import aiohttp
from app.core.config import settings

class Ship360Service:
    def __init__(self):
        # Validate required settings
        if not all([
            getattr(settings, "SP360_TOKEN_URL", None),
            getattr(settings, "SP360_TOKEN_USERNAME", None),
            getattr(settings, "SP360_TOKEN_PASSWORD", None)
        ]):
            raise ValueError("Required Ship 360 settings are missing")
        
    async def get_shipping_authorization(self):
        url = settings.SP360_TOKEN_URL
        auth = aiohttp.BasicAuth(settings.SP360_TOKEN_USERNAME, settings.SP360_TOKEN_PASSWORD)
        headers = {"Content-Type": "application/json"}

        async with aiohttp.ClientSession() as session:
            async with session.post(url, headers=headers, auth=auth) as response:
                data = await response.json()
                if response.status == 200:
                    print(data)
                else:
                    print(f"Error: {response.status}")
                return data
            
    async def perform_rate_shop(self, payload):
        pass