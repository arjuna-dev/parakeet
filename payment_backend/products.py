class ProductData:
    def __init__(self, product_id: str, product_type: str):
        self.product_id = product_id
        self.type = product_type

product_data_map = {
    "1m": ProductData("1m", "SUBSCRIPTION"),
}