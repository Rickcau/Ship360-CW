# Ship360 Chat API - FastAPI Documentation

## Project Overview

The Ship360 Chat API is a FastAPI-based application that provides chat functionality powered by Azure OpenAI and Semantic Kernel Plugins. The API interacts with the Shipping 360 API for rate shopping, shipment processing, and tracking functionality.

## Project Structure

```
ship360-chat-api/
├── app/                     # Main application directory
│   ├── api/                 # API routes and endpoints
│   │   └── routes/          # API route handlers
│   │       └── chat.py      # Chat endpoints
│   ├── core/                # Core application configuration
│   │   ├── config.py        # Settings and configuration
│   │   └── settings.py      # Additional settings
│   ├── models/              # Data models and schemas
│   ├── prompts/             # Prompt templates for AI
│   ├── plugins/             # Semantic Kernel plugins
│   ├── services/            # Service layer
│   │   └── thread_store.py  # Chat thread management
│   ├── utils/               # Utility functions
│   ├── __init__.py          # Package initialization
│   └── main.py              # Application entry point
├── tests/                   # Test directory
├── .env_sample              # Environment variables template
├── requirements.txt         # Python dependencies
├── startup.sh               # Startup script for deployment
└── README.md                # Project documentation
```

## Key Files

### main.py

The `main.py` file is the entry point for the FastAPI application. It:
- Configures the FastAPI app with settings and middleware
- Sets up CORS to allow cross-origin requests
- Includes the API routes
- Configures exception handlers for better error responses
- Provides custom Swagger UI for API documentation
- Implements a health check endpoint
- Includes a background thread for cleaning up stale chat threads

### config.py

The `config.py` file defines the application settings using Pydantic's `BaseSettings` class. It loads environment variables from a `.env` file and defines configuration for:
- Project settings (name, API prefix)
- CORS configuration
- Azure OpenAI API settings
- Shipping 360 API credentials and endpoints

## Environment Variables (.env)

The following environment variables are required for the application:

```
# Azure OpenAI configuration
AZURE_OPENAI_ENDPOINT="{your-azure-openai-endpoint}"
AZURE_OPENAI_API_KEY="{your-azure-openai-api-key}"
AZURE_OPENAI_CHAT_DEPLOYMENT_NAME="gpt-4o"
AZURE_OPENAI_API_VERSION="{api-version}"

# Shipping 360 API configuration
SP360_TOKEN_URL="{sp360-token-url}"
SP360_TOKEN_USERNAME="{username}"
SP360_TOKEN_PASSWORD="{password}"
SP360_RATE_SHOP_URL="{rate-shop-url}"
SP360_SHIPMENTS_URL="{shipments-url}"
SP360_TRACKING_URL="{tracking-url}"
```

## Dependencies (requirements.txt)

The application requires the following dependencies:

- **fastapi==0.103.1**: Web framework for building APIs
- **uvicorn==0.23.2**: ASGI server for FastAPI
- **pydantic>=2.4.2**: Data validation and settings management
- **pytest>=7.4.3**: Testing framework
- **pydantic-settings>=2.0.0**: Pydantic settings management
- **python-dotenv==1.0.0**: Loading environment variables from .env file
- **httpx==0.24.1**: HTTP client
- **openai>=1.67.0**: OpenAI client library
- **openapi_core>=0.18,<0.20**: OpenAPI validation
- **python-multipart==0.0.6**: Multipart form parsing
- **semantic-kernel>=1.28.0**: Microsoft's Semantic Kernel framework
- **gunicorn==21.2.0**: WSGI HTTP server
- **azure-search-documents==11.4.0**: Azure Search client
- **aiohttp==3.8.5**: Async HTTP client/server

## Startup Script (startup.sh)

The `startup.sh` script handles the deployment and startup of the application:

1. Changes to the application directory
2. Sets up logging to capture startup information
3. Waits for any previous processes to finish
4. Installs dependencies from requirements.txt
5. Sets up environment variables including PYTHONPATH
6. Starts the FastAPI application using Gunicorn with the following configuration:
   - 2 worker processes
   - UvicornWorker worker class
   - 600 second timeout
   - Binding to 0.0.0.0:8000
   - Logging to standard output

Example:
```bash
#!/bin/bash
cd /home/site/wwwroot

# Install dependencies
pip install --no-cache-dir -r requirements.txt

# Export environment variables
export PYTHONPATH=/home/site/wwwroot:$PYTHONPATH

# Start the FastAPI application with Gunicorn
exec gunicorn app.main:app --workers 2 --worker-class uvicorn.workers.UvicornWorker --timeout 600 --bind 0.0.0.0:8000 --access-logfile '-' --error-logfile '-'
```

## Deployment to Azure App Service (Code Deployment)

For deploying to Azure App Service as code (not a container), the following steps are necessary:

1. Create an App Service with Python runtime (preferably Python 3.10 or higher)
2. Configure the following app settings in Azure:
   - All environment variables from the .env file
   - SCM_DO_BUILD_DURING_DEPLOYMENT=true
   - WEBSITE_RUN_FROM_PACKAGE=0
3. Set the startup command to: `sh startup.sh`
4. Deploy the code using one of these methods:
   - Git deployment
   - ZIP deployment
   - Azure DevOps Pipeline
   - GitHub Actions

### Deployment PowerShell Considerations

When creating a PowerShell script for Azure App Service deployment:

1. Include environment variable setup (from .env)
2. Ensure proper Python version is selected
3. Include proper path configuration
4. Set up startup command properly
5. Configure application settings including CORS if needed
6. Ensure all dependencies are correctly installed

The script should handle:
- Authentication to Azure
- Creating or updating the App Service
- Configuring app settings
- Deploying the code (typically as a ZIP package)
- Restarting the service after deployment
- Verifying the deployment was successful 