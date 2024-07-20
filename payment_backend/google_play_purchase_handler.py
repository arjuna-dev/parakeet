import json
import base64
import re
from google.oauth2 import service_account
from googleapiclient.discovery import build
from google.cloud import pubsub_v1
from firebase_admin import firestore
from products import product_data_map
from datetime import datetime
from constants import SERVICE_ACCOUNT_FILE, ANDROID_PACKAGE_ID, CLOUD_REGION, GOOGLE_PLAY_PUBSUB_TOPIC

# Replace with actual paths and constants


db = firestore.client()

class GooglePlayPurchaseHandler:
    def __init__(self):
        self.credentials = service_account.Credentials.from_service_account_file(
            SERVICE_ACCOUNT_FILE,
            scopes=["https://www.googleapis.com/auth/androidpublisher"],
        )
        self.android_publisher = build('androidpublisher', 'v3', credentials=self.credentials)
        
    async def handle_subscription(self, user_id, product_data, token):
        try:
            response = self.android_publisher.purchases().subscriptions().get(
                packageName=ANDROID_PACKAGE_ID,
                subscriptionId=product_data['productId'],
                token=token
            ).execute()

            if not response.get('orderId'):
                print("Could not handle purchase without order id")
                return False

            order_id = response['orderId']
            order_id_match = re.match(r'^(.+)?[.]{2}[0-9]+$', order_id)
            if order_id_match:
                order_id = order_id_match.group(1)

            purchase_data = {
                'iapSource': 'google_play',
                'orderId': order_id,
                'productId': product_data['productId'],
                'purchaseDate': datetime.utcfromtimestamp(int(response.get('startTimeMillis', '0')) / 1000),
                'type': 'SUBSCRIPTION',
                'expiryDate': datetime.utcfromtimestamp(int(response.get('expiryTimeMillis', '0')) / 1000),
                'status': ['PENDING', 'ACTIVE', 'ACTIVE', 'PENDING', 'EXPIRED'][response.get('paymentState', 4)]
            }

            if user_id:
                purchase_data['userId'] = user_id
                self.create_or_update_purchase(purchase_data)
            else:
                self.update_purchase(purchase_data)
            return True
        except Exception as e:
            print("Could not verify the purchase because of error", e)
            return False

    async def handle_non_subscription(self, user_id, product_data, token):
        try:
            response = self.android_publisher.purchases().products().get(
                packageName=ANDROID_PACKAGE_ID,
                productId=product_data['productId'],
                token=token
            ).execute()

            if not response.get('orderId'):
                print("Could not handle purchase without order id")
                return False

            purchase_data = {
                'iapSource': 'google_play',
                'orderId': response['orderId'],
                'productId': product_data['productId'],
                'purchaseDate': datetime.utcfromtimestamp(int(response.get('purchaseTimeMillis', '0')) / 1000),
                'type': 'NON_SUBSCRIPTION',
                'status': ['COMPLETE', 'CANCELED', 'PENDING'][response.get('purchaseState', 0)]
            }

            if user_id:
                purchase_data['userId'] = user_id
                self.create_or_update_purchase(purchase_data)
            else:
                self.update_purchase(purchase_data)
            return True
        except Exception as e:
            print("Could not verify the purchase because of error", e)
            return False

    def create_or_update_purchase(self, purchase_data):
        doc_ref = db.collection('purchases').document(purchase_data['orderId'])
        doc_ref.set(purchase_data)

    def update_purchase(self, purchase_data):
        doc_ref = db.collection('purchases').document(purchase_data['orderId'])
        doc_ref.update(purchase_data)

    def handle_server_event(self, event):
        try:
            event_data = json.loads(base64.b64decode(event['data']).decode('utf-8'))
        except Exception as e:
            print("Could not parse Google Play billing event", e)
            return

        purchase_token = event_data.get('subscriptionNotification', {}).get('purchaseToken') or \
                         event_data.get('oneTimeProductNotification', {}).get('purchaseToken')
        subscription_id = event_data.get('subscriptionNotification', {}).get('subscriptionId')
        sku = event_data.get('oneTimeProductNotification', {}).get('sku')

        product_data = product_data_map.get(subscription_id or sku)
        if not product_data:
            return

        notification_type = 'SUBSCRIPTION' if subscription_id else 'NON_SUBSCRIPTION' if sku else None
        if product_data['type'] != notification_type:
            return

        if notification_type == 'SUBSCRIPTION':
            self.handle_subscription(None, product_data, purchase_token)
        elif notification_type == 'NON_SUBSCRIPTION':
            self.handle_non_subscription(None, product_data, purchase_token)


def google_play_billing_event(event, context):
    handler = GooglePlayPurchaseHandler()
    handler.handle_server_event(event)
