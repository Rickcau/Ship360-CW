from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional, Dict, Any, AsyncIterator
import json
import logging
from app.core.config import settings
from app.services.azure_openai import OpenAIService
from app.utils.helpers import format_response, format_error
from app.plugins.shipping_plugin import ShippingPlugin
from app.services.orders import OrderService

from semantic_kernel import Kernel
from semantic_kernel.utils.logging import setup_logging
from semantic_kernel.functions import kernel_function
from semantic_kernel.connectors.ai.open_ai import AzureChatCompletion
from semantic_kernel.connectors.ai.function_choice_behavior import FunctionChoiceBehavior
from semantic_kernel.connectors.ai.chat_completion_client_base import ChatCompletionClientBase
from semantic_kernel.contents.chat_history import ChatHistory
from semantic_kernel.functions.kernel_arguments import KernelArguments

from semantic_kernel.connectors.ai.open_ai.prompt_execution_settings.azure_chat_prompt_execution_settings import (
    AzureChatPromptExecutionSettings,
)
import requests
router = APIRouter(tags=["Chat"])

logger = logging.getLogger(__name__)

class ChatRequest(BaseModel):
    userId: str
    sessionId: str
    chatName: str
    user_prompt: str

    class Config:
        json_schema_extra = {
            "example": {
                "userId": "user123",
                "sessionId": "12345678",
                "chatName": "New Chat",
                "user_prompt": "Rate shop for the best shipping option for this package: 10x6x4 inches, 2 lbs, shipping from 10001 to 94105"
            }
        }

class ChatResponse(BaseModel):
    content: str
    is_task_complete: bool
    require_user_input: bool

#async def stream_chat_response(
#    request: ChatRequest,
#    openai_service: OpenAIService
#) -> AsyncIterator[str]:
#    """Stream chat responses as Server-Sent Events (SSE)."""
#    try:
#        async for response in openai_service.stream_response(
#            user_id=request.userId,
#            session_id=request.sessionId,
#            chat_name=request.chatName,
#            prompt=request.user_prompt
#        ):
#            yield f"data: {json.dumps(response)}\n\n"
#    except Exception as e:
#        error_response = {
#            "is_task_complete": False,
#            "require_user_input": True,
#            "content": f"Error: {str(e)}"
#        }
#        yield f"data: {json.dumps(error_response)}\n\n"
#    finally:
#        yield "data: [DONE]\n\n"

#@router.post("/chat")
#async def process_chat(
#    request: ChatRequest,
#    openai_service: OpenAIService = Depends(OpenAIService)
#):
#    """
#    Process a chat request using Semantic Kernel Agents.
#    Returns a streaming response of agent processing and final results.
#    """
#    try:
#        logger.info(f"Processing chat request for user {request.userId}, session {request.sessionId}")
#        
#        return StreamingResponse(
#            stream_chat_response(request, openai_service),
#            media_type="text/event-stream"
#        )
 #       
 #   except Exception as e:
 #       logger.error(f"Error processing chat: {str(e)}")
 #       raise HTTPException(
 #           status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
 #           detail=f"Chat processing error: {str(e)}"
 #       )

@router.post("/chat/sync", response_model=str)
async def process_chat_sync(
    request: ChatRequest,
    openai_service: OpenAIService = Depends(OpenAIService)
):
    """
    Process a chat request synchronously using a Semantic Kernel Plugin.
    Returns a single response with the final result.
    """
    try:
        url = f"{settings.AZURE_OPENAI_ENDPOINT}/openai/deployments/{settings.AZURE_OPENAI_CHAT_DEPLOYMENT_NAME}/chat/completions?api-version={settings.AZURE_OPENAI_API_VERSION}"
        logger.info(f"Processing chat request for user {request.userId}, session {request.sessionId}")
        
        kernel = Kernel()
        
        chat_completion = AzureChatCompletion(
            api_key=settings.AZURE_OPENAI_API_KEY,
            base_url=url,
        )

        kernel.add_service(chat_completion)
        
        # Set the logging level for  semantic_kernel.kernel to DEBUG.
        setup_logging()
        logging.getLogger("kernel").setLevel(logging.DEBUG)

        order_service = OrderService()
        shipping_plugin = ShippingPlugin(order_service)

        kernel.add_plugin(shipping_plugin, plugin_name="ShippingPlugin")

        # Enable planning
        execution_settings = AzureChatPromptExecutionSettings()
        execution_settings.function_choice_behavior = FunctionChoiceBehavior.Auto()
                
        history = ChatHistory(system_message="You are responsible for shipping orders.")
        history.add_user_message(request.user_prompt)

        # Get the response from the AI
        result = await chat_completion.get_chat_message_content(
            chat_history=history,
            settings=execution_settings,
            kernel=kernel,
        )

        history.add_message(result)

        logger.info(f"Successfully processed chat for session {request.sessionId}")
 
        return result.content
        
    except Exception as e:
        logger.error(f"Error processing chat: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Chat processing error: {str(e)}"
        )
    
@router.get("/orders/{order_number}", response_model=Dict[str, Any])
async def get_order_by_number(
    order_number: str,
    order_service: OrderService = Depends(OrderService)
):
    """
    Test endpoint to retrieve a specific order by order number.
    """
    try:
        order = order_service.get_order(order_number)
        if not order:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Order with number {order_number} not found"
            )
        return order
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving order {order_number}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error retrieving order: {str(e)}"
        )