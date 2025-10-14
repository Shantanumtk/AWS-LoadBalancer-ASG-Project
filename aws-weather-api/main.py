from fastapi import FastAPI, Query
from fastapi.responses import JSONResponse
import uvicorn
import requests
import time
import psutil
from datetime import datetime
from typing import List

app = FastAPI(
    title="Weather Data Aggregator",
    version="1.0.0",
    description="AWS Auto Scaling Lab - FastAPI Weather API"
)

# Global request counter
request_count = 0

# Simulated weather data
WEATHER_DATA = {
    "new-york": {"temp": 72, "condition": "Sunny", "humidity": 65, "wind": "10 mph"},
    "london": {"temp": 59, "condition": "Cloudy", "humidity": 78, "wind": "15 mph"},
    "tokyo": {"temp": 68, "condition": "Rainy", "humidity": 82, "wind": "8 mph"},
    "paris": {"temp": 64, "condition": "Partly Cloudy", "humidity": 70, "wind": "12 mph"},
    "sydney": {"temp": 75, "condition": "Clear", "humidity": 60, "wind": "5 mph"},
    "mumbai": {"temp": 86, "condition": "Humid", "humidity": 90, "wind": "7 mph"},
    "dubai": {"temp": 95, "condition": "Hot", "humidity": 45, "wind": "20 mph"},
    "toronto": {"temp": 55, "condition": "Windy", "humidity": 68, "wind": "25 mph"},
    "berlin": {"temp": 62, "condition": "Overcast", "humidity": 72, "wind": "14 mph"},
    "singapore": {"temp": 88, "condition": "Humid", "humidity": 85, "wind": "6 mph"},
}


def get_instance_metadata():
    """
    Fetch EC2 instance metadata using IMDSv2 (Instance Metadata Service Version 2)
    Returns instance_id, availability_zone, and instance_type
    """
    try:
        # Get IMDSv2 token (more secure than IMDSv1)
        token_response = requests.put(
            "http://169.254.169.254/latest/api/token",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"},
            timeout=2
        )
        token = token_response.text
        
        headers = {"X-aws-ec2-metadata-token": token}
        
        # Fetch instance metadata
        instance_id = requests.get(
            "http://169.254.169.254/latest/meta-data/instance-id",
            headers=headers,
            timeout=2
        ).text
        
        availability_zone = requests.get(
            "http://169.254.169.254/latest/meta-data/placement/availability-zone",
            headers=headers,
            timeout=2
        ).text
        
        instance_type = requests.get(
            "http://169.254.169.254/latest/meta-data/instance-type",
            headers=headers,
            timeout=2
        ).text
        
        private_ip = requests.get(
            "http://169.254.169.254/latest/meta-data/local-ipv4",
            headers=headers,
            timeout=2
        ).text
        
        return {
            "instance_id": instance_id,
            "availability_zone": availability_zone,
            "instance_type": instance_type,
            "private_ip": private_ip
        }
    except Exception as e:
        # Fallback for local development
        return {
            "instance_id": "local-development",
            "availability_zone": "local",
            "instance_type": "local",
            "private_ip": "127.0.0.1",
            "error": str(e)
        }


@app.get("/")
async def root():
    """
    Root endpoint - Returns welcome message with instance information
    """
    global request_count
    request_count += 1
    
    metadata = get_instance_metadata()
    
    return {
        "message": "🌦️ Weather Data Aggregator API",
        "version": "1.0.0",
        "description": "AWS Auto Scaling and Load Balancing Demo",
        "instance_info": metadata,
        "requests_served_by_this_instance": request_count,
        "timestamp": datetime.utcnow().isoformat(),
        "endpoints": {
            "health": "/health",
            "weather": "/weather/{city}",
            "bulk_weather": "/weather/bulk/cities?cities=new-york&cities=london",
            "instance_info": "/instance-info",
            "load_test": "/generate-load?duration=30"
        }
    }


@app.get("/health")
async def health_check():
    """
    Health check endpoint for Application Load Balancer
    Returns current system resource usage
    """
    cpu_percent = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    # Determine health status based on resource usage
    status = "healthy"
    if cpu_percent > 90 or memory.percent > 90:
        status = "degraded"
    
    return {
        "status": status,
        "system_resources": {
            "cpu_usage_percent": round(cpu_percent, 2),
            "memory_usage_percent": round(memory.percent, 2),
            "memory_available_gb": round(memory.available / (1024**3), 2),
            "disk_usage_percent": round(disk.percent, 2)
        },
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/weather/{city}")
async def get_weather(city: str):
    """
    Get weather data for a specific city
    Simulates processing delay to demonstrate load distribution
    """
    global request_count
    request_count += 1
    
    # Simulate API processing time
    time.sleep(0.5)
    
    # Normalize city name
    city_key = city.lower().replace(" ", "-")
    weather = WEATHER_DATA.get(city_key)
    
    if not weather:
        return JSONResponse(
            status_code=404,
            content={
                "error": f"Weather data not found for '{city}'",
                "available_cities": list(WEATHER_DATA.keys()),
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    
    metadata = get_instance_metadata()
    
    return {
        "city": city.title(),
        "weather": weather,
        "served_by_instance": metadata["instance_id"],
        "availability_zone": metadata["availability_zone"],
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/weather/bulk/cities")
async def get_bulk_weather(
    cities: List[str] = Query(
        default=["new-york", "london", "tokyo"],
        description="List of cities to get weather for"
    )
):
    """
    Get weather for multiple cities (CPU-intensive operation)
    This endpoint is designed to trigger auto-scaling
    """
    global request_count
    request_count += 1
    
    start_time = time.time()
    results = []
    
    # Process each city with artificial CPU load
    for city in cities:
        time.sleep(0.3)  # Simulate I/O delay
        
        city_key = city.lower().replace(" ", "-")
        weather = WEATHER_DATA.get(city_key)
        
        if not weather:
            weather = {"error": "City not found"}
        
        # Simulate CPU-intensive processing
        _ = sum([i ** 2 for i in range(10000)])
        
        results.append({
            "city": city.title(),
            "weather": weather
        })
    
    processing_time = time.time() - start_time
    metadata = get_instance_metadata()
    
    return {
        "cities_processed": len(cities),
        "results": results,
        "processing_time_seconds": round(processing_time, 2),
        "served_by_instance": metadata["instance_id"],
        "availability_zone": metadata["availability_zone"],
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/instance-info")
async def instance_info():
    """
    Get detailed information about the EC2 instance
    Useful for debugging and monitoring load distribution
    """
    global request_count
    
    metadata = get_instance_metadata()
    cpu_percent = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    # Get CPU count
    cpu_count = psutil.cpu_count()
    
    return {
        "instance_metadata": metadata,
        "system_info": {
            "cpu_count": cpu_count,
            "cpu_usage_percent": round(cpu_percent, 2),
            "memory_total_gb": round(memory.total / (1024**3), 2),
            "memory_used_gb": round(memory.used / (1024**3), 2),
            "memory_available_gb": round(memory.available / (1024**3), 2),
            "memory_percent": round(memory.percent, 2),
            "disk_total_gb": round(disk.total / (1024**3), 2),
            "disk_used_gb": round(disk.used / (1024**3), 2),
            "disk_free_gb": round(disk.free / (1024**3), 2),
            "disk_percent": round(disk.percent, 2)
        },
        "application_stats": {
            "requests_served_by_this_instance": request_count,
            "python_version": "3.11"
        },
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/generate-load")
async def generate_load(
    duration: int = Query(
        default=30,
        ge=10,
        le=300,
        description="Duration in seconds (10-300)"
    )
):
    """
    Generate CPU load for testing auto-scaling
    WARNING: This will consume significant CPU resources
    """
    global request_count
    request_count += 1
    
    metadata = get_instance_metadata()
    start_time = time.time()
    
    print(f"[LOAD TEST] Starting {duration}s load generation on {metadata['instance_id']}")
    
    # Generate CPU load for specified duration
    end_time = start_time + duration
    iterations = 0
    
    while time.time() < end_time:
        # CPU-intensive operation
        _ = sum([i ** 2 for i in range(100000)])
        iterations += 1
    
    elapsed = time.time() - start_time
    
    print(f"[LOAD TEST] Completed {iterations} iterations in {elapsed:.2f}s")
    
    return {
        "message": "Load generation completed successfully",
        "duration_seconds": round(elapsed, 2),
        "iterations_completed": iterations,
        "average_iterations_per_second": round(iterations / elapsed, 2),
        "served_by_instance": metadata["instance_id"],
        "availability_zone": metadata["availability_zone"],
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/cities")
async def list_cities():
    """
    List all available cities
    """
    return {
        "total_cities": len(WEATHER_DATA),
        "cities": [city.replace("-", " ").title() for city in WEATHER_DATA.keys()],
        "timestamp": datetime.utcnow().isoformat()
    }


if __name__ == "__main__":
    # This is used when running locally
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )