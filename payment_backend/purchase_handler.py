from abc import ABC, abstractmethod
from typing import Dict, Any

class ProductData:
    def __init__(self, product_id: str, product_type: str):
        self.productId = product_id
        self.type = product_type

class PurchaseHandler(ABC):
    async def verify_purchase(self, user_id: str, product_data: ProductData, token: str) -> bool:
        if product_data.type == "SUBSCRIPTION":
            return await self.handle_subscription(user_id, product_data, token)
        elif product_data.type == "NON_SUBSCRIPTION":
            return await self.handle_non_subscription(user_id, product_data, token)
        else:
            return False

    @abstractmethod
    async def handle_subscription(self, user_id: str, product_data: ProductData, token: str) -> bool:
        pass

    @abstractmethod
    async def handle_non_subscription(self, user_id: str, product_data: ProductData, token: str) -> bool:
        pass
