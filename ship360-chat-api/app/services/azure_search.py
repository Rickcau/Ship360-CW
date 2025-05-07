# This file is optional and only needed if Azure AI Search integration is required
import os
import logging
import httpx
import warnings
from typing import Dict, Any, List, Optional
from app.core.config import settings

logger = logging.getLogger(__name__)

class SearchService:
    def __init__(self):
        warnings.warn(
            "Not being used in the current implementation.",
            DeprecationWarning,
            stacklevel=2
        )
        """Initialize the Azure AI Search service if configured"""
        # Check if search is configured
        if not hasattr(settings, "AZURE_SEARCH_SERVICE_ENDPOINT") or not settings.AZURE_SEARCH_SERVICE_ENDPOINT:
            logger.warning("Azure AI Search is not configured. SearchService will not be functional.")
            self.is_configured = False
            return
            
        self.is_configured = True
        self.endpoint = settings.AZURE_SEARCH_SERVICE_ENDPOINT
        self.index_name = settings.AZURE_SEARCH_INDEX_NAME
        self.api_key = settings.AZURE_SEARCH_API_KEY
        self.api_version = "2023-07-01-Preview"
        logger.info("Azure AI Search service initialized")
    
    async def search(self, query: str, top: int = 5) -> List[Dict[str, Any]]:
        warnings.warn(
            "Not being used in the current implementation.",
            DeprecationWarning,
            stacklevel=2
        )
        """
        Search the Azure AI Search index if configured
        
        Args:
            query: Search query
            top: Number of results to return
            
        Returns:
            List of search results or empty list if not configured
        """
        if not self.is_configured:
            logger.warning("Search attempted but Azure AI Search is not configured")
            return []
            
        try:
            # Build request URL
            url = f"{self.endpoint}/indexes/{self.index_name}/docs/search"
            
            # Build request headers
            headers = {
                "Content-Type": "application/json",
                "api-key": self.api_key,
                "Accept": "application/json"
            }
            
            # Build request body
            body = {
                "search": query,
                "queryType": "semantic",
                "semanticConfiguration": "default",
                "top": top,
                "queryLanguage": "en-us"
            }
            
            # Send request
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    url, 
                    headers=headers, 
                    json=body, 
                    params={"api-version": self.api_version}
                )
                
                # Check for success
                response.raise_for_status()
                
                # Parse response
                search_results = response.json()
                
                # Extract and format results
                formatted_results = []
                if "value" in search_results:
                    for item in search_results["value"]:
                        formatted_result = {
                            "title": item.get("metadata_title", ""),
                            "content": item.get("content", ""),
                            "source": item.get("metadata_source", ""),
                            "score": item.get("@search.score", 0)
                        }
                        formatted_results.append(formatted_result)
                
                return formatted_results
                
        except Exception as e:
            logger.error(f"Error searching Azure AI Search: {str(e)}")
            return []