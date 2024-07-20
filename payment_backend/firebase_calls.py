import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
from typing import Union, Literal, Dict, Any

# Initialize Firebase
cred = credentials.Certificate('./assets/service-account.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

SubscriptionStatus = Literal['PENDING', 'ACTIVE', 'EXPIRED']
NonSubscriptionStatus = Literal['PENDING', 'COMPLETE', 'CANCELED']
IAPSource = Literal['google_play', 'app_store']

class BasePurchase:
    def __init__(self, iapSource: IAPSource, orderId: str, productId: str, userId: str, purchaseDate: datetime):
        self.iapSource = iapSource
        self.orderId = orderId
        self.productId = productId
        self.userId = userId
        self.purchaseDate = purchaseDate

class SubscriptionPurchase(BasePurchase):
    def __init__(self, iapSource: IAPSource, orderId: str, productId: str, userId: str, purchaseDate: datetime, expiryDate: datetime, status: SubscriptionStatus):
        super().__init__(iapSource, orderId, productId, userId, purchaseDate)
        self.type = 'SUBSCRIPTION'
        self.expiryDate = expiryDate
        self.status = status

class NonSubscriptionPurchase(BasePurchase):
    def __init__(self, iapSource: IAPSource, orderId: str, productId: str, userId: str, purchaseDate: datetime, status: NonSubscriptionStatus):
        super().__init__(iapSource, orderId, productId, userId, purchaseDate)
        self.type = 'NON_SUBSCRIPTION'
        self.status = status

Purchase = Union[SubscriptionPurchase, NonSubscriptionPurchase]

class FirebaseCalls:
    def __init__(self, firestore_client):
        self.firestore = firestore_client

    async def create_or_update_purchase(self, purchase_data: Purchase):
        purchases = self.firestore.collection('purchases')
        purchase_id = f"{purchase_data.iapSource}_{purchase_data.orderId}"
        purchase_ref = purchases.document(purchase_id)
        await purchase_ref.set(purchase_data.__dict__)
        await self.update_user_with_purchase(purchase_ref)

    async def update_purchase(self, purchase_data: Dict[str, Any]):
        purchases = self.firestore.collection('purchases')
        purchase_id = f"{purchase_data['iapSource']}_{purchase_data['orderId']}"
        purchase_ref = purchases.document(purchase_id)
        await purchase_ref.update(purchase_data)
        await self.update_user_with_purchase(purchase_ref)

    async def update_user_with_purchase(self, purchase_ref):
        purchase_doc = await purchase_ref.get()
        purchase_data = purchase_doc.to_dict()
        if 'userId' in purchase_data:
            user_ref = self.firestore.collection('users').document(purchase_data['userId'])
            if purchase_data['productId'] in ['unlimited_yt_monthly', 'unlimited_yt_yearly']:
                if purchase_data['status'] == 'ACTIVE':
                    await user_ref.update({'unlimited': True})
                elif purchase_data['status'] == 'EXPIRED':
                    await user_ref.update({'unlimited': False})

    async def expire_subscriptions(self):
        documents = self.firestore.collection('purchases').where('expiryDate', '<=', firestore.SERVER_TIMESTAMP).where('status', '==', 'ACTIVE').stream()
        write_batch = self.firestore.batch()
        for doc in documents:
            data = doc.to_dict()
            if data['productId'] in ['unlimited_yt_monthly', 'unlimited_yt_yearly']:
                user_ref = self.firestore.collection('users').document(data['userId'])
                await user_ref.update({'unlimited': False})
            write_batch.update(doc.reference, {'status': 'EXPIRED'})
        await write_batch.commit()

# Example usage:
firebase_calls = FirebaseCalls(db)
