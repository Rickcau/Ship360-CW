from semantic_kernel.contents.chat_history import ChatHistory
from semantic_kernel.connectors.ai.chat_completion_client_base import ChatCompletionClientBase
from semantic_kernel.connectors.ai.open_ai.prompt_execution_settings.azure_chat_prompt_execution_settings import AzureChatPromptExecutionSettings

class Intent:
    """
    A class for detecting shipping intents from user queries
    """
    
    @staticmethod
    async def get_intent(chat_service: ChatCompletionClientBase, query: str) -> str:
        """Get the intent of a shipping query"""
        # Create a chat history for intent detection
        chat_history = ChatHistory()
        
        # Add system message with intent classification instructions
        chat_history.add_system_message("""
        You are an intent classifier for shipping related queries. 
        Return the intent of the user. The intent must be one of the following strings:
        - create_label: Use this intent for requests to create or generate a shipping label
        - rate_shop: Use this intent for requests to compare rates or find the best shipping option
        - compare_carriers: Use this intent for requests to specifically compare different carrier options
        - optimized_shipping: Use this intent for requests that balance cost and delivery time constraints
        - not_found: Use this intent if you can't find a suitable answer
        
        Return ONLY the intent string and nothing else.
        """)
        
        # Add the user's query
        chat_history.add_user_message(query)
        
        # Create execution settings
        settings = AzureChatPromptExecutionSettings()
        settings.temperature = 0.0  # We want deterministic responses for intent classification
        
        try:
            # Try the new method first
            result = await chat_service.get_chat_message_contents(chat_history, settings)
        except AttributeError:
            try:
                # Try the old method as fallback
                result = await chat_service.complete_chat_async(chat_history)
            except AttributeError:
                # Try another alternative method
                result = await chat_service.get_chat_message_content(chat_history, settings)
        
        # Extract the intent from the result
        if hasattr(result, 'content'):
            intent = result.content.strip().lower()
        else:
            intent = result[0].content.strip().lower()
        
        # Validate the intent
        valid_intents = ["create_label", "rate_shop", "compare_carriers", "optimized_shipping", "not_found"]
        if intent not in valid_intents:
            return "not_found"
        
        return intent
