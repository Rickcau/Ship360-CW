#!/bin/bash
cd /home/site/wwwroot

# Echo progress for better logging
echo "Starting deployment process from startup.sh"

# Create a log file
exec > >(tee -a /home/LogFiles/startup.log) 2>&1
echo "$(date): Starting application deployment"

# Wait for any previous processes to finish
echo "Waiting for any package operations to finish..."
for i in {1..30}; do
    if ps aux | grep -q "[p]ip install"; then
        echo "Package installation is still running... waiting (attempt $i of 30)"
        sleep 10
    else
        break
    fi
done

# Install dependencies
echo "Installing dependencies from requirements.txt..."
pip install --no-cache-dir -r requirements.txt

# Export environment variables
echo "Setting up environment variables..."
export PYTHONPATH=/home/site/wwwroot:$PYTHONPATH

# Start the FastAPI application with Gunicorn
echo "Starting FastAPI application with Gunicorn..."
exec gunicorn app.main:app --workers 2 --worker-class uvicorn.workers.UvicornWorker --timeout 600 --bind 0.0.0.0:8000 --access-logfile '-' --error-logfile '-'