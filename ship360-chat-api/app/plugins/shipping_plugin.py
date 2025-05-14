import requests
from typing import Annotated, Any, AsyncIterable, Literal, Dict
import enum
from semantic_kernel import Kernel
from semantic_kernel.functions import kernel_function
from app.core.config import settings
from app.services.orders import OrderService
from app.services.ship_360_service import Ship360Service

order_service = OrderService()
ship_360_service = Ship360Service()

class ShippingPlugin:
    def __init__(self, order_service: OrderService):
        if not all([
            settings.SP360_TOKEN_URL,
            settings.SP360_TOKEN_USERNAME,
            settings.SP360_TOKEN_PASSWORD
        ]):
            raise ValueError("Required Ship 360 settings are missing")
        
        self.order_service = order_service

    @kernel_function(name="RateShop", description="Given an Order Id, return a list of shipping options using the maximum price and duration, if provided.")
    async def perform_rate_shop(
        self,
        order_id: Annotated[str, "The unique identifier for the order"],
        max_price: Annotated[float, "Maximum price for shipping options"] = 0.0,
        duration_value: Annotated[int, "Maximum duration in days for shipping options"] = 0,
        duration_operator: Annotated[str, "Comparison operator for duration (less_than, less_than_or_equal)"] = "less_than_or_equal"
    ):
        # Check for order_service dependency
        if not hasattr(self, "order_service") or self.order_service is None:
            return {"error": "order_service dependency is required."}

        # Fetch the order
        order = self.order_service.get_order(order_id)
        if not order:
            return {"error": f"Order with ID {order_id} not found."}

        # Call the service's perform_rate_shop with the order object
        return await ship_360_service.perform_rate_shop(
            order=order,
            max_price=max_price,
            duration_value=duration_value,
            duration_operator=duration_operator
        )

    @kernel_function(name="GenerateShippingLabel", description="Create a shipping label for a given Order Id using the cheapest available carrier.")
    async def create_shipping_label(
        self,
        order_id: Annotated[str, "The unique identifier for the order."],
        carrier_account_id: Annotated[str, "The unique identifier for the carrier account."],
        size: Annotated[str, "The size of the printed shipping label."]
    ):
        order = self.order_service.get_order(order_id)
        if not order:
            return f"Order with ID {order_id} not found."
        
        bearer_token = await ship_360_service.get_sp360_token()
        if not bearer_token:
            return "Failed to retrieve bearer token."
        
        print (f"Bearer Token: {bearer_token}")
        return "Plugin successfully invoked."
