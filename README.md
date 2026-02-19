# MyApp - EC2 Deployment Demo

A demo app with Python (Flask) API + React frontend deployed on one EC2, PostgreSQL on a separate EC2.
Designed to support multiple apps on the same EC2s.

## Project Structure

```
├── backend/
│   ├── app.py                        # Flask API (items CRUD + DB init)
│   └── requirements.txt              # flask, flask-cors, psycopg2-binary, gunicorn
├── frontend/
│   ├── public/index.html
│   ├── src/
│   │   ├── App.js                    # React UI (add/list/delete items)
│   │   └── index.js
│   └── package.json                  # proxy: localhost:8000 for local dev
├── nginx/
│   └── myapp.conf                    # Nginx: / → React, /api/ → Gunicorn
├── systemd/
│   └── myapp.service                 # Gunicorn managed as a systemd service
├── scripts/
│   ├── setup_db_ec2.sh               # One-time DB EC2 setup (parameterized per app)
│   ├── setup_app_ec2.sh              # One-time App EC2 setup (parameterized per app)
│   └── deploy.sh                     # Deploy code changes (run from project root)
├── infra/
│   ├── provision_ec2.sh              # Bash: Creates VPC, SGs, App EC2 + DB EC2
│   ├── destroy_ec2.sh                # Bash: Destroys all AWS resources
│   ├── terraform/                    # Terraform (recommended)
│   │   ├── main.tf                   # VPC, subnet, IGW, route table
│   │   ├── security.tf               # App + DB security groups
│   │   ├── ec2.tf                    # App + DB EC2 instances
│   │   ├── variables.tf              # Input variable definitions
│   │   ├── outputs.tf                # Prints IPs after apply
│   │   ├── terraform.tfvars.example  # Copy to terraform.tfvars and fill in values
│   │   └── .gitignore                # Excludes state files and tfvars
│   └── README.md
├── .env.example                      # Environment variable template
└── .gitignore                        # Excludes .pem, .env, terraform state
```

---

## Architecture

![Architecture Diagram](assets/architecture.png)

```
Client Browser
     |
     ↓ port 80
[App EC2] - Nginx (reverse proxy)
     ├── / → React frontend (static files from /opt/myapp/frontend_dist)
     └── /api/ → Gunicorn :8000 (Python Flask API)
                     |
                     ↓ port 5432 (private network only)
              [DB EC2] - PostgreSQL
                     └── myapp_db
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/health | Health check |
| GET | /api/items | List all items |
| POST | /api/items | Create item `{"name": "", "description": ""}` |
| DELETE | /api/items/:id | Delete item |

---

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform installed (`brew install hashicorp/tap/terraform`)
- Node.js + npm installed
- Python 3 installed
- EC2 Key Pair created and `.pem` saved locally:

```bash
# Create key pair and download .pem to project root
aws ec2 create-key-pair \
  --key-name MyAppKeyPair \
  --query 'KeyMaterial' \
  --output text \
  --region us-east-1 > MyAppKeyPair.pem

chmod 400 MyAppKeyPair.pem
```

> `MyAppKeyPair.pem` is gitignored — never commit it.

---

## Full Deployment Guide

### Step 1 — Provision EC2s with Terraform (once ever)

```bash
cd infra/terraform

# Copy and fill in your values
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
region        = "us-east-1"
ami_id        = "ami-04680790a315cd58d"   # Ubuntu 22.04 — find for your region below
instance_type = "t3.micro"
key_name      = "MyAppKeyPair"            # your EC2 key pair name
your_ip       = "x.x.x.x/32"             # your public IP: curl ifconfig.me
```

Find the correct Ubuntu 22.04 AMI for your region:
```bash
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64*" \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' \
  --output text --region <your-region>
```

```bash
terraform init
terraform apply
```

Outputs:
```
app_ec2_public_ip  = "x.x.x.x"
app_ec2_private_ip = "10.0.1.x"
db_ec2_public_ip   = "x.x.x.x"
db_ec2_private_ip  = "10.0.1.x"
```

---

### Step 2 — Setup DB EC2 (once per app)

Copy the script and run it on the DB EC2:

```bash
scp -i MyAppKeyPair.pem scripts/setup_db_ec2.sh ubuntu@<DB_EC2_PUBLIC_IP>:~/
ssh -i MyAppKeyPair.pem ubuntu@<DB_EC2_PUBLIC_IP>
chmod +x ~/setup_db_ec2.sh
~/setup_db_ec2.sh myapp <APP_EC2_PRIVATE_IP> <DB_PASSWORD>

# Example
~/setup_db_ec2.sh myapp 10.0.1.254 strongpass123
```

Creates: `myapp_db` database, `myapp_user`, grants access from App EC2 private IP only.

---

### Step 3 — Setup App EC2 (once per app)

Install system packages and Python deps on the App EC2:

```bash
ssh -i MyAppKeyPair.pem ubuntu@<APP_EC2_PUBLIC_IP>

sudo apt update && sudo apt install -y python3-pip python3-venv nginx

# Create app directory
sudo mkdir -p /opt/myapp/backend /opt/myapp/frontend_dist
sudo chown -R ubuntu:ubuntu /opt/myapp
```

Copy backend files:
```bash
scp -i MyAppKeyPair.pem backend/app.py backend/requirements.txt ubuntu@<APP_EC2_PUBLIC_IP>:/opt/myapp/backend/
```

Install Python dependencies:
```bash
ssh -i MyAppKeyPair.pem ubuntu@<APP_EC2_PUBLIC_IP>
cd /opt/myapp/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Create `.env` with DB credentials:
```bash
echo 'DATABASE_URL=postgresql://myapp_user:<DB_PASSWORD>@<DB_EC2_PRIVATE_IP>:5432/myapp_db' > /opt/myapp/.env
```

Install systemd service:
```bash
sudo cp /path/to/systemd/myapp.service /etc/systemd/system/myapp.service
sudo systemctl daemon-reload
sudo systemctl enable myapp
sudo systemctl start myapp
```

Configure Nginx:
```bash
sudo cp /path/to/nginx/myapp.conf /etc/nginx/sites-available/myapp
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/myapp
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

---

### Step 4 — Build and Deploy Frontend

Run from your **local machine** (project root):

```bash
cd frontend
npm install
npm run build

rsync -avz --delete \
  -e "ssh -i ../MyAppKeyPair.pem" \
  build/ ubuntu@<APP_EC2_PUBLIC_IP>:/opt/myapp/frontend_dist/
```

---

### Step 5 — Verify Deployment

```bash
# Health check
curl http://<APP_EC2_PUBLIC_IP>/api/health
# → {"status": "ok"}

# Create an item
curl -X POST http://<APP_EC2_PUBLIC_IP>/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","description":"Hello"}'

# List items
curl http://<APP_EC2_PUBLIC_IP>/api/items
```

Open `http://<APP_EC2_PUBLIC_IP>` in your browser for the React UI.

---

## Deploying Code Changes (every release)

Run from the **project root** on your local machine:

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh myapp ubuntu@<APP_EC2_PUBLIC_IP>
```

What it does:
1. Builds React frontend locally (`npm run build`)
2. Rsyncs the build to the EC2
3. SSHs in, runs `git pull`, updates pip dependencies, restarts Gunicorn

---

## Adding a Second App (Multi-App Scalability)

Each app gets its own isolated resources on the same EC2s:

| Resource | App 1 | App 2 |
|---|---|---|
| Directory | `/opt/myapp` | `/opt/myapp2` |
| Gunicorn port | `8000` | `8001` |
| Systemd service | `myapp.service` | `myapp2.service` |
| Nginx config | `sites-available/myapp` | `sites-available/myapp2` |
| Database | `myapp_db` | `myapp2_db` |

Repeat Steps 2–5 with a different app name and port.

---

## Teardown

```bash
cd infra/terraform
terraform destroy
```

Destroys all AWS resources: EC2s, VPC, subnets, security groups, internet gateway.

---

## Local Development

```bash
# Backend (Terminal 1)
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
DATABASE_URL=postgresql://user:pass@localhost:5432/myapp_db python app.py

# Frontend (Terminal 2)
cd frontend
npm install && npm start   # proxies /api/* to localhost:8000
```

---

## Troubleshooting

```bash
# Check service status
sudo systemctl status myapp

# View live logs
sudo journalctl -u myapp -f

# Test API directly (bypassing Nginx)
curl http://localhost:8000/api/health

# Reload Nginx after config changes
sudo nginx -t && sudo systemctl reload nginx

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log
```

---

## Security Notes

- DB EC2 port 5432 is only accessible from the App EC2 security group — not the public internet
- SSH (port 22) is restricted to your IP only on both EC2s
- `.pem` key files and `.env` are gitignored — never commit them
- `terraform.tfvars` is gitignored — contains your IP and key name
