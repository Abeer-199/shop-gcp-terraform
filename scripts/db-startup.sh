#!/bin/bash
# ================================================================
# db-startup.sh — MariaDB Installation & Setup
# يُشغَّل تلقائياً عند إنشاء الـ DB VM
# ================================================================
set -e
exec > >(tee /var/log/db-startup.log) 2>&1

echo "📦 [1/4] Installing MariaDB..."
apt-get update -y -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server

echo "🔧 [2/4] Configuring MariaDB..."
sed -i 's/^bind-address.*=.*127.0.0.1/bind-address = 0.0.0.0/' \
  /etc/mysql/mariadb.conf.d/50-server.cnf

systemctl enable mariadb
systemctl restart mariadb

echo "💾 [3/4] Creating database and tables..."
mysql << 'SQLEOF'
CREATE DATABASE IF NOT EXISTS ecommerce CHARACTER SET utf8mb4;
USE ecommerce;

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) UNIQUE NOT NULL,
  password_hash VARCHAR(64) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email (email)
);

CREATE TABLE IF NOT EXISTS products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200),
  description TEXT,
  price DECIMAL(10,2),
  stock INT DEFAULT 0,
  category VARCHAR(100),
  image_path VARCHAR(300)
);

CREATE TABLE IF NOT EXISTS orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  total DECIMAL(10,2),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  INDEX idx_user (user_id)
);

CREATE TABLE IF NOT EXISTS order_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  quantity INT NOT NULL,
  unit_price DECIMAL(10,2),
  FOREIGN KEY (order_id) REFERENCES orders(id)
);

CREATE TABLE IF NOT EXISTS user_uploads (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  gcs_path VARCHAR(500) NOT NULL,
  file_size INT,
  content_type VARCHAR(100),
  uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  INDEX idx_user (user_id)
);

INSERT INTO products (name, description, price, stock, category, image_path) VALUES
  ('iPhone 15 Pro',      'آيفون 15 برو',      4999.00, 50,  'Electronics', 'products/iphone.svg'),
  ('Samsung Galaxy S24', 'سامسونج جالكسي',    3799.00, 40,  'Electronics', 'products/samsung.svg'),
  ('MacBook Pro M3',     'ماك بوك برو',       9999.00, 20,  'Laptops',     'products/macbook.svg'),
  ('Sony Headphones',    'سماعات سوني',       1299.00, 100, 'Audio',       'products/headphones.svg'),
  ('iPad Pro',           'آيباد برو',         5999.00, 30,  'Tablets',     'products/ipad.svg');
SQLEOF

echo "🔐 [4/4] Creating app user..."
mysql -e "CREATE USER IF NOT EXISTS 'app_user'@'%' IDENTIFIED BY '${db_password}';"
mysql -e "GRANT ALL ON ecommerce.* TO 'app_user'@'%';"
mysql -e "FLUSH PRIVILEGES;"

echo "✅ MariaDB setup complete!"
