# Multi-App EC2 Deployment — Architecture & SDLC Overview

**Audience:** Engineering Leadership, Tech Leads, Project Managers

---

## Executive Summary

This document describes a standardized deployment pattern for hosting multiple web applications on shared AWS EC2 infrastructure. The approach balances cost efficiency, operational simplicity, and scalability — suitable for teams managing 2–10 applications with moderate traffic.

---

## Infrastructure Overview

```
                        Internet
                           |
              ┌────────────────────────┐
              │        AWS VPC         │
              │                        │
              │  ┌──────────────────┐  │
              │  │    App EC2       │  │  ← All apps live here
              │  │                  │  │
              │  │  Nginx (port 80) │  │
              │  │  ├── App 1 :8000 │  │
              │  │  ├── App 2 :8001 │  │
              │  │  └── App N :800N │  │
              │  └────────┬─────────┘  │
              │           │ private    │
              │  ┌────────▼─────────┐  │
              │  │    DB EC2        │  │  ← All databases live here
              │  │                  │  │
              │  │  PostgreSQL      │  │
              │  │  ├── app1_db     │  │
              │  │  ├── app2_db     │  │
              │  │  └── appN_db     │  │
              │  └──────────────────┘  │
              └────────────────────────┘
```

### Key Design Decisions

| Decision | Rationale |
|---|---|
| Single App EC2 for all apps | Reduces cost; apps share OS, Nginx, system packages |
| Single DB EC2 for all databases | One PostgreSQL instance, isolated databases per app |
| Nginx as reverse proxy | Routes traffic by domain/subdomain to the correct app |
| Gunicorn per app | Each app runs as an independent process on a unique port |
| Systemd per app | OS-level process management — auto-restart on crash or reboot |
| Private networking for DB | DB port 5432 never exposed to internet; App EC2 only |

---

## Security Model

```
Internet → App EC2 (port 80/443 open)
                 ↓ internal only
           DB EC2 (port 5432, App EC2 SG only)

SSH access → Both EC2s (port 22, developer IP only)
```

- No database is ever publicly accessible
- Each app has its own DB user with scoped permissions
- SSH restricted to known IPs via Security Groups
- Secrets (DB passwords, API keys) stored in per-app `.env` files on the server — never in code

---

## SDLC Lifecycle

### Phase 1 — Infrastructure Provisioning (Once per environment)

**Who:** DevOps / Tech Lead
**Tool:** Terraform
**Time:** ~5 minutes

```
Developer runs:  terraform apply
AWS creates:     VPC → Subnets → Security Groups → App EC2 + DB EC2
Output:          Public/Private IPs for both EC2s
```

This is a one-time activity per environment (dev, staging, prod). Infrastructure is version-controlled and reproducible.

---

### Phase 2 — App Onboarding (Once per new application)

**Who:** Tech Lead / Backend Developer
**Tool:** Setup scripts
**Time:** ~15 minutes

```
Step 1: DB EC2  → setup_db_ec2.sh <app_name> <app_private_ip> <password>
                  Creates isolated database + user for the app

Step 2: App EC2 → setup_app_ec2.sh <app_name> <repo_url> <port>
                  Clones repo, installs deps, configures Nginx + systemd
```

Each new app is fully isolated — its own directory, port, service, database, and Nginx config.

---

### Phase 3 — Development Workflow

**Who:** Developers
**Branching strategy:** Feature → PR → main

```
Developer workflow:
  1. Create feature branch
  2. Develop + test locally (backend on :8000, frontend on :3000)
  3. Open Pull Request → code review
  4. Merge to main
  5. Run deploy.sh → live in ~2 minutes
```

Local development requires no AWS access — developers run the full stack locally using a local PostgreSQL instance.

---

### Phase 4 — Deployment (Every release)

**Who:** Developer / Tech Lead
**Tool:** `deploy.sh`
**Time:** ~2 minutes

```
./scripts/deploy.sh <app_name> ubuntu@<app_ec2_ip>

What happens:
  1. React frontend built locally (npm run build)
  2. Build uploaded to EC2 via rsync (only changed files)
  3. SSH into EC2: git pull → pip install → systemctl restart
  4. Zero manual steps on the server
```

**Deployment is atomic per app** — deploying App 2 has zero impact on App 1.

---

### Phase 5 — Monitoring & Operations

**Who:** Tech Lead / On-call Developer

```bash
# Check app health
curl http://<app_ec2_ip>/api/health

# View live logs
ssh ubuntu@<app_ec2_ip>
sudo journalctl -u <app_name> -f

# Check all running apps
sudo systemctl list-units --type=service | grep app
```

If an app crashes, systemd automatically restarts it within 5 seconds.

---

### Phase 6 — Teardown

**Who:** DevOps / Tech Lead
**Tool:** Terraform
**Time:** ~2 minutes

```
terraform destroy   → removes all AWS resources cleanly
                      EC2s, VPC, subnets, security groups, IGW
```

No orphaned resources, no surprise AWS charges.

---

## Multi-App Resource Isolation

Every application deployed on this infrastructure gets fully isolated resources:

| Resource | App 1 | App 2 | App N |
|---|---|---|---|
| Code directory | `/opt/app1` | `/opt/app2` | `/opt/appN` |
| API port | `8000` | `8001` | `800N` |
| Process | `app1.service` | `app2.service` | `appN.service` |
| Nginx config | `sites-available/app1` | `sites-available/app2` | `sites-available/appN` |
| Database | `app1_db` | `app2_db` | `appN_db` |
| DB user | `app1_user` | `app2_user` | `appN_user` |
| Environment | `/opt/app1/.env` | `/opt/app2/.env` | `/opt/appN/.env` |

**One app crashing, restarting, or being deployed does not affect any other app.**

---

## Cost Profile

| Resource | Type | Estimated Monthly Cost |
|---|---|---|
| App EC2 | t3.micro | ~$8 |
| DB EC2 | t3.micro | ~$8 |
| Data transfer | Minimal | ~$1–2 |
| **Total** | | **~$18/month** |

This cost is **fixed regardless of how many apps** are deployed on the same EC2s (up to resource limits).

---

## Scalability Limits & Upgrade Path

This pattern is designed for **small to medium workloads**. Here's when to consider upgrading:

| Trigger | Recommended Next Step |
|---|---|
| App EC2 CPU/memory consistently >70% | Upgrade instance type (t3.small → t3.medium) |
| 5+ apps on same EC2 | Containerize with Docker + ECS |
| DB growing large or slow | Migrate to Amazon RDS |
| Need zero-downtime deploys | Add blue/green deployment to deploy.sh |
| Multiple developers deploying | Add GitHub Actions CI/CD pipeline |
| Need staging/prod environments | Add Terraform workspaces |

---

## Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| Infrastructure | Terraform | Reproducible AWS resource provisioning |
| Cloud | AWS EC2 + VPC | Compute and networking |
| Web server | Nginx | Reverse proxy, static file serving |
| App server | Gunicorn | Python WSGI production server |
| Backend | Python / Flask | REST API |
| Frontend | React | Single-page application |
| Database | PostgreSQL | Relational data store |
| Process mgmt | systemd | Service lifecycle management |
| Deployment | Bash + rsync + SSH | Lightweight deploy pipeline |

---

## Summary

This pattern provides a **production-ready, cost-efficient, multi-app deployment foundation** that:

- Provisions infrastructure in minutes with a single command
- Onboards new applications in ~15 minutes with parameterized scripts
- Deploys code changes in ~2 minutes with a single command
- Keeps all applications fully isolated from each other
- Scales horizontally by adding more EC2s when needed
- Tears down completely with `terraform destroy` — no orphaned resources

It is intentionally simple — no Kubernetes, no container orchestration, no CI/CD server to maintain — making it ideal for small teams that need reliability without operational overhead.
