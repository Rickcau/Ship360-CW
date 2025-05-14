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

class ComparisonOperator(str, enum.Enum):
    """Enum defining comparison operators for filtering shipping options."""
    LESS_THAN = "less_than"
    LESS_THAN_OR_EQUAL = "less_than_or_equal"

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
        order = self.order_service.get_order(order_id)
        if not order:
            return f"Order with ID {order_id} not found."
        
        bearer_token = await ship_360_service.get_shipping_authorization()
        if not bearer_token:
            return "Failed to retrieve bearer token."

        # Extract just the access_token from the bearer token response        
        token = bearer_token.get("access_token")

        print(f"Bearer Token: {bearer_token}")

        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "compactResponse": "true"            
        }

        # Call the rate shop API with the order details sent in the body
        url = settings.SP360_RATE_SHOP_URL
        response = requests.post(url, headers=headers, json=order)
        
        if response.status_code == 200:
            # Get the full API response
            api_response = response.json()

            # Extract only the rates array which contains the shipping options
            if "rates" in api_response and isinstance(api_response["rates"], list):
                shipping_options = api_response["rates"]

                # filter out the 0 cost options
                shipping_options = [option for option in shipping_options if option.get("totalCarrierCharge", 0) > 0]

                # filter options based on max price specified by the user
                if max_price > 0:
                    shipping_options = [option for option in shipping_options if option.get("totalCarrierCharge", 0) <= max_price]

                # filter options based on max duration specified by the user
                comparison_op = ComparisonOperator(duration_operator)

                final_options = []
                if duration_value > 0:
                    for option in shipping_options:
                        # get the deliveryCommitment object where the min and max estimated number of days are
                        delivery_commitment = option.get("deliveryCommitment", {})
                        
                        # get the min and max estimated number of days as integers
                        min_days = int(delivery_commitment.get("minEstimatedNumberOfDays", 0))
                        max_days = int(delivery_commitment.get("maxEstimatedNumberOfDays", 0))

                        if (comparison_op == ComparisonOperator.LESS_THAN and (min_days < duration_value or max_days < duration_value)) or \
                           (comparison_op == ComparisonOperator.LESS_THAN_OR_EQUAL and (min_days <= duration_value or max_days <= duration_value)):
                            final_options.append(option)
                else:
                    final_options = shipping_options

                # sort by price in the event the user requested a certain number of options be returned which ends up being less than the total number of options available
                try:
                    final_options.sort(key=lambda x: float(x.get("totalCarrierCharge", 0)))
                except ValueError:
                    print("Error sorting shipping options by price. Defaulting to original order.")

                # return a structured JSON response so the LLM can use this to accurately respond to the user with the total options
                return {
                    "total_options": len(final_options), # original count before filtering
                    "filtered_count": len(shipping_options), # count after filtering options
                    "shippingOptions": final_options # final filtered shipping options
                }

        else:
            print(f"Error: {response.status_code} - {response.text}")
            return {
                "error": f"{response.status_code} - {response.text}"
            }

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
        
        bearer_token = await ship_360_service.get_shipping_authorization()
        if not bearer_token:
            return "Failed to retrieve bearer token."
        
        print (f"Bearer Token: {bearer_token}")
        return "Plugin successfully invoked."
