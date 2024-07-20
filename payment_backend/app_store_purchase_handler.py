# import json
# import jwt
# import requests
# from datetime import datetime
# from google.cloud import firestore
# from google.cloud import pubsub_v1
# from google.cloud.functions_v1.context import Context
# import firebase_admin
# from firebase_admin import credentials, firestore, functions
# from typing import List, Dict, Any
# from products import product_data_map
# from constants import APP_STORE_SHARED_SECRET

# # Replace with actual paths and constants
# SERVICE_ACCOUNT_FILE = 'path/to/service-account.json'
# CLOUD_REGION = 'your-cloud-region'

# cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
# firebase_admin.initialize_app(cred)
# db = firestore.client()

# class AppStorePurchaseHandler:
#     def __init__(self):
#         self.config = {
#             'verbose': True,
#             'secret': APP_STORE_SHARED_SECRET,
#             'extended': True,
#             'environment': 'production',
#             'excludeOldTransactions': True
#         }

#     async def handle_subscription(self, user_id: str, product_data: Dict[str, Any], token: str) -> bool:
#         return await self.handle_validation(user_id, token)

#     async def handle_non_subscription(self, user_id: str, product_data: Dict[str, Any], token: str) -> bool:
#         return await self.handle_validation(user_id, token)

#     async def handle_validation(self, user_id: str, token: str) -> bool:
#         try:
#             response = requests.post(
#                 'https://buy.itunes.apple.com/verifyReceipt',
#                 json={'receipt-data': token, 'password': self.config['secret']}
#             )
#             response_data = response.json()
            
#             if response_data.get('status') != 0:
#                 print("Receipt validation failed with status:", response_data.get('status'))
#                 return False

#             products = response_data.get('latest_receipt_info', [])
#         except Exception as e:
#             print("Could not verify the receipt because of error:", e)
#             return False

#         for product in products:
#             product_data = product_data_map.get(product.get('product_id'))
#             if not product_data:
#                 continue

#             purchase_date = int(product.get('purchase_date_ms')) // 1000
#             expiration_date = int(product.get('expires_date_ms', 0)) // 1000

#             purchase_data = {
#                 'iapSource': 'app_store',
#                 'orderId': product.get('original_transaction_id'),
#                 'productId': product.get('product_id'),
#                 'userId': user_id,
#                 'purchaseDate': datetime.utcfromtimestamp(purchase_date),
#                 'type': product_data['type'],
#                 'status': 'EXPIRED' if expiration_date <= datetime.utcnow().timestamp() else 'ACTIVE'
#             }

#             if product_data['type'] == 'SUBSCRIPTION':
#                 purchase_data['expiryDate'] = datetime.utcfromtimestamp(expiration_date)
#                 await self.create_or_update_purchase(purchase_data)
#             elif product_data['type'] == 'NON_SUBSCRIPTION':
#                 purchase_data['status'] = 'COMPLETE'
#                 await self.create_or_update_purchase(purchase_data)

#         return True

#     async def create_or_update_purchase(self, purchase_data: Dict[str, Any]):
#         doc_ref = db.collection('purchases').document(purchase_data['orderId'])
#         doc_ref.set(purchase_data)

#     def handle_server_event(self, request):
#         try:
#             decoded_body = jwt.decode(request.json.get('signedPayload'), options={"verify_signature": False})
#             signed_info = jwt.decode(decoded_body['data']['signedTransactionInfo'], options={"verify_signature": False})
#             event_data = {
#                 'notificationType': decoded_body['notificationType'],
#                 'productId': signed_info['productId'],
#                 'expiresDate': signed_info['expiresDate'],
#                 'originalTransactionId': signed_info['originalTransactionId']
#             }
#         except Exception as e:
#             print("Could not parse Apple notification event", e)
#             return {"status": 400, "message": "Invalid request"}

#         product_data = product_data_map.get(event_data['productId'])
#         if not product_data:
#             print("No matching product data for product:", event_data['productId'])
#             return {"status": 403, "message": "Product not found"}

#         if product_data['type'] == 'SUBSCRIPTION':
#             try:
#                 expiry_date = int(event_data['expiresDate']) // 1000
#                 status = 'EXPIRED' if datetime.utcnow().timestamp() >= expiry_date else 'ACTIVE'
#                 update_data = {
#                     'iapSource': 'app_store',
#                     'orderId': event_data['originalTransactionId'],
#                     'expiryDate': datetime.utcfromtimestamp(expiry_date),
#                     'status': status
#                 }
#                 doc_ref = db.collection('purchases').document(event_data['originalTransactionId'])
#                 doc_ref.update(update_data)
#             except Exception as e:
#                 print("Could not update purchase", event_data)

#         return {"status": 200, "message": "Event processed successfully"}

# # Cloud Function to handle HTTP requests
# def apple_purchase_event(request):
#     handler = AppStorePurchaseHandler()
#     response = handler.handle_server_event(request)
#     return response, response['status']
