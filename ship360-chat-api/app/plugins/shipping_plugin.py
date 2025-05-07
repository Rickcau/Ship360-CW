import requests
from typing import Annotated, Any, AsyncIterable, Literal, Dict
from semantic_kernel import Kernel
from semantic_kernel.functions import kernel_function
from app.core.config import settings
from app.services.orders import OrderService

order_service = OrderService()

class ShippingPlugin:
    def __init__(self, order_service: OrderService):
        if not all([
            settings.SP360_TOKEN_URL,
            settings.SP360_TOKEN_USERNAME,
            settings.SP360_TOKEN_PASSWORD
        ]):
            raise ValueError("Required Ship 360 settings are missing")
        
        self.order_service = order_service

    @kernel_function(name="GetShippingLabel", description="Create a shipping label for a given Order Id using the cheapest available carrier.")
    async def create_shipping_label(
        self,
        order_id: Annotated[str, "The unique identifier for the order"]
    ):
        order = self.order_service.get_order(order_id)
        if not order:
            return f"Order with ID {order_id} not found."
        
        bearer_token = await self.get_shipping_authorization()
        if not bearer_token:
            return "Failed to retrieve bearer token."
        
        print (f"Bearer Token: {bearer_token}")
        return "Plugin successfully invoked."
    
    async def get_shipping_authorization(self):
        url = settings.SP360_TOKEN_URL
        auth = (settings.SP360_TOKEN_USERNAME, settings.SP360_TOKEN_PASSWORD)
        headers = {"Content-Type": "application/json"}
        
        response = requests.post(url, headers=headers, auth=auth)

        if response.status_code == 200:
            print(response.json())
        else:
            print(f"Error: {response.status_code}")
        
        return response.json()