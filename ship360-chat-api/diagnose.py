#!/usr/bin/env python3
"""
Diagnostic script for Ship360 Chat API deployment issues.
This script helps identify common problems in Azure App Service deployments.
"""

import os
import sys
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

def main():
    """Run comprehensive diagnostics."""
    logger.info("=== Ship360 Chat API Deployment Diagnostics ===")
    
    # 1. Check Python environment
    logger.info(f"Python version: {sys.version}")
    logger.info(f"Python executable: {sys.executable}")
    
    # 2. Check current directory and files
    cwd = Path.cwd()
    logger.info(f"Current working directory: {cwd}")
    
    logger.info("Files in current directory:")
    try:
        for item in sorted(cwd.iterdir()):
            if item.is_file():
                logger.info(f"  📄 {item.name} ({item.stat().st_size} bytes)")
            elif item.is_dir():
                logger.info(f"  📁 {item.name}/")
    except Exception as e:
        logger.error(f"Error listing directory: {e}")
    
    # 3. Check for key files
    key_files = ['app/main.py', 'requirements.txt', 'startup.py', 'startup_wrapper.py']
    logger.info("\nChecking for key files:")
    for file_path in key_files:
        path = cwd / file_path
        if path.exists():
            logger.info(f"  ✅ {file_path}")
        else:
            logger.warning(f"  ❌ {file_path} - MISSING")
    
    # 4. Check environment variables
    logger.info("\nEnvironment variables:")
    env_vars = sorted(os.environ.items())
    for key, value in env_vars:
        if any(sensitive in key.upper() for sensitive in ['PASSWORD', 'SECRET', 'KEY', 'TOKEN']):
            logger.info(f"  {key}=***HIDDEN***")
        else:
            logger.info(f"  {key}={value}")
    
    # 5. Try importing key modules
    logger.info("\nTesting imports:")
    modules_to_test = [
        'fastapi',
        'uvicorn',
        'gunicorn',
        'pydantic',
        'openai',
        'app.main'
    ]
    
    for module in modules_to_test:
        try:
            __import__(module)
            logger.info(f"  ✅ {module}")
        except ImportError as e:
            logger.error(f"  ❌ {module} - {e}")
        except Exception as e:
            logger.warning(f"  ⚠️  {module} - {e}")
    
    # 6. Test FastAPI app creation
    logger.info("\nTesting FastAPI app:")
    try:
        from app.main import app
        logger.info(f"  ✅ FastAPI app created: {type(app)}")
        
        # Try to get the routes
        if hasattr(app, 'routes'):
            logger.info(f"  ✅ Routes available: {len(app.routes)} routes")
            for route in app.routes[:5]:  # Show first 5 routes
                if hasattr(route, 'path'):
                    logger.info(f"    - {route.path}")
        
    except Exception as e:
        logger.error(f"  ❌ FastAPI app creation failed: {e}")
        import traceback
        logger.error(traceback.format_exc())
    
    logger.info("\n=== Diagnostics Complete ===")

if __name__ == "__main__":
    main()