from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional, Dict, Any, AsyncIterator, List
from fastapi.params import Path
import json
import logging
from app.services.azure_openai import OpenAIService
from app.utils.helpers import format_response, format_error
from app.services.orders import OrderService
from app.plugins.shipping_plugin import ShippingPlugin

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

from app.core.config import settings

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

async def stream_chat_response(
    request: ChatRequest,
    openai_service: OpenAIService
) -> AsyncIterator[str]:
    """Stream chat responses as Server-Sent Events (SSE)."""
    try:
        async for response in openai_service.stream_response(
            user_id=request.userId,
            session_id=request.sessionId,
            chat_name=request.chatName,
            prompt=request.user_prompt
        ):
            yield f"data: {json.dumps(response)}\n\n"
    except Exception as e:
        error_response = {
            "is_task_complete": False,
            "require_user_input": True,
            "content": f"Error: {str(e)}"
        }
        yield f"data: {json.dumps(error_response)}\n\n"
    finally:
        yield "data: [DONE]\n\n"

@router.post("/chat")
async def process_chat(
    request: ChatRequest
):
    """
    Process a chat request using a Semantic Kernel Plugin.
    """
    try:
        logger.info(f"Processing chat request for user {request.userId}, session {request.sessionId}")
        
        # Initialize the kernel
        kernel = Kernel()

        # Add Azure OpenAI chat completion
        chat_completion = AzureChatCompletion(
            deployment_name=settings.AZURE_OPENAI_CHAT_DEPLOYMENT_NAME,
            api_key=settings.AZURE_OPENAI_API_KEY,
            base_url=settings.AZURE_OPENAI_ENDPOINT
        )

        kernel.add_service(chat_completion)
        
        # Set the logging level for  semantic_kernel.kernel to DEBUG.
        setup_logging()
        logging.getLogger("kernel").setLevel(logging.DEBUG)

        # Instantiate the plugin
        order_service: OrderService = Depends(OrderService)
        shipping_plugin_instance = ShippingPlugin(order_service=order_service)

        kernel.add_plugin(
            shipping_plugin_instance,
            plugin_name="ShippingPlugin",
        )

        # Enable planning
        execution_settings = AzureChatPromptExecutionSettings()
        execution_settings.function_choice_behavior = FunctionChoiceBehavior.Auto()

        # Create a history of the conversation
        history = ChatHistory()

        # Add user input to the history
        history.add_user_message(request.user_prompt)

        # Get the response from the AI
        result = await chat_completion.get_chat_message_content(
            chat_history=history,
            settings=execution_settings,
            kernel=kernel,
        )

        # Add the message from the agent to the chat history
        history.add_message(result)

        return StreamingResponse(
            stream_chat_response(request, openai_service=OpenAIService()),
            media_type="text/event-stream"
        )

    except Exception as e:
        logger.error(f"Error processing chat: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Chat processing error: {str(e)}"
        )

@router.post("/chat/sync", response_model=ChatResponse)
async def process_chat_sync(
    request: ChatRequest,
    openai_service: OpenAIService = Depends(OpenAIService)
):
    """
    Process a chat request synchronously using Semantic Kernel Agents.
    Returns a single response with the final result.
    """
    try:
        logger.info(f"Processing chat request for user {request.userId}, session {request.sessionId}")
        
        response = await openai_service.process_with_agents(
            user_id=request.userId,
            session_id=request.sessionId,
            chat_name=request.chatName,
            prompt=request.user_prompt
        )
        
        logger.info(f"Successfully processed chat for session {request.sessionId}")
        return ChatResponse(**response)
        
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
