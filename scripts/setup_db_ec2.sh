#!/bin/bash
# One-time DB setup for ANY app
# Usage: ./setup_db_ec2.sh <APP_NAME> <APP_EC2_PRIVATE_IP> <DB_PASSWORD>
# Example: ./setup_db_ec2.sh myapp 10.0.1.50 strongpass123
set -e

APP_NAME=$1
APP_EC2_PRIVATE_IP=$2
DB_PASSWORD=$3

if [ -z "$APP_NAME" ] || [ -z "$APP_EC2_PRIVATE_IP" ] || [ -z "$DB_PASSWORD" ]; then
  echo "Usage: $0 <app_name> <app_ec2_private_ip> <db_password>"
  exit 1
fi

DB_NAME="${APP_NAME}_db"
DB_USER="${APP_NAME}_user"

sudo apt update && sudo apt install -y postgresql postgresql-contrib

sudo -u postgres psql <<EOF
CREATE DATABASE ${DB_NAME};
CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
EOF

echo "host ${DB_NAME} ${DB_USER} ${APP_EC2_PRIVATE_IP}/32 md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf

sudo systemctl restart postgresql
echo "DB '${DB_NAME}' ready for app '${APP_NAME}'"
