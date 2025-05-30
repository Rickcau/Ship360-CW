#!/usr/bin/env python3
"""
Simplified startup script for Ship360 Chat API on Azure App Service.
This script starts the FastAPI application with minimal overhead.
"""

import os
import sys
import subprocess

def main():
    """Start the FastAPI application directly with gunicorn."""
    
    # Get port from environment (Azure App Service sets this)
    port = os.environ.get('PORT', '8000')
    
    print(f"Starting Ship360 Chat API on port {port}...")
    print(f"Python executable: {sys.executable}")
    print(f"Working directory: {os.getcwd()}")
    
    # Try different startup methods in order of preference
    
    # Method 1: Direct gunicorn command (most reliable for production)
    try:
        cmd = [
            sys.executable, "-m", "gunicorn",
            "app.main:app",
            "-w", "1",  # Single worker
            "-k", "uvicorn.workers.UvicornWorker",
            f"--bind=0.0.0.0:{port}",
            "--timeout", "120",
            "--log-level", "info"
        ]
        
        print(f"Method 1 - Gunicorn: {' '.join(cmd)}")
        os.execv(sys.executable, cmd)
        
    except Exception as e:
        print(f"Method 1 failed: {e}")
        pass
    
    # Method 2: Uvicorn fallback
    try:
        cmd = [
            sys.executable, "-m", "uvicorn",
            "app.main:app",
            "--host", "0.0.0.0",
            "--port", port,
            "--log-level", "info"
        ]
        
        print(f"Method 2 - Uvicorn: {' '.join(cmd)}")
        os.execv(sys.executable, cmd)
        
    except Exception as e:
        print(f"Method 2 failed: {e}")
        pass
    
    # Method 3: Last resort - try to run with subprocess
    try:
        print("Method 3 - Subprocess fallback...")
        import subprocess
        
        cmd = [
            sys.executable, "-c",
            f"""
import uvicorn
import os
from app.main import app

if __name__ == "__main__":
    port = int(os.environ.get('PORT', '{port}'))
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")
"""
        ]
        
        print(f"Method 3 command: {' '.join(cmd)}")
        result = subprocess.run(cmd)
        sys.exit(result.returncode)
        
    except Exception as e:
        print(f"Method 3 failed: {e}")
        print("All startup methods failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()