"""
Shop Backend API
================
FastAPI backend with:
- User authentication (JWT)
- Product catalog with signed URLs
- Order management
- File uploads to GCS with signed URLs
"""
from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
from datetime import datetime, timedelta
import mysql.connector, os, hashlib, jwt, uuid
from google.cloud import storage
from google.auth import default
from google.auth.transport import requests as auth_requests

app = FastAPI(title="Shop API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ---------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------
DB = {
    "host": os.getenv("DB_HOST", "localhost"),
    "user": os.getenv("DB_USER", "app_user"),
    "password": os.getenv("DB_PASSWORD", "AppPass123!"),
    "database": os.getenv("DB_NAME", "ecommerce"),
}
JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-me")
BUCKET_NAME = os.getenv("BUCKET_NAME", "")

storage_client = storage.Client()

# ---------------------------------------------------------------
# Pydantic Models
# ---------------------------------------------------------------
class RegisterReq(BaseModel):
    name: str
    email: str
    password: str

class LoginReq(BaseModel):
    email: str
    password: str

class OrderItem(BaseModel):
    product_id: int
    quantity: int

class CreateOrder(BaseModel):
    items: List[OrderItem]

# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------
def get_db():
    conn = mysql.connector.connect(**DB)
    try:
        yield conn
    finally:
        conn.close()

def hash_pw(p: str) -> str:
    return hashlib.sha256(p.encode()).hexdigest()

def make_token(uid: int) -> str:
    return jwt.encode(
        {"user_id": uid, "exp": datetime.utcnow() + timedelta(hours=24)},
        JWT_SECRET, algorithm="HS256"
    )

def verify_token(authorization: str = Header(None)) -> int:
    if not authorization:
        raise HTTPException(401, "Missing token")
    try:
        token = authorization.replace("Bearer ", "")
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        return payload["user_id"]
    except Exception:
        raise HTTPException(401, "Invalid token")

def signed_url(blob_path: str, minutes: int = 60) -> str:
    """Generate signed URL using IAM Sign Blob (works on GCE VMs without private key)"""
    credentials, _ = default()
    auth_request = auth_requests.Request()
    credentials.refresh(auth_request)

    bucket = storage_client.bucket(BUCKET_NAME)
    blob = bucket.blob(blob_path)

    return blob.generate_signed_url(
        version="v4",
        expiration=timedelta(minutes=minutes),
        method="GET",
        service_account_email=credentials.service_account_email,
        access_token=credentials.token,
    )

# ================= ROUTES =================

@app.get("/api/health")
def health():
    try:
        c = mysql.connector.connect(**DB)
        c.close()
        return {"status": "ok", "db": "connected", "hostname": os.uname().nodename}
    except Exception as e:
        raise HTTPException(503, f"DB error: {e}")

# --- Authentication ---
@app.post("/api/register")
def register(req: RegisterReq, db=Depends(get_db)):
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT id FROM users WHERE email=%s", (req.email,))
    if cur.fetchone():
        raise HTTPException(409, "Email already exists")
    cur.execute(
        "INSERT INTO users (name, email, password_hash) VALUES (%s, %s, %s)",
        (req.name, req.email, hash_pw(req.password))
    )
    db.commit()
    uid = cur.lastrowid
    return {"user_id": uid, "token": make_token(uid), "name": req.name}

@app.post("/api/login")
def login(req: LoginReq, db=Depends(get_db)):
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT id, name, password_hash FROM users WHERE email=%s", (req.email,))
    u = cur.fetchone()
    if not u or u["password_hash"] != hash_pw(req.password):
        raise HTTPException(401, "Invalid credentials")
    return {"user_id": u["id"], "name": u["name"], "token": make_token(u["id"])}

# --- Products ---
@app.get("/api/products")
def list_products(db=Depends(get_db)):
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM products WHERE stock > 0 ORDER BY category")
    rows = cur.fetchall()
    for r in rows:
        r["price"] = float(r["price"])
        if r.get("image_path"):
            r["image_url"] = signed_url(r["image_path"], minutes=60)
    return rows

# --- Orders ---
@app.post("/api/orders")
def create_order(req: CreateOrder, db=Depends(get_db), user_id: int = Depends(verify_token)):
    cur = db.cursor(dictionary=True)
    total = 0.0
    prices = {}

    for item in req.items:
        cur.execute("SELECT price, stock, name FROM products WHERE id=%s FOR UPDATE", (item.product_id,))
        p = cur.fetchone()
        if not p:
            raise HTTPException(404, f"Product {item.product_id} not found")
        if p["stock"] < item.quantity:
            raise HTTPException(400, f"Not enough stock for {p['name']}")
        prices[item.product_id] = float(p["price"])
        total += float(p["price"]) * item.quantity

    cur.execute("INSERT INTO orders (user_id, total) VALUES (%s, %s)", (user_id, round(total, 2)))
    order_id = cur.lastrowid

    for item in req.items:
        cur.execute(
            "INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (%s, %s, %s, %s)",
            (order_id, item.product_id, item.quantity, prices[item.product_id])
        )
        cur.execute("UPDATE products SET stock = stock - %s WHERE id=%s", (item.quantity, item.product_id))
    db.commit()

    return {"order_id": order_id, "total": round(total, 2), "status": "pending"}

@app.get("/api/my-orders")
def my_orders(db=Depends(get_db), user_id: int = Depends(verify_token)):
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM orders WHERE user_id=%s ORDER BY created_at DESC", (user_id,))
    orders = cur.fetchall()
    for o in orders:
        o["total"] = float(o["total"])
    return orders

# --- File Uploads ---
@app.post("/api/upload")
async def upload_file(
    file: UploadFile = File(...),
    db=Depends(get_db),
    user_id: int = Depends(verify_token)
):
    content = await file.read()
    size = len(content)

    if size > 5 * 1024 * 1024:
        raise HTTPException(400, "File too large (max 5 MB)")

    file_id = uuid.uuid4().hex[:8]
    safe_name = file.filename.replace(" ", "_")
    gcs_path = f"user_uploads/user_{user_id}/{file_id}_{safe_name}"

    bucket = storage_client.bucket(BUCKET_NAME)
    blob = bucket.blob(gcs_path)
    blob.upload_from_string(content, content_type=file.content_type)

    cur = db.cursor()
    cur.execute("""
        INSERT INTO user_uploads (user_id, file_name, gcs_path, file_size, content_type)
        VALUES (%s, %s, %s, %s, %s)
    """, (user_id, file.filename, gcs_path, size, file.content_type))
    db.commit()

    return {"success": True, "file_name": file.filename, "size": size, "upload_id": cur.lastrowid}

@app.get("/api/my-uploads")
def my_uploads(db=Depends(get_db), user_id: int = Depends(verify_token)):
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT * FROM user_uploads WHERE user_id=%s ORDER BY uploaded_at DESC", (user_id,))
    uploads = cur.fetchall()
    for u in uploads:
        u["download_url"] = signed_url(u["gcs_path"], minutes=15)
        u["uploaded_at"] = u["uploaded_at"].isoformat()
    return uploads

@app.delete("/api/uploads/{upload_id}")
def delete_upload(upload_id: int, db=Depends(get_db), user_id: int = Depends(verify_token)):
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT gcs_path FROM user_uploads WHERE id=%s AND user_id=%s", (upload_id, user_id))
    u = cur.fetchone()
    if not u:
        raise HTTPException(404, "Upload not found")

    bucket = storage_client.bucket(BUCKET_NAME)
    bucket.blob(u["gcs_path"]).delete()

    cur.execute("DELETE FROM user_uploads WHERE id=%s", (upload_id,))
    db.commit()
    return {"success": True}
