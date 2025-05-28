from typing import Annotated, Optional, Union
from semantic_kernel import Kernel
from semantic_kernel.functions import kernel_function
from semantic_kernel.functions.kernel_arguments import KernelArguments
from app.core.config import settings
from app.services.orders import OrderService
from app.services.ship_360_service import Ship360Service
from app.models.rate_shop_models import RateShopRequest

order_service = OrderService()
ship_360_service = Ship360Service()

class ShippingPlugin:
    def __init__(self, order_service: OrderService, kernel: Kernel = None):
        if not all([
            settings.SP360_TOKEN_URL,
            settings.SP360_TOKEN_USERNAME,
            settings.SP360_TOKEN_PASSWORD
        ]):
            raise ValueError("Required Ship 360 settings are missing")
        
        self.order_service = order_service
        self.kernel = kernel

    @kernel_function(name="RateShop", description="Given an Order Id, return a list of shipping options using the maximum price and duration, if provided.")
    async def perform_rate_shop(
        self,
        order_id: Annotated[str, "The unique identifier for the order"],
        max_price: Annotated[float, "Maximum price for shipping options"] = 0.0,
        duration_value: Annotated[int, "Maximum duration in days for shipping options"] = 0,
        duration_comparison_operator: Annotated[str, "Comparison operator for duration (less_than, less_than_or_equal)"] = "less_than_or_equal"
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
            duration_comparison_operator=duration_comparison_operator
        )

    # RDC Added 5/21/2025
    @kernel_function(name="RateShop_Without_Order", description="Get shipping options without an order id using the maximum price and duration, if provided.")
    async def perform_rate_shop_without_order_id(
        self,
        user_prompt: Annotated[str, "The question the user is asking"],
        max_price: Annotated[Optional[Union[float, str]], "Maximum price for shipping options"] = 0.0,
        duration_value: Annotated[Optional[Union[int, str]], "Maximum duration in days for shipping options"] = 0,
        duration_comparison_operator: Annotated[str, "Comparison operator for duration (less_than, less_than_or_equal)"] = "less_than_or_equal"
    ):
        # Check if kernel is available
        if not self.kernel:
            return {"error": "Kernel is required for this operation."}
        
        # Get the current date in YYYY-MM-DD format for the default value of the JSON structure
        current_date = await self.get_current_date()

        from semantic_kernel.connectors.ai.open_ai import OpenAIChatPromptExecutionSettings

        request_settings = OpenAIChatPromptExecutionSettings(
            service_id='default', max_tokens=2000, temperature=0.0, top_p=0.95, response_format={"type": "json_object"}
        )
        #request_settings.response_format = RateShopRequest
        
        # Define your prompt template with the JSON structure and additional logic
        prompt_template = f"""
        You are a specialized shipping information extractor. Extract ALL shipping details from the user's request.
        
        User request: {{{{$input}}}}
        
        Based on the user's request, fill in the following JSON structure with any information you can extract.
        For any fields that weren't mentioned or are unclear, leave them as empty strings or null values for numbers.
        Use 'IN' for inches, and 'LBS' for pounds and 'OZ' for ounces as dimension and weight units, respectively, when applicable.
        Default to 'US' for countryCode if not specified. Default to current date in YYYY-MM-DD format for dateOfShipment, if not specified.

        REQUIRED INFORMATION:
        - A complete "fromAddress" (addressLine1, cityTown, postalCode, stateProvince)
        - A complete "toAddress" (addressLine1, cityTown, postalCode, stateProvince)
        - Complete parcel information (length, width, height, weight)
        
        EXTRACTION GUIDELINES:
        1. FOR ADDRESSES:
            - Look for patterns like "from [address]" and "to [address]"
            - If you see a full address with street number, ALWAYS extract it as addressLine1
            - Examples of addressLine1: "421 8th Avenue", "415 Mission Street", "123 Main St"
            - If you see city, state, zip combinations, parse them separately
            - NEVER leave addressLine1 empty if any street address is mentioned
            - Country codes (default to "US" if not specified)
            - IMPORTANT: If any address information is missing, set them to null and include a clear explanation in llmResponse
        2. FOR PACKAGE INFORMATION:
            - Dimensions in the format LxWxH (e.g., "10x6x4 in")
            - Weight with units (e.g., "2 lbs")
            - IMPORTANT: If any parcel dimensions or weight are missing, set them to null and include a clear explanation in llmResponse

        VALIDATION CHECK:
            - If you see a street address in the input but haven't extracted it, double-check your extraction
            - For "infoComplete" to be true, BOTH addresses must have addressLine1, cityTown, stateProvince, postalCode AND parcel must have length, width, height, weight and unit

        CURRENT DATE: {current_date}
       
        Do not include ```json or any other formatting in your response. Please respond ONLY with the completed JSON object and nothing else:
        
        {{
            "fromAddress": {{
                "addressLine1": "",
                "addressLine2": "",
                "addressLine3": "",
                "cityTown": "",
                "company": "",
                "countryCode": "",
                "email": "",
                "name": "",
                "phone": "",
                "postalCode": "",
                "stateProvince": ""
            }},
            "toAddress": {{
                "addressLine1": "",
                "addressLine2": "",
                "addressLine3": "",
                "cityTown": "",
                "company": "",
                "countryCode": "",
                "email": "",
                "name": "",
                "phone": "",
                "postalCode": "",
                "stateProvince": ""
            }},
            "parcel": {{
                "dimUnit": "IN",
                "length": null,
                "width": null,
                "height": null,
                "weightUnit": "OZ",
                "weight": null
            }},
            "dateOfShipment": "",
            "parcelType": "PKG",
            "llmResponse": "",
            "infoComplete": false
        }}
        """
        
        # Set up context variables with the user's input
        context_variables = KernelArguments(input=user_prompt)
        
        # Invoke the prompt
        result = await self.kernel.invoke_prompt(
            prompt=prompt_template,
            arguments=context_variables,
            prompt_execution_settings=request_settings
        )

        # The result should be a JSON string that you can parse
        import json
        try:
            extracted_info = json.loads(str(result))
            
            # Check if information is complete
            if extracted_info.get("infoComplete", True):
                # If complete, proceed with rate shop, but remove llmresponse and infoComplete fields
                extracted_info.pop("llmResponse", None)
                extracted_info.pop("infoComplete", None)

                # Create the model instance - not being used for now since the service handles the json structure
                #rate_shop_request = RateShopRequest(**extracted_info)

                return await ship_360_service.perform_rate_shop(extracted_info, max_price, duration_value, duration_comparison_operator)
            else:
                # If incomplete, return the extraction result with the message
                return extracted_info
        except json.JSONDecodeError:
            return {"error": "Failed to parse the model's response as JSON."}

    @kernel_function(name="CreateShippingLabel", description="Create a shipping label for a given Order Id using the provided carrier account id and shipping label size.")
    async def create_shipping_label(
        self,
        order_id: Annotated[str, "The unique identifier for the order."],
        carrier_account_id: Annotated[str, "The unique identifier for the carrier account."],
        service_id: Annotated[str, "The service id for the carrier account."],
        shipping_label_size: Annotated[str, "The size of the printed shipping label."]
    ):
        order = self.order_service.get_order(order_id)
        if not order:
            return f"Order with ID {order_id} not found."

        api_response = await ship_360_service.create_shipment_domestic(
                order=order,
                carrier_account_id=carrier_account_id,
                service_id=service_id,
                shipping_label_size=shipping_label_size
            )
        
        data = {
            "parcelTrackingNumber": api_response["parcelTrackingNumber"],
            "shipmentId": api_response["shipmentId"],
            "shipping_label_url": api_response["labelLayout"][0]["contents"]
        }

        return data

    @kernel_function(name="GetTrackingDetails", description="Get tracking details for a given Tracking Number.")
    async def get_tracking_details(
        self,
        tracking_number: Annotated[str, "The unique identifier for the tracking number."]
    ):
        
        api_response = await ship_360_service.get_tracking_info(
                tracking_number=tracking_number
            )
        
        data = {
            # From the top level of the response
            "estimatedDeliveryDate": api_response.get("estimatedDeliveryDate"),
            "serviceName": api_response.get("serviceName"),
            
            # From the currentStatus object
            "carrierEventDescription": api_response.get("currentStatus", {}).get("carrierEventDescription"),
            "eventDescription": api_response.get("currentStatus", {}).get("eventDescription"),
            "status": api_response.get("currentStatus", {}).get("status"),
            "eventDate": api_response.get("currentStatus", {}).get("eventDate"),
            
            # Include the full tracking history
            "trackingHistory": api_response.get("trackingHistory", [])
        }

        return data
    
    @kernel_function(name="GetCurrentDate", description="Get the current date in YYYY-MM-DD format.")
    async def get_current_date(self):
        """
        Returns the current date in YYYY-MM-DD format.
        
        This function can be called by GenAI when the current date is needed for operations
        such as setting default date ranges or comparing with other dates.
        
        Returns:
        A string representing the current date in YYYY-MM-DD format.
        """
        from datetime import datetime
        
        # Get the current date and format it as YYYY-MM-DD
        current_date = datetime.now().strftime("%Y-%m-%d")
        
        return {
            "current_date": current_date
        }
    
    @kernel_function(name="GetShipments", description="Get shipments with optional date filtering.")
    async def get_shipments(
        self,
        current_date: Annotated[str, "The current date in YYYY-MM-DD format of today"],
        startDate: Annotated[str, "Starting date in YYYY-MM-DD format (optional, leave empty for no filter)"] = "",
        endDate: Annotated[str, "Ending date in YYYY-MM-DD format (optional, leave empty for no filter)"] = ""
    ):
        """
        Get shipments with optional date filtering.
        
        Parameters:
        - current_date: The current date in YYYY-MM-DD format.
        - startDate: Optional starting date in YYYY-MM-DD format.
        - endDate: Optional ending date in YYYY-MM-DD format.
        
        Returns:
        A dictionary containing the filtered shipments and pagination info.
        """
        
        # Validate date formats if provided
        if not isinstance(startDate, str):
            raise ValueError("startDate must be a string in YYYY-MM-DD format.")
        if not isinstance(endDate, str):
            raise ValueError("endDate must be a string in YYYY-MM-DD format.")
            
        # Build the query parameters for the API call
        start_date_param = None
        end_date_param = None
        
        # Only use date parameters if they are not empty
        if startDate and startDate.strip():
            start_date_param = startDate.strip()
        if endDate and endDate.strip():
            end_date_param = endDate.strip()
        
        # Make the API call to get shipments
        api_response = await ship_360_service.get_shipments(
            startDate=start_date_param,
            endDate=end_date_param
        )
        
        # Extract only the required fields from each shipment
        filtered_shipments = []
        for shipment in api_response.get("data", []):
            # Get carrier from the first rate in rates array
            carrier = None
            total_carrier_charge = None
            if shipment.get("rates") and len(shipment.get("rates")) > 0:
                carrier = shipment["rates"][0].get("carrier")
                total_carrier_charge = shipment["rates"][0].get("totalCarrierCharge")
            
            filtered_shipment = {
                "shipmentId": shipment.get("shipmentId"),
                "parcelTrackingNumber": shipment.get("parcelTrackingNumber"),
                "carrier": carrier,
                "toAddress": shipment.get("toAddress"),
                "totalCarrierCharge": total_carrier_charge
            }
            filtered_shipments.append(filtered_shipment)
        
        # Return the filtered data with pagination info
        return {
            "data": filtered_shipments,
            "pageInfo": api_response.get("pageInfo", {})
        }
    
    @kernel_function(name="CancelShipment", description="Given a Shipment Id, cancel the shipment and return cancelation status.")
    async def cancel_shipment(
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