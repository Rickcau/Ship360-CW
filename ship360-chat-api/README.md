# File: README.md
# Chat Provider API

A FastAPI-based service that provides chat capabilities using Azure OpenAI and Semantic Kernel Agents.

## Features

- Chat endpoint that processes user queries using multiple specialized agents
- Integration with Azure OpenAI through Semantic Kernel
- Optional integration with Azure AI Search (can be enabled in config)
- Swagger UI for API documentation and testing

## Requirements

- Python 3.11+
- FastAPI
- Azure OpenAI access
- Semantic Kernel

## Setup

1. Clone the repository
2. Create a virtual environment:
   ```
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
3. Install dependencies:
   ```
   pip install -r requirements.txt
   ```
4. Create a `.env` file in the root directory with the following variables:
   ```
   AZURE_OPENAI_API_KEY=your_openai_api_key
   AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
   AZURE_OPENAI_API_VERSION=2023-05-15
   
   # Shipping 360 API configuration
   SP360_TOKEN_URL=""
   SP360_TOKEN_USERNAME=""
   SP360_TOKEN_PASSWORD=""
   SP360_RATE_SHOP_URL=""
   SP360_SHIPMENTS_URL=""
   SP360_TRACKING_URL=""
   ```

## Running the Application

```
uvicorn app.main:app --reload
```

The application will be available at http://localhost:8000

## API Documentation

Swagger UI documentation is available at http://localhost:8000/docs

## API Endpoints

### POST /api/chat

Process a chat message using multiple Semantic Kernel agents.

Request body:
```json
{
    "userId": "stevesmith@contoso.com",
    "sessionId": "12345678",
    "chatName": "New Chat",
    "user_prompt": "Hello, What can you do for me?"
}
```

Response:
```json
{
    "chatResponse": "This is concatenated response from all agents",
    "masterAgent": "Response from the masterAgent",
    "intentAgent": "Response from the intentAgent",
    "rateAgent": "Response from the rateAgent",
    "labelAgent": "Response from the labelAgent",
    "trackingAgent": "Response from the trackingAgent"
}
```

## Implementing Search Integration

To enable Azure AI Search integration:

1. Uncomment the search-related environment variables in the `.env` file
2. Update the config.py file to uncomment the search settings
3. Modify the chat.py endpoint to inject and use the SearchService where needed