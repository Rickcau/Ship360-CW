import os
from pydantic_settings import BaseSettings
from pydantic import model_validator
from typing import List, Optional, Dict, Any
from functools import lru_cache
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class Settings(BaseSettings):
    # Project settings
    PROJECT_NAME: str = "Chat API"
    API_PREFIX: str = "/api"
    DEBUG: bool = False
    
    # CORS
    CORS_ORIGINS: List[str] = ["*"]
    
    # Azure OpenAI
    AZURE_OPENAI_API_KEY: str
    AZURE_OPENAI_ENDPOINT: str
    AZURE_OPENAI_API_VERSION: str
    AZURE_OPENAI_CHAT_DEPLOYMENT_NAME: str

    # Ship 360 API Configuration
    SP360_TOKEN_URL: str
    SP360_TOKEN_USERNAME: str
    SP360_TOKEN_PASSWORD: str

    # Ship 360 APIs
    SP360_RATE_SHOP_URL: str
    SP360_SHIPMENTS_URL: str
    SP360_TRACKING_URL: str

    # Semantic Kernel agent configurations
    #MASTER_AGENT_DEPLOYMENT: str
    #INTENT_AGENT_DEPLOYMENT: str
    #RATE_AGENT_DEPLOYMENT: str
    #LABEL_AGENT_DEPLOYMENT: str
    #TRACKING_AGENT_DEPLOYMENT: str
    
    # Optional - Azure AI Search (uncomment if needed)
    # AZURE_SEARCH_SERVICE_ENDPOINT: Optional[str] = None
    # AZURE_SEARCH_INDEX_NAME: Optional[str] = None
    # AZURE_SEARCH_API_KEY: Optional[str] = None
    
    # Optional logging settings
    LOG_LEVEL: str = "INFO"
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        
    @model_validator(mode='after')
    def check_required_fields(self) -> 'Settings':
        missing_fields = []
        for field_name, field in self.model_fields.items():
            if field.is_required() and getattr(self, field_name) is None:
                missing_fields.append(field_name)
        
        if missing_fields:
            error_msg = f"Missing required environment variables: {', '.join(missing_fields)}"
            print(f"STARTUP ERROR: {error_msg}")
            print("Please check your environment variables configuration.")
            raise ValueError(error_msg)
        return self

@lru_cache()
def get_settings() -> Settings:
    try:
        return Settings()
    except Exception as e:
        print(f"CONFIGURATION ERROR: Failed to load settings - {e}")
        print("Application cannot start without proper configuration.")
        raise

# Initialize settings with error handling
settings = None
try:
    settings = get_settings()
    print(f"✓ Configuration loaded successfully for {settings.PROJECT_NAME}")
except Exception as e:
    print(f"✗ Configuration failed: {e}")
    # Re-raise to prevent app from starting with invalid config
    raise