import json
import os
import logging
from typing import Dict, Optional, Any
from functools import lru_cache

logger = logging.getLogger(__name__)

class OrderService:
    """Service to handle operations on mock customer orders data."""
    
    def __init__(self):
        """Initialize the order service with data from orders.json. We can generecize this if needed, but leaving it as orders.json for now."""
        self.orders_file_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'orders.json')
        self.orders_by_number: Dict[str, Dict[str, Any]] = {}
        self.load_orders()
    
    def load_orders(self) -> None:
        """Load orders from the JSON file into memory. This will mock the database being used in production."""
        try:
            with open(self.orders_file_path, 'r') as file:
                orders = json.load(file)
                
            # Index orders by order number for fast lookups
            self.orders_by_number = {order["orderNumber"]: order for order in orders}
            logger.info(f"Successfully loaded {len(self.orders_by_number)} orders")
        
        except Exception as e:
            logger.error(f"Error loading orders from {self.orders_file_path}: {str(e)}")
            # Initialize with empty dict if there's an error
            self.orders_by_number = {}
    
    def get_order(self, order_number: str) -> Optional[Dict[str, Any]]:
        """Get an order by its order number"""
        return self.orders_by_number.get(order_number)

@lru_cache(maxsize=1)
def get_order_service() -> OrderService:
    """Get a singleton instance of the OrderService"""
    return OrderService()