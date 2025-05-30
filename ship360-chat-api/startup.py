#!/usr/bin/env python3
"""
Startup script for Ship360 Chat API on Azure App Service
This script provides better error handling and logging for deployment issues.
"""

import os
import sys
import logging
import subprocess
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
        logger.warning(f"⚠️  Missing environment variables: {', '.join(missing_vars)}")
        logger.warning("The application may not function correctly without these variables.")
        logger.warning("Please check your Azure App Service configuration settings.")
        
        # Check if we're in a test/development environment
        if os.getenv('ENVIRONMENT') in ['test', 'development', 'dev']:
            logger.info("Running in development mode - allowing startup with missing variables")
            return True
        
        # For production, still warn but allow startup for debugging
        logger.warning("Allowing startup for debugging purposes...")
        return True
    
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
            logger.info(f"✓ {package} is available")
        except ImportError:
            missing_packages.append(package)
            logger.warning(f"✗ {package} is not available")
    
    if missing_packages:
        logger.error(f"Missing required packages: {', '.join(missing_packages)}")
        logger.error("This likely indicates the virtual environment is not activated or packages are not installed.")
        logger.error("In Azure App Service, packages should be installed globally during deployment.")
        return False
    
    logger.info("✓ All required packages are available")
    return True

def start_app():
    """Start the FastAPI application with gunicorn"""
    import subprocess
    
    # Get port from environment
    port = os.environ.get('PORT', '8000')
    logger.info(f"✅ Starting application on port {port}...")
    
    # Log Python and package information
    logger.info(f"Python executable: {sys.executable}")
    logger.info(f"Python version: {sys.version}")
    logger.info(f"Python path: {sys.path}")
    
    # Log environment variables (excluding sensitive ones)
    logger.info("Environment variables:")
    for key, value in sorted(os.environ.items()):
        if any(sensitive in key.upper() for sensitive in ['PASSWORD', 'SECRET', 'KEY', 'TOKEN']):
            logger.info(f"  {key}=***HIDDEN***")
        else:
            logger.info(f"  {key}={value}")
    
    # Use system Python - Azure App Service should have packages installed globally
    python_cmd = sys.executable
    logger.info(f"✅ Using Python: {python_cmd}")
    
    # Try gunicorn first (recommended for production)
    try:
        # Start gunicorn with conservative settings
        cmd = [
            python_cmd, "-m", "gunicorn",
            "-w", "1",  # Single worker for debugging
            "-k", "uvicorn.workers.UvicornWorker", 
            "app.main:app",
            f"--bind=0.0.0.0:{port}",
            "--timeout", "300",
            "--keep-alive", "2",
            "--max-requests", "1000", 
            "--max-requests-jitter", "50",
            "--log-level", "info",
            "--access-logfile", "-",
            "--error-logfile", "-"
        ]
        
        logger.info(f"Executing gunicorn command: {' '.join(cmd)}")
        os.execv(python_cmd, cmd)
        
    except Exception as e:
        logger.error(f"Failed to start with gunicorn: {e}")
        logger.info("Trying fallback to uvicorn...")
        
        try:
            # Fallback to uvicorn
            cmd = [
                python_cmd, "-m", "uvicorn",
                "app.main:app",
                "--host", "0.0.0.0",
                "--port", port,
                "--log-level", "info"
            ]
            
            logger.info(f"Executing uvicorn command: {' '.join(cmd)}")
            os.execv(python_cmd, cmd)
            
        except Exception as e2:
            logger.error(f"Failed to start with uvicorn: {e2}")
            logger.error("Both gunicorn and uvicorn startup attempts failed")
            sys.exit(1)

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
    
    # Validate environment (now more forgiving)
    env_valid = validate_environment()
    if not env_valid:
        logger.warning("❌ Environment validation had issues, but continuing...")
    
    # Check dependencies (more forgiving for startup debugging)
    deps_valid = check_dependencies()
    if not deps_valid:
        logger.warning("❌ Some dependencies may be missing, but continuing startup for debugging...")
    
    # Try to import the app to check for import errors
    try:
        logger.info("Attempting to import FastAPI application...")
        from app.main import app
        logger.info("✓ FastAPI application imported successfully")
    except Exception as e:
        logger.error(f"⚠️  Could not import FastAPI application: {e}")
        logger.error("This indicates missing dependencies or configuration issues.")
        
        # If we can't import the app, try to provide helpful information
        try:
            logger.error(f"Python path: {sys.path}")
            logger.error("Attempting to show installed packages...")
            result = subprocess.run([sys.executable, "-m", "pip", "list"], 
                                  capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                logger.error(f"Installed packages:\n{result.stdout}")
            else:
                logger.error(f"Failed to get package list: {result.stderr}")
        except Exception as debug_e:
            logger.error(f"Could not gather debug information: {debug_e}")
        
        logger.error("Application startup will fail due to import errors.")
        sys.exit(1)
    
    if env_valid and deps_valid:
        logger.info("✅ Startup validation completed successfully!")
    else:
        logger.warning("⚠️  Startup validation completed with warnings")
    
    logger.info("Starting FastAPI application...")
    start_app()

if __name__ == "__main__":
    main()