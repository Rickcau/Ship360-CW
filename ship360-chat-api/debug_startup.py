#!/usr/bin/env python3
"""
Debug script for troubleshooting Ship360 Chat API startup issues.
Run this script via SSH to diagnose deployment problems.
"""

import os
import sys
import subprocess
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

def check_environment():
    """Check environment variables."""
    logger.info("=== ENVIRONMENT VARIABLES ===")
    
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
        'SP360_TRACKING_URL',
        'PORT'
    ]
    
    missing_vars = []
    for var in required_vars:
        value = os.getenv(var)
        if value:
            # Hide sensitive values
            if any(sensitive in var.upper() for sensitive in ['PASSWORD', 'SECRET', 'KEY', 'TOKEN']):
                logger.info(f"✓ {var}=***HIDDEN*** (length: {len(value)})")
            else:
                logger.info(f"✓ {var}={value}")
        else:
            missing_vars.append(var)
            logger.warning(f"✗ {var}=<NOT SET>")
    
    if missing_vars:
        logger.warning(f"Missing variables: {', '.join(missing_vars)}")
    else:
        logger.info("All required environment variables are set")

def check_python_environment():
    """Check Python environment and packages."""
    logger.info("=== PYTHON ENVIRONMENT ===")
    logger.info(f"Python executable: {sys.executable}")
    logger.info(f"Python version: {sys.version}")
    logger.info(f"Working directory: {os.getcwd()}")
    
    # List directory contents
    try:
        contents = list(os.listdir('.'))
        logger.info(f"Directory contents: {contents}")
    except Exception as e:
        logger.error(f"Could not list directory: {e}")

def check_packages():
    """Check installed packages."""
    logger.info("=== INSTALLED PACKAGES ===")
    
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
        except ImportError as e:
            missing_packages.append(package)
            logger.warning(f"✗ {package} is not available: {e}")
    
    # Show all installed packages
    try:
        result = subprocess.run([sys.executable, "-m", "pip", "list"], 
                              capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            logger.info("All installed packages:")
            for line in result.stdout.split('\n')[:20]:  # Show first 20 lines
                if line.strip():
                    logger.info(f"  {line}")
        else:
            logger.error(f"Failed to get package list: {result.stderr}")
    except Exception as e:
        logger.error(f"Could not get package list: {e}")

def test_app_import():
    """Test importing the FastAPI application."""
    logger.info("=== APPLICATION IMPORT TEST ===")
    
    try:
        logger.info("Attempting to import FastAPI application...")
        from app.main import app
        logger.info("✓ FastAPI application imported successfully")
        logger.info(f"App type: {type(app)}")
        logger.info(f"App title: {getattr(app, 'title', 'Unknown')}")
        return True
    except Exception as e:
        logger.error(f"✗ Could not import FastAPI application: {e}")
        logger.error(f"Error type: {type(e).__name__}")
        
        # Try to import individual components
        try:
            logger.info("Testing individual component imports...")
            import fastapi
            logger.info(f"✓ fastapi version: {fastapi.__version__}")
            
            from app.core.config import settings
            logger.info("✓ settings imported successfully")
            
            from app.api.routes import chat
            logger.info("✓ chat routes imported successfully")
            
        except Exception as component_error:
            logger.error(f"✗ Component import failed: {component_error}")
        
        return False

def test_startup_commands():
    """Test different startup commands."""
    logger.info("=== STARTUP COMMAND TESTS ===")
    
    port = os.environ.get('PORT', '8000')
    
    # Test gunicorn
    try:
        cmd = [sys.executable, "-m", "gunicorn", "--version"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            logger.info(f"✓ gunicorn available: {result.stdout.strip()}")
        else:
            logger.warning(f"✗ gunicorn test failed: {result.stderr}")
    except Exception as e:
        logger.warning(f"✗ gunicorn test error: {e}")
    
    # Test uvicorn
    try:
        cmd = [sys.executable, "-m", "uvicorn", "--version"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            logger.info(f"✓ uvicorn available: {result.stdout.strip()}")
        else:
            logger.warning(f"✗ uvicorn test failed: {result.stderr}")
    except Exception as e:
        logger.warning(f"✗ uvicorn test error: {e}")

def main():
    """Run all diagnostic checks."""
    logger.info("🔍 Starting Ship360 Chat API diagnostic checks...")
    logger.info("=" * 60)
    
    check_environment()
    logger.info("")
    
    check_python_environment()
    logger.info("")
    
    check_packages()
    logger.info("")
    
    app_imported = test_app_import()
    logger.info("")
    
    test_startup_commands()
    logger.info("")
    
    logger.info("=" * 60)
    if app_imported:
        logger.info("✅ Diagnostic complete - Application should be able to start")
        logger.info("Try running: python startup.py")
    else:
        logger.error("❌ Diagnostic complete - Application has import issues")
        logger.error("Fix the import errors before attempting to start the application")

if __name__ == "__main__":
    main()