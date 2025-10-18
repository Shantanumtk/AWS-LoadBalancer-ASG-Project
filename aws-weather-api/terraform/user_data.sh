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
