import os
import logging
import warnings
from typing import Any, AsyncIterable, Literal, Dict
from pydantic import BaseModel

from semantic_kernel.agents import ChatCompletionAgent, ChatHistoryAgentThread
from semantic_kernel.connectors.ai.open_ai import AzureChatCompletion, AzureChatPromptExecutionSettings
from semantic_kernel.contents import (
    FunctionCallContent, FunctionResultContent, StreamingChatMessageContent, StreamingTextContent
)
from semantic_kernel.functions.kernel_arguments import KernelArguments

from app.core.config import settings
from deprecated import deprecated
logger = logging.getLogger(__name__)

# region Response Format

class ResponseFormat(BaseModel):
    warnings.warn(
            "Not being used in the current implementation.",
            DeprecationWarning,
            stacklevel=2
        )
    """A Response Format model to direct how the model should respond."""
    status: Literal["input_required", "completed", "error"] = "input_required"
    message: str

# endregion

class OpenAIService:
    """Wraps Semantic Kernel-based agents to handle chat interactions."""

    agent: ChatCompletionAgent
    thread: ChatHistoryAgentThread = None

    def __init__(self):
        warnings.warn(
            "Not being used in the current implementation.",
            DeprecationWarning,
            stacklevel=2
        )
        """Initialize the Azure OpenAI service with Semantic Kernel agents"""
        if not all([
            settings.AZURE_OPENAI_API_KEY,
            settings.AZURE_OPENAI_ENDPOINT,
            settings.AZURE_OPENAI_API_VERSION
        ]):
            raise ValueError("Required Azure OpenAI settings are missing")

        # Create Azure OpenAI service for intent analysis agent
        intent_agent = ChatCompletionAgent(
            service=AzureChatCompletion(
                deployment_name=settings.INTENT_AGENT_DEPLOYMENT,
                endpoint=settings.AZURE_OPENAI_ENDPOINT,
                api_key=settings.AZURE_OPENAI_API_KEY,
                api_version=settings.AZURE_OPENAI_API_VERSION,
            ),
            name="IntentAgent",
            instructions=(
                "You specialize in identifying the intent of user messages. "
                "Categorize the intent into: Create Shipping Label, Shop for Best Rate, Other. "
                "Provide a brief explanation for your categorization."
            ),
        )

        # Create Azure OpenAI service for rate analysis agent
        rate_agent = ChatCompletionAgent(
            service=AzureChatCompletion(
                deployment_name=settings.RATE_AGENT_DEPLOYMENT,
                endpoint=settings.AZURE_OPENAI_ENDPOINT,
                api_key=settings.AZURE_OPENAI_API_KEY,
                api_version=settings.AZURE_OPENAI_API_VERSION,
            ),
            name="RateAgent",
            instructions=(
                "You specialize in finding the best shipping rate for user messages. "
                "If you need more information from the user, ask for it."
            ),
        )

        # Create Azure OpenAI service for labeling agent
        label_agent = ChatCompletionAgent(
            service=AzureChatCompletion(
                deployment_name=settings.LABEL_AGENT_DEPLOYMENT,
                endpoint=settings.AZURE_OPENAI_ENDPOINT,
                api_key=settings.AZURE_OPENAI_API_KEY,
                api_version=settings.AZURE_OPENAI_API_VERSION,
            ),
            name="LabelAgent",
            instructions=(
                "You specialize in generating a shipping label for the user message"
                "Make sure you include all the information the user needs to create a shipping label if you need to ask for more informaiton do so."
            ),
        )

        # Create Azure OpenAI service for tracking agent
        tracking_agent = ChatCompletionAgent(
            service=AzureChatCompletion(
                deployment_name=settings.TRACKING_AGENT_DEPLOYMENT,
                endpoint=settings.AZURE_OPENAI_ENDPOINT,
                api_key=settings.AZURE_OPENAI_API_KEY,
                api_version=settings.AZURE_OPENAI_API_VERSION,
            ),
            name="TrackingAgent",
            instructions=(
                "You specialize in providing tracking information order and shipping label what was created for the user."
                "Suggest what information or actions might be needed next."
            ),
        )

        # Create Azure OpenAI service for the main agent
        self.agent = ChatCompletionAgent(
            service=AzureChatCompletion(
                deployment_name=settings.MASTER_AGENT_DEPLOYMENT,
                endpoint=settings.AZURE_OPENAI_ENDPOINT,
                api_key=settings.AZURE_OPENAI_API_KEY,
                api_version=settings.AZURE_OPENAI_API_VERSION,
            ),
            name="MasterAgent",
            instructions=(
                "Your role is to analyze user requests and coordinate with specialized agents to provide comprehensive responses. "
                "You will receive input from intent agent, based on the intent you will leverage the rate agent to find best shipping rates, the label agent to generate a shipping agent, the tracking agent to provide tracking information. "
                "Combine these insights to create informative and helpful responses."
            ),
            plugins=[intent_agent, rate_agent, label_agent, tracking_agent],
            arguments=KernelArguments(
                settings=AzureChatPromptExecutionSettings(
                    response_format=ResponseFormat,
                )
            ),
        )

        logger.info("Azure OpenAI service and Semantic Kernel agents initialized")

    async def process_with_agents(
        self,
        user_id: str,
        session_id: str,
        chat_name: str,
        prompt: str
    ) -> Dict[str, str]:
        warnings.warn(
            "Not being used in the current implementation.",
            DeprecationWarning,
            stacklevel=2
        )
        """Process a user prompt with all Semantic Kernel agents.
        
        Args:
            user_id: User identifier (email)
            session_id: Session identifier
            chat_name: Name of the chat
            prompt: User message or prompt
            
        Returns:
            Dictionary with responses from each agent
        """
        await self._ensure_thread_exists(session_id)

        context_info = f"""
        User ID: {user_id}
        Session ID: {session_id}
        Chat Name: {chat_name}
        """

        # Get response from master agent which will coordinate with other agents
        response = await self.agent.get_response(
            messages=f"{context_info}\n\nUser Message: {prompt}",
            thread=self.thread,
        )

        return self._get_agent_response(response.content)

    async def stream_response(
        self,
        user_id: str,
        session_id: str,
        chat_name: str,
        prompt: str
    ) -> AsyncIterable[Dict[str, Any]]:
        warnings.warn(
            "Not being used in the current implementation.",
            DeprecationWarning,
            stacklevel=2
        )
        """Stream the response from the agents.
        
        Args:
            user_id: User identifier (email)
            session_id: Session identifier
            chat_name: Name of the chat
            prompt: User message or prompt
            
        Yields:
            Dictionary containing response content and status
        """
        await self._ensure_thread_exists(session_id)

        context_info = f"""
        User ID: {user_id}
        Session ID: {session_id}
        Chat Name: {chat_name}
        """

        chunks: list[StreamingChatMessageContent] = []
        tool_call_in_progress = False
        message_in_progress = False

        async for response_chunk in self.agent.invoke_stream(
            messages=f"{context_info}\n\nUser Message: {prompt}",
            thread=self.thread,
        ):
            if any(isinstance(item, (FunctionCallContent, FunctionResultContent)) for item in response_chunk.items):
                if not tool_call_in_progress:
                    yield {
                        "is_task_complete": False,
                        "require_user_input": False,
                        "content": "Processing with specialized agents...",
                    }
                    tool_call_in_progress = True
            elif any(isinstance(item, StreamingTextContent) for item in response_chunk.items):
                if not message_in_progress:
                    yield {
                        "is_task_complete": False,
                        "require_user_input": False,
                        "content": "Building response...",
                    }
                    message_in_progress = True

                chunks.append(response_chunk.message)

        full_message = sum(chunks[1:], chunks[0])
        yield self._get_agent_response(full_message)

    def _get_agent_response(self, message: str) -> Dict[str, Any]:
        warnings.warn(
            "Not being used in the current implementation.",
            DeprecationWarning,
            stacklevel=2
        )
        """Extract the structured response from the agent's message content."""
        try:
            structured_response = ResponseFormat.model_validate_json(message)

            response_map = {
                "input_required": {"is_task_complete": False, "require_user_input": True},
                "error": {"is_task_complete": False, "require_user_input": True},
                "completed": {"is_task_complete": True, "require_user_input": False},
            }

            if response := response_map.get(structured_response.status):
                return {**response, "content": structured_response.message}

        except Exception as e:
            logger.error(f"Error parsing agent response: {str(e)}")

        return {
            "is_task_complete": False,
            "require_user_input": True,
            "content": "We are unable to process your request at the moment. Please try again.",
        }

    async def _ensure_thread_exists(self, session_id: str) -> None:
        warnings.warn(
            "Not being used in the current implementation.",
            DeprecationWarning,
            stacklevel=2
        )
        """Ensure the thread exists for the given session ID."""
        if self.thread is None or self.thread._thread_id != session_id:
            await self.thread.delete() if self.thread else None
            self.thread = ChatHistoryAgentThread(thread_id=session_id)