import logging
import json
from datetime import datetime, date
from typing import Any, Dict
import uuid

logger = logging.getLogger(__name__)

class JSONEncoder(json.JSONEncoder):
    """Custom JSON encoder to handle datetime and UUID objects"""
    def default(self, obj: Any) -> Any:
        if isinstance(obj, (datetime, date)):
            return obj.isoformat()
        if isinstance(obj, uuid.UUID):
            return str(obj)
        return super().default(obj)

def format_response(data: Dict[str, Any]) -> Dict[str, Any]:
    """Format API response with consistent structure"""
    return {
        "status": "success",
        "data": data,
        "timestamp": datetime.utcnow()
    }

def format_error(message: str, error_code: str = None) -> Dict[str, Any]:
    """Format error response with consistent structure"""
    return {
        "status": "error",
        "error": {
            "message": message,
            "code": error_code
        },
        "timestamp": datetime.utcnow()
    }

def sanitize_input(text: str) -> str:
    """Sanitize user input to prevent injection attacks"""
    # Implement sanitization logic
    return text.strip()