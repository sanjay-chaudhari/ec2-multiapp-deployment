#!/bin/bash
# Deploy latest code for ANY app
# Usage: ./scripts/deploy.sh <APP_NAME> <user@app-ec2-ip>
# Must be run from the project root directory
# Example: ./scripts/deploy.sh myapp ubuntu@54.x.x.x
set -e

APP_NAME=$1
SSH_TARGET=$2

if [ -z "$APP_NAME" ] || [ -z "$SSH_TARGET" ]; then
  echo "Usage: $0 <app_name> <user@app-ec2-ip>"
  exit 1
fi

# Ensure we're in the project root (where frontend/ exists)
if [ ! -d "frontend" ]; then
  echo "Error: run this script from the project root directory"
  exit 1
fi

echo ">>> Building React frontend for ${APP_NAME}..."
cd frontend
npm run build

echo ">>> Uploading frontend..."
rsync -avz --delete build/ $SSH_TARGET:/opt/${APP_NAME}/frontend_dist/
cd ..

echo ">>> Deploying backend..."
ssh $SSH_TARGET "
  cd /opt/${APP_NAME}
  git pull origin main
  source backend/venv/bin/activate
  pip install -r backend/requirements.txt
  sudo systemctl restart ${APP_NAME}
  echo 'Backend restarted.'
"

echo ">>> Deployment complete for ${APP_NAME}!"
