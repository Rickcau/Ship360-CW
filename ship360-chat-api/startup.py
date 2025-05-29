#!/usr/bin/env python3
"""
Startup script for Ship360 Chat API on Azure App Service
This script provides better error handling and logging for deployment issues.
"""

import os
import sys
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/tmp/startup.log') if os.path.exists('/tmp') else logging.NullHandler()
    ]
)

logger = logging.getLogger(__name__)

def validate_environment():
    """Validate required environment variables before starting the app."""
    required_vars = [
        'AZURE_OPENAI_API_KEY',
        'AZURE_OPENAI_ENDPOINT', 
        'AZURE_OPENAI_API_VERSION',
        'AZURE_OPENAI_CHAT_DEPLOYMENT_NAME',
        'SP360_TOKEN_URL',
        'SP360_TOKEN_USERNAME', 
        'SP360_TOKEN_PASSWORD',
        'SP360_RATE_SHOP_URL',
        'SP360_SHIPMENTS_URL',
        'SP360_TRACKING_URL'
    ]
    
    missing_vars = []
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        logger.error(f"Missing required environment variables: {', '.join(missing_vars)}")
        logger.error("Please check your Azure App Service configuration settings.")
        return False
    
    logger.info("✓ All required environment variables are present")
    return True

def check_dependencies():
    """Check if required Python packages are available."""
    required_packages = [
        'fastapi',
        'uvicorn', 
        'gunicorn',
        'pydantic',
        'pydantic_settings',
        'openai',
        'semantic_kernel'
    ]
    
    missing_packages = []
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing_packages.append(package)
    
    if missing_packages:
        logger.error(f"Missing required packages: {', '.join(missing_packages)}")
        return False
    
    logger.info("✓ All required packages are available")
    return True

def main():
    """Main startup validation and app initialization."""
    logger.info("🚀 Starting Ship360 Chat API startup validation...")
    
    # Check Python version
    python_version = sys.version_info
    logger.info(f"Python version: {python_version.major}.{python_version.minor}.{python_version.micro}")
    
    # Check working directory
    cwd = os.getcwd()
    logger.info(f"Current working directory: {cwd}")
    
    # List contents to help debug
    try:
        contents = list(os.listdir(cwd))
        logger.info(f"Directory contents: {contents}")
    except Exception as e:
        logger.warning(f"Could not list directory contents: {e}")
    
    # Validate environment
    if not validate_environment():
        logger.error("❌ Environment validation failed")
        sys.exit(1)
    
    # Check dependencies
    if not check_dependencies():
        logger.error("❌ Dependency check failed")
        sys.exit(1)
    
    # Try to import the app to check for import errors
    try:
        logger.info("Attempting to import FastAPI application...")
        from app.main import app
        logger.info("✓ FastAPI application imported successfully")
    except Exception as e:
        logger.error(f"❌ Failed to import FastAPI application: {e}")
        logger.error("This indicates a problem with the application code or dependencies.")
        sys.exit(1)
    
    logger.info("✅ Startup validation completed successfully!")
    logger.info("Application is ready to start...")

if __name__ == "__main__":
    main()