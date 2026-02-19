#!/bin/bash
# One-time App EC2 setup for ANY app
# Usage: ./setup_app_ec2.sh <APP_NAME> <REPO_URL> <PORT>
# Example: ./setup_app_ec2.sh myapp https://github.com/org/myapp.git 8000
#          ./setup_app_ec2.sh myapp2 https://github.com/org/myapp2.git 8001
set -e

APP_NAME=$1
REPO_URL=$2
PORT=$3

if [ -z "$APP_NAME" ] || [ -z "$REPO_URL" ] || [ -z "$PORT" ]; then
  echo "Usage: $0 <app_name> <repo_url> <port>"
  exit 1
fi

APP_DIR="/opt/${APP_NAME}"

# Install system deps (safe to run multiple times)
sudo apt update && sudo apt install -y python3-pip python3-venv nginx nodejs npm git

# Clone repo
sudo git clone $REPO_URL $APP_DIR
sudo chown -R ubuntu:ubuntu $APP_DIR

# Python setup
cd $APP_DIR/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Build React
cd $APP_DIR/frontend
npm install && npm run build
sudo mkdir -p ${APP_DIR}/frontend_dist
sudo cp -r build/. ${APP_DIR}/frontend_dist/

# Create .env from example
cp $APP_DIR/.env.example $APP_DIR/.env
echo ">>> Edit ${APP_DIR}/.env with real DB credentials before starting <<<"

# Systemd service
cat <<EOF | sudo tee /etc/systemd/system/${APP_NAME}.service
[Unit]
Description=${APP_NAME} Python API
After=network.target

[Service]
User=ubuntu
WorkingDirectory=${APP_DIR}/backend
EnvironmentFile=${APP_DIR}/.env
ExecStart=${APP_DIR}/backend/venv/bin/gunicorn -w 4 -b 127.0.0.1:${PORT} app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ${APP_NAME}

# Nginx config
cat <<EOF | sudo tee /etc/nginx/sites-available/${APP_NAME}
server {
    listen 80;
    server_name ${APP_NAME}.yourdomain.com;

    location / {
        root ${APP_DIR}/frontend_dist;
        try_files \$uri /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/${APP_NAME} /etc/nginx/sites-enabled/${APP_NAME}
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

echo "Setup complete for '${APP_NAME}' on port ${PORT}."
echo "Update ${APP_DIR}/.env then run: sudo systemctl start ${APP_NAME}"
