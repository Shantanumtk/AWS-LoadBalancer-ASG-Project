# 🌦️ AWS Weather Data Aggregator API

FastAPI application demonstrating AWS Auto Scaling and Application Load Balancing.

## 📋 Overview

This project is a complete demonstration of:
- **AWS Auto Scaling Groups (ASG)** - Automatic scaling based on CPU utilization
- **Application Load Balancer (ALB)** - Traffic distribution across multiple instances
- **EC2 Instance Management** - Automated deployment and configuration
- **FastAPI Framework** - Modern Python web framework
- **CloudWatch Monitoring** - Metrics and alarms

## 🚀 Features

- Real-time weather data API (simulated)
- Load balancing demonstration with instance identification
- Built-in load generation for testing auto-scaling
- Health check endpoint for ALB
- Comprehensive system metrics
- Automatic deployment via Git clone

## 📡 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Welcome message with instance info |
| `/health` | GET | Health check (used by ALB) |
| `/weather/{city}` | GET | Get weather for a specific city |
| `/weather/bulk/cities` | GET | Get weather for multiple cities (CPU-intensive) |
| `/instance-info` | GET | Detailed EC2 instance information |
| `/generate-load` | GET | Generate CPU load (duration parameter) |
| `/cities` | GET | List all available cities |
| `/docs` | GET | Interactive API documentation (Swagger UI) |

## 🏙️ Available Cities

- New York
- London
- Tokyo
- Paris
- Sydney
- Mumbai
- Dubai
- Toronto
- Berlin
- Singapore

## 🔧 Local Development

### Prerequisites
- Python 3.11+
- pip

### Installation

```bash
# Clone the repository
git clone https://github.com/Shantanumtkg/aws-weather-api.git
cd aws-weather-api

# Install dependencies
pip install -r requirements.txt

# Run the application
python main.py

# Weather Lab — ALB + ASG SOP (README.md)

A complete **step‑by‑step, copy‑paste Standard Operating Procedure (SOP)** to deploy the `aws-weather-api` app behind an **Application Load Balancer (ALB)** with an **Auto Scaling Group (ASG)**.

> **Repo:** [https://github.com/Shantanumtk/AWS-LoadBalancer-ASG-Project/tree/main/aws-weather-api](https://github.com/Shantanumtk/AWS-LoadBalancer-ASG-Project/tree/main/aws-weather-api)
> **Naming prefix used throughout:** `wl-…`
> **App health path:** `/health`
> **App port (target):** **5000** (unless you explicitly standardize on 8000)
> **Design:** Public ALB in **public subnets**; EC2 instances in **private subnets** via **NAT Gateway**; scaling on **ALB RequestCountPerTarget**.

---

## Table of Contents

1. [Step 1 — VPC & Networking (names for every object)](#step-1--vpc--networking-names-for-every-object)
2. [Step 2 — Security Groups](#step-2--security-groups-explicit-names)
3. [Step 3 — IAM Role & Instance Profile](#step-3--iam-role--instance-profile-explicit-names)
4. [Step 4 — Key Pair](#step-4--key-pair)
5. [Step 5 — Target Group](#step-5--target-group-explicit-name--health)
6. [Step 6 — Load Balancer](#step-6--load-balancer-explicit-names-mapping)
7. [Step 7 — Launch Template (+ Ubuntu 24.04 user-data)](#step-7--launch-template-explicit-name-ubuntu-2404-user-data)
8. [Step 8 — Auto Scaling Group](#step-8--auto-scaling-group-explicit-names-private-subnets)
9. [Step 9 — Verify Health](#step-9--verify-health-by-name)
10. [Step 10 — (Optional) HTTPS](#step-10--optional-https-named-parts)
11. [Step 11 — (Optional) Load Test & Observe Scaling](#step-11--optional-load-test--observe-scaling)
12. [Step 12 — Cleanup](#step-12--cleanup-delete-by-name-in-order)
13. [Quick Name Map](#quick-name-map-for-your-checklist)
14. [Appendix A — Create Subnets, IGW, EIP, NAT, Route Tables](#appendix-a--subnets-igw-eip-nat-route-tables)
15. [Appendix B — Session Manager (SSM) quick setup on Ubuntu](#appendix-b--session-manager-ssm-quick-setup-on-ubuntu)

---

## Step 1 — VPC & Networking (names for every object)

### 1.1 Create the VPC

**Console:** VPC → Your VPCs → Create VPC → **VPC only**

* **Name tag:** `wl-vpc`
* **IPv4 CIDR:** `10.20.0.0/16`
* **Create**

### 1.2 Create Subnets (two public, two private)

**Console:** VPC → Subnets → **Create subnet**
**VPC:** `wl-vpc`

**Create Public A**

* **Subnet name:** `wl-subnet-public-a`
* **AZ:** `us-west-2a`
* **IPv4 CIDR block:** `10.20.1.0/24`

**Create Public B**

* **Subnet name:** `wl-subnet-public-b`
* **AZ:** `us-west-2b`
* **IPv4 CIDR block:** `10.20.2.0/24`

**Create Private A**

* **Subnet name:** `wl-subnet-private-a`
* **AZ:** `us-west-2a`
* **IPv4 CIDR block:** `10.20.11.0/24`

**Create Private B**

* **Subnet name:** `wl-subnet-private-b`
* **AZ:** `us-west-2b`
* **IPv4 CIDR block:** `10.20.12.0/24`

**Create subnet**

### 1.3 Create and Attach an Internet Gateway

**Console:** VPC → Internet Gateways → **Create internet gateway**

* **Name:** `wl-igw` → **Create**
* **Actions → Attach to VPC** → `wl-vpc`

### 1.4 Allocate Elastic IP for NAT

**Console:** VPC → Elastic IPs → **Allocate Elastic IP address**

* **Name tag:** `wl-eip-nat-a` → **Allocate**

### 1.5 Create NAT Gateway (in Public A)

**Console:** VPC → NAT gateways → **Create NAT gateway**

* **Name:** `wl-natgw-a`
* **Subnet:** `wl-subnet-public-a`
* **Elastic IP allocation ID:** `wl-eip-nat-a`
* **Create NAT gateway** (wait until **Available**)

> **Cost note:** 1 NAT keeps cost lower; both private subnets will route to this NAT in `us-west-2a`.

### 1.6 Create Route Tables and Associations

**Console:** VPC → Route tables → **Create route table**

**Public Route Table**

* **Name:** `wl-rtb-public`
* **VPC:** `wl-vpc` → **Create**
* Open `wl-rtb-public` → **Routes → Edit routes → Add route**

  * Destination `0.0.0.0/0` → **Target:** Internet Gateway `wl-igw` → **Save changes**
* **Subnet associations → Edit subnet associations**

  * Check: `wl-subnet-public-a`, `wl-subnet-public-b` → **Save**

**Private Route Table A**

* **Create route table** → **Name:** `wl-rtb-private-a` → **VPC:** `wl-vpc` → **Create**
* **Routes → Edit routes → Add route**

  * Destination `0.0.0.0/0` → **Target:** NAT gateway `wl-natgw-a` → **Save changes**
* **Subnet associations → Edit** → select `wl-subnet-private-a` → **Save**

**Private Route Table B**

* **Create route table** → **Name:** `wl-rtb-private-b` → **VPC:** `wl-vpc` → **Create**
* **Routes → Edit routes → Add route**

  * Destination `0.0.0.0/0` → **Target:** NAT gateway `wl-natgw-a` → **Save changes**
* **Subnet associations → Edit** → select `wl-subnet-private-b` → **Save**

✅ **At this point you have:**

* VPC: `wl-vpc (10.20.0.0/16)`
* IGW: `wl-igw`
* EIP: `wl-eip-nat-a`
* NAT: `wl-natgw-a` (in `wl-subnet-public-a`)
* Subnets: `wl-subnet-public-a (10.20.1.0/24)`, `wl-subnet-public-b (10.20.2.0/24)`, `wl-subnet-private-a (10.20.11.0/24)`, `wl-subnet-private-b (10.20.12.0/24)`
* Route tables: `wl-rtb-public` (to IGW, assoc with public), `wl-rtb-private-a` & `wl-rtb-private-b` (to NAT, assoc with respective private subnets)

---

## Step 2 — Security Groups (explicit names)

**Console:** EC2 → Network & Security → **Security Groups**

**2.1 ALB Security Group**

* **Name:** `wl-sg-alb`
* **VPC:** `wl-vpc`
* **Inbound rules:** HTTP, **Port 80**, **Source `0.0.0.0/0`** (Name: `Allow-HTTP-World`)
* **Outbound:** All traffic (default)
* **Create security group**

**2.2 EC2/Instance Security Group**

* **Name:** `wl-sg-ec2`
* **VPC:** `wl-vpc`
* **Inbound rules:** Custom TCP, **Port 5000**, **Source:** Security group `wl-sg-alb` (Name: `Allow-5000-from-ALB`)
* **Outbound:** All traffic (default)
* **Create security group**

---

## Step 3 — IAM Role & Instance Profile (explicit names)

**Console:** IAM → Roles → **Create role**

* **Trusted entity:** AWS service → **EC2**
* **Permissions policies:**

  * `AmazonSSMManagedInstanceCore`
  * *(Optional)* `AmazonSSMReadOnlyAccess` (if using Parameter Store)
* **Role name:** `wl-role-ec2-ssm` → **Create role**

> Instance profile will be created automatically and share the role name when you attach via the Launch Template.

---

## Step 4 — Key Pair

**Console:** EC2 → Key pairs → **Create key pair**

* **Name:** `wl-kp`
* **Type:** RSA, `.pem`
* **Create key pair** (download safely)

---

## Step 5 — Target Group (explicit name & health)

**Console:** EC2 → Target Groups → **Create target group**

* **Target type:** **Instances**
* **Name:** `wl-tg-5000`
* **Protocol:** HTTP
* **Port:** **5000**
* **VPC:** `wl-vpc`
* **Health checks:** Protocol **HTTP**, **Path `/`** *(change later to `/health`)*
  Healthy 2, Unhealthy 2, Interval 10s, Timeout 5s
* **Create target group** *(don’t register targets manually)*

---

## Step 6 — Load Balancer (explicit names, mapping)

**Console:** EC2 → Load Balancers → **Create load balancer** → **Application Load Balancer**

* **Name:** `wl-alb`
* **Scheme:** Internet-facing
* **IP address type:** IPv4
* **Network mapping:**

  * **VPC:** `wl-vpc`
  * **Subnets:** `wl-subnet-public-a`, `wl-subnet-public-b`
* **Security groups:** `wl-sg-alb`
* **Listeners:** HTTP **:80** → **Forward** to `wl-tg-5000`
* **Create load balancer**

---

## Step 7 — Launch Template (explicit name, Ubuntu 24.04 user-data)

**Console:** EC2 → Launch Templates → **Create launch template**

* **Name:** `wl-lt`
* **Application and OS Images (AMI):** **Ubuntu Server 24.04 LTS (amd64)**
* **Instance type:** `t3.micro`
* **Key pair:** `wl-kp`
* **Network settings:** (ASG will attach SG; you can also pre-attach `wl-sg-ec2` here.)
* **Advanced details → IAM instance profile:** `wl-role-ec2-ssm`
* **Advanced details → User data:** paste **this exact script**:

```bash
#!/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- System base (Ubuntu 24.04) ---
apt-get update -y
apt-get install -y git python3 python3-venv python3-pip

# --- Get the app into /opt/app ---
install -d -o ubuntu -g ubuntu /opt/app
cd /opt/app
if [ ! -d "AWS-LoadBalancer-ASG-Project" ]; then
  sudo -u ubuntu git clone https://github.com/Shantanumtk/AWS-LoadBalancer-ASG-Project.git
fi
cd AWS-LoadBalancer-ASG-Project/aws-weather-api
chown -R ubuntu:ubuntu /opt/app/AWS-LoadBalancer-ASG-Project

# --- Create venv in the project folder and install deps ---
sudo -u ubuntu python3 -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate

if [ -f requirements.txt ]; then
  pip install --upgrade pip
  pip install -r requirements.txt
else
  # minimal fallback if requirements.txt isn't present
  pip install --upgrade pip
  pip install fastapi uvicorn psutil requests
fi

# --- Simple environment (match ALB/TG port) ---
cat >/etc/default/weather <<EOF
PORT=5000
EOF
chmod 600 /etc/default/weather

# --- Tiny runner that sources the venv and starts uvicorn ---
cat >/opt/app/AWS-LoadBalancer-ASG-Project/aws-weather-api/start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
cd /opt/app/AWS-LoadBalancer-ASG-Project/aws-weather-api
# Activate the venv created in user-data
source .venv/bin/activate
export PORT="${PORT:-5000}"

# Prefer common module names that expose `app`
if [ -f app.py ];  then exec uvicorn app:app  --host 0.0.0.0 --port "$PORT"; fi
if [ -f main.py ]; then exec uvicorn main:app --host 0.0.0.0 --port "$PORT"; fi

# Last resort: try module:app or first .py file
python3 -c "import importlib; import sys; m=None
for name in ('app','main','server','api','application'):
    try:
        m=importlib.import_module(name)
        assert hasattr(m,'app')
        break
    except Exception: pass
sys.exit(0 if m else 1)" \
&& exec uvicorn app:app --host 0.0.0.0 --port "$PORT"

PYFILE=$(ls *.py | head -n1)
exec python3 "$PYFILE"
EOS
chmod +x /opt/app/AWS-LoadBalancer-ASG-Project/aws-weather-api/start.sh
chown ubuntu:ubuntu /opt/app/AWS-LoadBalancer-ASG-Project/aws-weather-api/start.sh

# --- Systemd unit: runs as ubuntu, sources venv via start.sh ---
cat >/etc/systemd/system/weather.service <<'EOF'
[Unit]
Description=Weather API (FastAPI/uvicorn) from repo
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/app/AWS-LoadBalancer-ASG-Project/aws-weather-api
EnvironmentFile=/etc/default/weather
ExecStart=/opt/app/AWS-LoadBalancer-ASG-Project/aws-weather-api/start.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable + start
systemctl daemon-reload
systemctl enable --now weather
```

> **Note:** If you standardize on port **8000** instead, set `PORT=8000`, adjust the Target Group port and the EC2 SG rule to TCP 8000 from the ALB SG.

---

## Step 8 — Auto Scaling Group (explicit names, private subnets)

**Console:** EC2 → Auto Scaling Groups → **Create Auto Scaling group**

* **Auto Scaling group name:** `wl-asg`
* **Launch template:** `wl-lt` (Default version)
* **VPC:** `wl-vpc`
* **Subnets:** `wl-subnet-private-a`, `wl-subnet-private-b`
* **Load balancing:** Attach to existing **Application Load Balancer**

  * **Load balancer:** `wl-alb`
  * **Target group:** `wl-tg-5000`
  * **Health checks:** **Turn on ELB health checks**
* **Group size:** Desired **2**, Min **1**, Max **4**
* **Scaling policy:** Target tracking

  * **Metric:** **ALB RequestCountPerTarget**
  * **Target group:** `wl-tg-5000`
  * **Target value:** **50**
  * **Instance warm-up:** **120s**
* **Create Auto Scaling group**

---

## Step 9 — Verify Health (by name)

### 9.1 Targets

**Console:** EC2 → Target Groups → `wl-tg-5000` → **Targets**
You should see 2 instances moving to **healthy (green)**.

**If unhealthy:**

* **Security groups:** `wl-sg-ec2` must allow **TCP 5000** **from** `wl-sg-alb`.
* **Service logs:** EC2 → Instances → *(an instance)* → **Connect (Session Manager)**

  ```bash
  sudo systemctl status weather
  sudo journalctl -u weather -f
  ```
* **Health check path:** ensure `/` returns 200; otherwise set TG Health check path to **`/health`**.

### 9.2 Load Balancer DNS

**Console:** EC2 → Load Balancers → `wl-alb` → **Details**
Copy the **DNS name** (e.g., `wl-alb-123456.us-west-2.elb.amazonaws.com`)

Open in browser:

```
http://<wl-alb DNS name>/
http://<wl-alb DNS name>/health
```

---

## Step 10 — (Optional) HTTPS (named parts)

* **ACM (Certificate Manager)** → Request public certificate for your domain (e.g., `api.yourdomain.com`).
* **Route 53 → A (Alias)** → point `api.yourdomain.com` to ALB `wl-alb`.
* **EC2 → Load Balancers → wl-alb → Listeners → Add listener**

  * **HTTPS :443** → Default action: **Forward** → `wl-tg-5000` (choose ACM cert)
* *(Optional)* Edit HTTP :80 listener to **redirect to HTTPS**.

---

## Step 11 — (Optional) Load Test & Observe Scaling

From your laptop/mac:

**`hey` (Homebrew):**

```bash
hey -z 2m -q 5 http://<wl-alb DNS>/
```

**`wrk` (Homebrew):**

```bash
wrk -t4 -c32 -d60s http://<wl-alb DNS>/weather/new-york
```

**`ab` (ApacheBench via Homebrew httpd):**

```bash
ab -n 10000 -c 50 http://<wl-alb DNS>/weather/new-york
```

**Node `autocannon` (example using a real DNS you shared):**

```bash
npx autocannon -d 180 -c 80 \
  http://weather-lab-alb-v2-1533197798.us-east-1.elb.amazonaws.com/weather/new-york
```

**Watch scaling:**

* **EC2 → Auto Scaling Groups → wl-asg → Activity** (scale-out events)
* **CloudWatch → Metrics → ALB / Target Group** → `RequestCountPerTarget`, `TargetResponseTime`

> For RequestCountPerTarget scaling, prefer high‑concurrency requests to `/weather/new-york`. Use `/weather/bulk/cities` if you want to make each request heavier on CPU.

---

## Step 12 — Cleanup (delete by name, in order)

1. **Auto Scaling Group:** `wl-asg` → **Delete**
2. **Load Balancer:** `wl-alb` → **Delete**
3. **Target Group:** `wl-tg-5000` → **Delete**
4. **Launch Template:** `wl-lt` → **Delete**
5. **Security Groups:** `wl-sg-ec2`, `wl-sg-alb` → **Delete**
6. **NAT Gateway:** `wl-natgw-a` → **Delete** (wait until deleted)
7. **Elastic IP:** `wl-eip-nat-a` → **Release**
8. **Internet Gateway:** `wl-igw` → **Detach from `wl-vpc`** → **Delete**
9. **Route Tables:** `wl-rtb-private-a`, `wl-rtb-private-b`, `wl-rtb-public` → **Delete** (non‑main only)
10. **Subnets:** `wl-subnet-public-a`, `wl-subnet-public-b`, `wl-subnet-private-a`, `wl-subnet-private-b` → **Delete**
11. **VPC:** `wl-vpc` → **Delete**
12. **IAM Role:** `wl-role-ec2-ssm` (and its instance profile) → **Delete**
13. **Key Pair:** `wl-kp` (optional) → **Delete**
14. **Parameter Store key** `/weather/OPENWEATHER_API_KEY` (if created) → **Delete**

---

## Quick “Name Map” (for your checklist)

* **VPC:** `wl-vpc (10.20.0.0/16)`
* **Internet Gateway:** `wl-igw`
* **Elastic IP:** `wl-eip-nat-a`
* **NAT Gateway:** `wl-natgw-a` (in `wl-subnet-public-a`)
* **Subnets:**

  * Public: `wl-subnet-public-a (10.20.1.0/24)`, `wl-subnet-public-b (10.20.2.0/24)`
  * Private: `wl-subnet-private-a (10.20.11.0/24)`, `wl-subnet-private-b (10.20.12.0/24)`
* **Route Tables:** `wl-rtb-public` (→ IGW), `wl-rtb-private-a` (→ NAT), `wl-rtb-private-b` (→ NAT)
* **Security Groups:** `wl-sg-alb` (HTTP 80 from `0.0.0.0/0`), `wl-sg-ec2` (TCP 5000 **from** `wl-sg-alb`)
* **IAM Role:** `wl-role-ec2-ssm`
* **Key Pair:** `wl-kp`
* **Target Group:** `wl-tg-5000` (HC `/` or `/health`)
* **Load Balancer:** `wl-alb` (HTTP:80 → `wl-tg-5000`)
* **Launch Template:** `wl-lt`
* **Auto Scaling Group:** `wl-asg` (private subnets, ELB health, target tracking 50 req/target/min)

---

## Appendix A — Subnets, IGW, EIP, NAT, Route Tables

> This is the same content from Step 1 (expanded for clarity).

* **Create subnets** in `wl-vpc`:

  * `wl-subnet-public-a (us-west-2a, 10.20.1.0/24)`
  * `wl-subnet-public-b (us-west-2b, 10.20.2.0/24)`
  * `wl-subnet-private-a (us-west-2a, 10.20.11.0/24)`
  * `wl-subnet-private-b (us-west-2b, 10.20.12.0/24)`
* **Internet Gateway:** `wl-igw` → attach to `wl-vpc`.
* **Elastic IP:** `wl-eip-nat-a` → allocate.
* **NAT GW:** `wl-natgw-a` in `wl-subnet-public-a` using `wl-eip-nat-a`.
* **Route tables:**

  * `wl-rtb-public` → default route `0.0.0.0/0` to **IGW** → associate both **public** subnets.
  * `wl-rtb-private-a` → default route `0.0.0.0/0` to **NAT GW** `wl-natgw-a` → associate **private-a**.
  * `wl-rtb-private-b` → default route `0.0.0.0/0` to **NAT GW** `wl-natgw-a` → associate **private-b**.

---

## Appendix B — Session Manager (SSM) quick setup on Ubuntu

If the **Session Manager** button is greyed out (or you want to ensure SSM is present):

**Prereqs:**

* Instance IAM role attached: typically `wl-role-ec2-ssm` *(or `wl-ue1-role-ec2-ssm` if you’re running in us‑east‑1 and used that name)*.
* Private subnets must have outbound internet through **NAT**.

**Install/enable SSM Agent (Ubuntu 24.04):**

```bash
sudo -i
apt-get update -y
apt-get install -y snapd
snap install amazon-ssm-agent --classic
systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service
```

**Open a shell (browser):** EC2 → Instances → select instance → **Connect** → **Session Manager** → **Connect**.

---

## Appendix C — Example macOS load test (Node `autocannon`)

```bash
npx autocannon -d 180 -c 80 \
  http://weather-lab-alb-v2-1533197798.us-east-1.elb.amazonaws.com/weather/new-york
```

> Replace the URL with your **ALB DNS** if different. Stop any test with **CTRL+C**.
