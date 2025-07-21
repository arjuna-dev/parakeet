import { firestore } from "firebase-admin";
import Timestamp = firestore.Timestamp;

export type SubscriptionStatus = "PENDING" | "ACTIVE" | "EXPIRED";
export type NonSubscriptionStatus = "PENDING" | "COMPLETE" | "CANCELED";

export type IAPSource = "google_play" | "app_store";
export type Purchase = SubscriptionPurchase | NonSubscriptionPurchase;

export interface BasePurchase {
  iapSource: IAPSource;
  orderId: string;
  productId: string;
  userId: string;
  purchaseDate: firestore.Timestamp;
}

export interface SubscriptionPurchase extends BasePurchase {
  type: "SUBSCRIPTION";
  expiryDate: firestore.Timestamp;
  status: SubscriptionStatus;
}

export interface NonSubscriptionPurchase extends BasePurchase {
  type: "NON_SUBSCRIPTION";
  status: NonSubscriptionStatus;
}

export class FirebaseCalls {
  constructor(private firestore: FirebaseFirestore.Firestore) {}

  async createOrUpdatePurchase(purchaseData: Purchase): Promise<void> {
    const purchases = this.firestore.collection("purchases");
    const purchaseId = `${purchaseData.iapSource}_${purchaseData.orderId}`;
    const purchase = purchases.doc(purchaseId);
    await purchase.set(purchaseData);
    this.updateUserWithPurchase(purchase);
  }

  async updatePurchase(
    purchaseData: { iapSource: IAPSource; orderId: string } & Partial<Purchase>
  ): Promise<void> {
    const purchases = this.firestore.collection("purchases");
    const purchaseId = `${purchaseData.iapSource}_${purchaseData.orderId}`;
    const purchase = purchases.doc(purchaseId);
    await purchase.update(purchaseData);
    this.updateUserWithPurchase(purchase);
  }

  async updateUserWithPurchase(
    purchaseRef: firestore.DocumentReference
  ): Promise<void> {
    const purchaseDoc = await purchaseRef.get();
    if (typeof purchaseDoc?.data()?.userId != undefined) {
      const userRef = this.firestore
        .collection("users")
        .doc(purchaseDoc?.data()?.userId);
      if (!["1m", "1year"].includes(purchaseDoc?.data()?.productId)) return;
      if (purchaseDoc?.data()?.status == "ACTIVE") {
        userRef.update({
          premium: true,
        });
      } else if (purchaseDoc?.data()?.status == "EXPIRED") {
        userRef.update({
          premium: false,
        });
      }
    }
  }

  async expireSubscriptions(): Promise<void> {
    const documents = await this.firestore
      .collection("purchases")
      .where("expiryDate", "<=", Timestamp.now())
      .where("status", "==", "ACTIVE")
      .get();
    if (!documents.size) return;
    const writeBatch = this.firestore.batch();
    documents.docs.forEach((doc) => {
      if (["1m", "1year"].includes(doc.data().productId)) {
        const userRef = this.firestore
          .collection("users")
          .doc(doc.data().userId);
        userRef.update({
          premium: false,
        });
      }
      writeBatch.update(doc.ref, { status: "EXPIRED" });
    });
    await writeBatch.commit();
  }
}
