import os
import httpx
import logging
from typing import Any, AsyncIterable, Annotated, Literal, TYPE_CHECKING

from dotenv import load_dotenv

from pydantic import BaseModel

from semantic_kernel.agents import ChatCompletionAgent, ChatHistoryAgentThread
from semantic_kernel.connectors.ai.open_ai import OpenAIChatCompletion, OpenAIChatPromptExecutionSettings, AzureChatCompletion, AzureChatPromptExecutionSettings
from semantic_kernel.contents import (
    FunctionCallContent, FunctionResultContent, StreamingChatMessageContent, StreamingTextContent
)
from semantic_kernel.functions.kernel_arguments import KernelArguments
from semantic_kernel.functions import kernel_function

if TYPE_CHECKING:
    from semantic_kernel.contents import ChatMessageContent

logger = logging.getLogger(__name__)

load_dotenv()
