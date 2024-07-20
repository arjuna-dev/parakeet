from firebase_admin import initialize_app, firestore, credentials
from firebase_functions import https_fn
from google.cloud import pubsub_v1
from products import product_data_map
from constants import CLOUD_REGION, SERVICE_ACCOUNT_FILE

from firebase_calls import FirebaseCalls
from purchase_handler import PurchaseHandler
# from app_store_purchase_handler import AppStorePurchaseHandler
# from google_play_purchase_handler import GooglePlayPurchaseHandler
from inapppy import GooglePlayValidator, InAppPyValidationError
from products import product_data_map

cred = credentials.Certificate(SERVICE_ACCOUNT_FILE)
app = initialize_app(cred, name='payment-backend')
db = firestore.client()

firebase_calls = FirebaseCalls(db)
purchase_handlers = {
    "google_play": GooglePlayPurchaseHandler(firebase_calls),
    # "app_store": AppStorePurchaseHandler(firebase_calls),
}


def verify_purchase(data, context):
    # Check for auth
    if not context.auth:
        print("verifyPurchase was called no authentication")
        raise https_fn.HttpsError("unauthenticated", "Request was not authenticated.")
    
    product_data = product_data_map.get(data['productId'])
    # Product data was unknown
    if not product_data:
        print(f'verifyPurchase was called for an unknown product ("{data["productId"]}")')
        return False
    
    # Called from unknown source
    if data['source'] not in purchase_handlers:
        print(f'verifyPurchase called for an unknown source ("{data["source"]}")')
        return False
    
    # Validate the purchase
    return purchase_handlers[data['source']].verify_purchase(
        context.auth.uid,
        product_data,
        data['verificationData'],
    )

verify_purchase_function = https_fn.on_call(verify_purchase, region=CLOUD_REGION)

# handle_app_store_server_event = purchase_handlers['app_store'].handle_server_event
handle_play_store_server_event = purchase_handlers['google_play'].handle_server_event

def expire_subscriptions(event):
    firebase_calls.expire_subscriptions()

expire_subscriptions_function = pubsub_v1.schedule("*/10 */1 * * *").time_zone("America/New_York").on_run(expire_subscriptions)