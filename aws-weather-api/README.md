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