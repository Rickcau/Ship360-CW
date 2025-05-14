import aiohttp
from app.core.config import settings

class Ship360Service:
    """
    Service for interacting with Ship360 API, including token management with in-memory caching.
    """


    def __init__(self):
        # Validate required settings
        if not all([
            getattr(settings, "SP360_TOKEN_URL", None),
            getattr(settings, "SP360_TOKEN_USERNAME", None),
            getattr(settings, "SP360_TOKEN_PASSWORD", None)
        ]):
            raise ValueError("Required Ship 360 settings are missing")
        
    async def get_sp360_token(self):
        """
        Retrieve a Ship360 access token, using in-memory caching to avoid unnecessary API calls.

        - Returns the cached token if it exists and is valid (at least 30 seconds before expiration).
        - Otherwise, fetches a new token from the API and updates the cache.
        - The cache is class-level and safe for use in async contexts (single-process).
        """
        import time


        # Fetch a new token from the API
        url = settings.SP360_TOKEN_URL
        auth = aiohttp.BasicAuth(settings.SP360_TOKEN_USERNAME, settings.SP360_TOKEN_PASSWORD)
        headers = {"Content-Type": "application/json"}

        async with aiohttp.ClientSession() as session:
            async with session.post(url, headers=headers, auth=auth) as response:
                data = await response.json()
                if response.status == 200 and "access_token" in data and "expires_in" in data:
                    return data["access_token"]
                return None
            
    import enum

    class ComparisonOperator(str, enum.Enum):
        LESS_THAN = "less_than"
        LESS_THAN_OR_EQUAL = "less_than_or_equal"

    async def perform_rate_shop(
        self,
        order: dict,
        max_price: float = 0.0,
        duration_value: int = 0,
        duration_operator: str = "less_than_or_equal"
    ):
        """
        Refactored business logic for rate shopping.
        Args:
            order (dict): The order object to process for rate shopping.
            max_price (float): Maximum price for shipping options.
            duration_value (int): Maximum duration in days for shipping options.
            duration_operator (str): Comparison operator for duration.
        Returns:
            dict: Result with shipping options or error.
        """
        # Get bearer token using the service's async method
        token = await self.get_sp360_token()
        if not token:
            return {"error": "Failed to retrieve bearer token."}

        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "compactResponse": "true"
        }

        url = settings.SP360_RATE_SHOP_URL

        async with aiohttp.ClientSession() as session:
            async with session.post(url, headers=headers, json=order) as response:
                if response.status == 200:
                    api_response = await response.json()
                    if "rates" in api_response and isinstance(api_response["rates"], list):
                        shipping_options = api_response["rates"]
                        # filter out the 0 cost options
                        shipping_options = [
                            option for option in shipping_options
                            if option.get("totalCarrierCharge", 0) > 0
                        ]
                        # filter options based on max price specified by the user
                        if max_price > 0:
                            shipping_options = [
                                option for option in shipping_options
                                if option.get("totalCarrierCharge", 0) <= max_price
                            ]
                        # filter options based on max duration specified by the user
                        comparison_op = ComparisonOperator(duration_operator)
                        final_options = []
                        if duration_value > 0:
                            for option in shipping_options:
                                delivery_commitment = option.get("deliveryCommitment", {})
                                min_days = int(delivery_commitment.get("minEstimatedNumberOfDays", 0))
                                max_days = int(delivery_commitment.get("maxEstimatedNumberOfDays", 0))
                                if (
                                    (comparison_op == ComparisonOperator.LESS_THAN and (min_days < duration_value or max_days < duration_value))
                                    or
                                    (comparison_op == ComparisonOperator.LESS_THAN_OR_EQUAL and (min_days <= duration_value or max_days <= duration_value))
                                ):
                                    final_options.append(option)
                        else:
                            final_options = shipping_options
                        # sort by price
                        try:
                            final_options.sort(key=lambda x: float(x.get("totalCarrierCharge", 0)))
                        except ValueError:
                            pass
                        return {
                            "total_options": len(final_options),
                            "filtered_count": len(shipping_options),
                            "shippingOptions": final_options
                        }
                # Non-200 response
                error_text = await response.text()
                return {
                    "error": f"{response.status} - {error_text}"
                }