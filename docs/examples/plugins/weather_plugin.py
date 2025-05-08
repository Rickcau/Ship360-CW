
from semantic_kernel.functions import kernel_function
from semantic_kernel import Kernel

class WeatherPlugin:
    @kernel_function(name="get_weather", description="Get weather for location")
    async def get_weather(self, location: str) -> str:
        return f"Sunny in {location}"
    
    