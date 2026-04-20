#!/bin/bash
# ================================================================
# web-startup.sh — Web VM Setup
# Downloads app code from GCS and runs FastAPI + Nginx
# ================================================================
set -e
exec > >(tee /var/log/web-startup.log) 2>&1

echo "📦 [1/6] Installing dependencies..."
apt-get update -y -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  python3-pip python3-venv nginx

echo "📥 [2/6] Downloading app code from GCS..."
mkdir -p /opt/shop /var/www/shop
gcloud storage cp gs://${bucket_name}/app-code/* /opt/shop/

# Split frontend and backend
cp /opt/shop/index.html /var/www/shop/
cp /opt/shop/nginx.conf /etc/nginx/sites-available/default

echo "🐍 [3/6] Setting up Python venv..."
cd /opt/shop
python3 -m venv venv
source venv/bin/activate
pip install -q -r requirements.txt

echo "📝 [4/6] Creating systemd service..."
cat > /etc/systemd/system/shop-backend.service << SVCEOF
[Unit]
Description=Shop Backend API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/shop
Environment="DB_HOST=${db_ip}"
Environment="DB_USER=app_user"
Environment="DB_PASSWORD=${db_password}"
Environment="DB_NAME=ecommerce"
Environment="BUCKET_NAME=${bucket_name}"
Environment="JWT_SECRET=shop-prod-secret-$RANDOM$RANDOM"
ExecStart=/opt/shop/venv/bin/uvicorn backend:app --host 127.0.0.1 --port 8080 --workers 2
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

echo "🚀 [5/6] Starting backend..."
systemctl daemon-reload
systemctl enable shop-backend
systemctl start shop-backend

echo "🌐 [6/6] Restarting Nginx..."
systemctl restart nginx
systemctl enable nginx

echo "✅ Web VM setup complete!"
