import aiohttp
import enum
import app.models.create_shipping_label_request as create_shipping_label_request
from app.core.config import settings

class ComparisonOperator(str, enum.Enum):
    LESS_THAN = "less_than"
    LESS_THAN_OR_EQUAL = "less_than_or_equal"

class Ship360Service:
    def __init__(self):
        # Validate required settings
        if not all([
            getattr(settings, "SP360_TOKEN_URL", None),
            getattr(settings, "SP360_TOKEN_USERNAME", None),
            getattr(settings, "SP360_TOKEN_PASSWORD", None),
            getattr(settings, "SP360_RATE_SHOP_URL", None),
            getattr(settings, "SP360_SHIPMENTS_URL", None)
        ]):
            raise ValueError("Required Ship 360 settings are missing")
        
    async def get_sp360_token(self):
        # Fetch a new token from the API
        url = settings.SP360_TOKEN_URL
        auth = aiohttp.BasicAuth(settings.SP360_TOKEN_USERNAME, settings.SP360_TOKEN_PASSWORD)
        headers = {"Content-Type": "application/json"}

        async with aiohttp.ClientSession() as session:
            async with session.post(url, headers=headers, auth=auth) as response:
                data = await response.json()
                if response.status == 200 and "access_token" in data:
                    return data["access_token"]
                else:
                    print(f"Error: {response.status}")
                return None

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

    async def create_shipment_domestic(
            self, 
            order: dict,
            carrier_account_id: str, 
            shipping_label_size: str
        ):

        json_shipping_label_request = create_shipping_label_request.ShippingLabel(
            size=shipping_label_size,
            type="SHIPPING_LABEL",
            fromAddress=create_shipping_label_request.Address(
                company="PB", # TODO
                addressLine1=order["fromAddress"]["addressLine1"],
                addressLine2="",
                addressLine3="",
                cityTown=order["fromAddress"]["cityTown"],
                countryCode=order["fromAddress"]["countryCode"],
                name=order["fromAddress"]["name"],
                phone=order["fromAddress"]["phone"],
                postalCode=order["fromAddress"]["postalCode"],
                stateProvince=order["fromAddress"]["stateProvince"]
            ),
            parcel=create_shipping_label_request.Parcel(
                height=order["parcel"]["height"],
                length=order["parcel"]["length"],
                dimUnit=order["parcel"]["dimUnit"],
                width=order["parcel"]["width"],
                weightUnit=order["parcel"]["weightUnit"],
                weight=order["parcel"]["weight"]
            ),
            carrierAccountId=carrier_account_id,
            parcelType="PKG",
            serviceId="UGA",
            shipmentOptions=create_shipping_label_request.ShipmentOptions(
                addToManifest=True,
                packageDescription="test" # TODO
            ),
            metadata=[
                create_shipping_label_request.MetadataItem(
                    name="costAccountName", # TODO
                    value="cost account 123" # TODO
                )
            ],
            toAddress=create_shipping_label_request.Address(
                company=order["toAddress"]["company"],
                addressLine1=order["toAddress"]["addressLine1"],
                addressLine2="",
                addressLine3="",
                cityTown=order["toAddress"]["cityTown"],
                countryCode=order["toAddress"]["countryCode"],
                name=order["toAddress"]["name"],
                phone=order["toAddress"]["phone"],
                postalCode=order["toAddress"]["postalCode"],
                stateProvince=order["toAddress"]["stateProvince"]
            )
        )

        url = settings.SP360_SHIPMENTS_URL
        bearer_token = await self.get_sp360_token()
        
        if not bearer_token:
            return "Failed to retrieve bearer token."
        
        headers = {
            "Authorization": f"Bearer {bearer_token}",
            "Content-Type": "application/json",
            "compactResponse": "true"
        }

        async with aiohttp.ClientSession() as session:
            async with session.post(
                url,
                headers=headers,
                json=json_shipping_label_request.model_dump()
            ) as response:
                if response.status == 200:
                    api_response = await response.json()
                    print(api_response)
                    return api_response
                # Non-200 response
                error_text = await response.text()
                return {
                    "error": f"{response.status} - {error_text}"
                }
            async def track_order(
                self,
                order: dict,
                carrier_account_id: str,
                shipping_label_size: str
            ):

                json_shipping_label_request = create_shipping_label_request.ShippingLabel(
                    size=shipping_label_size,
                    type="SHIPPING_LABEL",
                    fromAddress=create_shipping_label_request.Address(
                company="PB", # TODO
                addressLine1=order["fromAddress"]["addressLine1"],
                addressLine2="",
                addressLine3="",
                cityTown=order["fromAddress"]["cityTown"],
                countryCode=order["fromAddress"]["countryCode"],
                name=order["fromAddress"]["name"],
                phone=order["fromAddress"]["phone"],
                postalCode=order["fromAddress"]["postalCode"],
                stateProvince=order["fromAddress"]["stateProvince"]
            ),
            parcel=create_shipping_label_request.Parcel(
                height=order["parcel"]["height"],
                length=order["parcel"]["length"],
                dimUnit=order["parcel"]["dimUnit"],
                width=order["parcel"]["width"],
                weightUnit=order["parcel"]["weightUnit"],
                weight=order["parcel"]["weight"]
            ),
            carrierAccountId=carrier_account_id,
            parcelType="PKG",
            serviceId="UGA",
            shipmentOptions=create_shipping_label_request.ShipmentOptions(
                addToManifest=True,
                packageDescription="test" # TODO
            ),
            metadata=[
                create_shipping_label_request.MetadataItem(
                    name="costAccountName", # TODO
                    value="cost account 123" # TODO
                )
            ],
            toAddress=create_shipping_label_request.Address(
                company=order["toAddress"]["company"],
                addressLine1=order["toAddress"]["addressLine1"],
                addressLine2="",
                addressLine3="",
                cityTown=order["toAddress"]["cityTown"],
                countryCode=order["toAddress"]["countryCode"],
                name=order["toAddress"]["name"],
                phone=order["toAddress"]["phone"],
                postalCode=order["toAddress"]["postalCode"],
                stateProvince=order["toAddress"]["stateProvince"]
            )
        )

        url = settings.SP360_SHIPMENTS_URL
        bearer_token = await self.get_sp360_token()
        
        if not bearer_token:
            return "Failed to retrieve bearer token."
        
        headers = {
            "Authorization": f"Bearer {bearer_token}",
            "Content-Type": "application/json",
            "compactResponse": "true"
        }

        async with aiohttp.ClientSession() as session:
            async with session.post(
                url,
                headers=headers,
                json=json_shipping_label_request.model_dump()
            ) as response:
                if response.status == 200:
                    api_response = await response.json()
                    print(api_response)
                    return api_response
                # Non-200 response
                error_text = await response.text()
                return {
                    "error": f"{response.status} - {error_text}"
                }

    # Region: Tracking function - Get tracking information
    # This function retrieves tracking information for a shipment using the tracking number and optional carrier.
    # It constructs the request URL, adds the carrier as a query parameter if provided, and sends a GET request to the API.
    # The function handles the response, returning the tracking information as a JSON object or an error message.
    # The function is asynchronous and uses aiohttp for making HTTP requests.
    # It also retrieves a bearer token for authorization using the get_sp360_token method.
    # The function is designed to be used in an asynchronous context, allowing for non-blocking I/O operations.
    # It is important to note that the function does not handle all possible error cases and may need to be extended for production use.      
    async def get_tracking_info(
        self,
        tracking_number: str,
        carrier: str = None
    ):
        """
        Get tracking information for a shipment.
        
        Args:
            tracking_number: The tracking number of the shipment
            carrier: The carrier (optional). If provided, used as a query parameter.
        
        Returns:
            The tracking information as a JSON object, or an error message
        """
        # Base URL for the tracking endpoint
        base_url = f"{settings.SP360_TRACKING_URL}/{tracking_number}"
        
        # Add carrier as query parameter only if provided
        if carrier:
            url = f"{base_url}?carrier={carrier.upper()}"
        else:
            url = base_url
        
        bearer_token = await self.get_sp360_token()
        
        if not bearer_token:
            return "Failed to retrieve bearer token."
        
        headers = {
            "Authorization": f"Bearer {bearer_token}"
        }

        async with aiohttp.ClientSession() as session:
            async with session.get(
                url,
                headers=headers
            ) as response:
                if response.status == 200:
                    tracking_data = await response.json()
                    return tracking_data
                # Non-200 response
                error_text = await response.text()
                return {
                    "error": f"{response.status} - {error_text}"
                }     
    # End Region

    async def get_shipments(
        self,
        startDate: str = None,
        endDate: str = None,
        page: str = None,
        size: str = None
    ):
        """
        Get shipments with optional date filtering.
        
        Args:
            startDate: Optional start date in YYYY-MM-DD format
            endDate: Optional end date in YYYY-MM-DD format
            page: Optional page number for pagination
            size: Optional number of items per page
        
        Returns:
            The shipments information as a JSON object, or an error message
        """
        # Base URL for the shipments endpoint
        base_url = f"{settings.SP360_SHIPMENTS_URL}"
        
        # Build query parameters
        query_params = []
        
        # Add date parameters only if provided
        if startDate:
            query_params.append(f"startDate={startDate}")
        if endDate:
            query_params.append(f"endDate={endDate}")
        if page:
            query_params.append(f"page={page}")
        if size:
            query_params.append(f"size={size}")
        
        # Construct the full URL with query parameters
        if query_params:
            url = f"{base_url}?{'&'.join(query_params)}"
        else:
            url = base_url
        
        bearer_token = await self.get_sp360_token()
        
        if not bearer_token:
            return "Failed to retrieve bearer token."
        
        headers = {
            "Authorization": f"Bearer {bearer_token}"
        }

        async with aiohttp.ClientSession() as session:
            async with session.get(
                url,
                headers=headers
            ) as response:
                if response.status == 200:
                    shipments_data = await response.json()
                    return shipments_data
                # Non-200 response
                error_text = await response.text()
                return {
                    "error": f"{response.status} - {error_text}"
                }