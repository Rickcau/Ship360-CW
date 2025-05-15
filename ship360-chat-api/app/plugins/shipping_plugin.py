from typing import Annotated
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

    @kernel_function(name="CreateShippingLabel", description="Create a shipping label for a given Order Id using the provided carrier account id and shipping label size.")
    async def create_shipping_label(
        self,
        order_id: Annotated[str, "The unique identifier for the order."],
        carrier_account_id: Annotated[str, "The unique identifier for the carrier account."],
        shipping_label_size: Annotated[str, "The size of the printed shipping label."]
    ):
        order = self.order_service.get_order(order_id)
        if not order:
            return f"Order with ID {order_id} not found."

        api_response = await ship_360_service.create_shipment_domestic(
                order=order,
                carrier_account_id=carrier_account_id,
                shipping_label_size=shipping_label_size
            )
        
        json_response = {
            "parcelTrackingNumber": api_response["parcelTrackingNumber"],
            "shipmentId": api_response["shipmentId"],
            "shipping_label_url": api_response["labelLayout"][0]["contents"]
        }

        return json_response
    
    @kernel_function(name="CancelShipment", description="Given a Shipment Id, cancel the shipment and return cancelation status.")
    async def create_shipping_label(
        self,
        shipment_id: Annotated[str, "The Shipment Id."]
    ):

        api_response = await ship_360_service.cancel_shipment(shipment_id=shipment_id)
        
        json_response = {
            "carrier": api_response["carrier"],
            "totalCarrierCharge": api_response["totalCarrierCharge"],
            "status": api_response["status"],
            "parcelTrackingNumber": api_response["parcelTrackingNumber"]
        }

        return json_response