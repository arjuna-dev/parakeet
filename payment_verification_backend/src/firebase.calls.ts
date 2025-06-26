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
          lesson_credit: 65,
          lastCreditReset: firestore.Timestamp.now(),
        });
      } else if (purchaseDoc?.data()?.status == "EXPIRED") {
        userRef.update({
          premium: false,
          lesson_credit: 0,
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
          lesson_credit: 0,
        });
      }
      writeBatch.update(doc.ref, { status: "EXPIRED" });
    });
    await writeBatch.commit();
  }

  async resetMonthlyCredits(): Promise<void> {
    const now = Timestamp.now();

    // Get all subscription purchases
    const allSubscriptions = await this.firestore
      .collection("purchases")
      .where("type", "==", "SUBSCRIPTION")
      .where("productId", "in", ["1m", "1year"])
      .get();

    if (!allSubscriptions.size) return;

    const writeBatch = this.firestore.batch();
    const processedUsers = new Set<string>();
    let resetCount = 0;
    let expiredCount = 0;

    for (const doc of allSubscriptions.docs) {
      const purchase = doc.data() as SubscriptionPurchase;

      // Skip if user already processed in this batch
      if (processedUsers.has(purchase.userId)) continue;

      const userRef = this.firestore.collection("users").doc(purchase.userId);

      // Get user document
      const userDoc = await userRef.get();
      if (!userDoc.exists) continue;

      const userData = userDoc.data();
      const lastCreditReset = userData?.lastCreditReset;

      // Check if subscription is expired
      if (
        purchase.status === "EXPIRED" ||
        purchase.expiryDate.toDate().toDateString() <=
          now.toDate().toDateString()
      ) {
        // Reset credits to 0 for expired users
        writeBatch.update(userRef, {
          lesson_credit: 0,
          premium: false,
        });
        processedUsers.add(purchase.userId);
        expiredCount++;
        continue;
      }

      // Check if subscription is active
      if (purchase.status !== "ACTIVE") continue;

      // Determine the reference date for monthly reset
      let referenceDate: Timestamp;
      if (lastCreditReset) {
        // Use last reset date as reference
        referenceDate = lastCreditReset;
      } else {
        // Use purchase date as reference for first-time reset
        referenceDate = purchase.purchaseDate;
      }

      // Calculate if one month has passed since reference date
      const oneMonthAfterReference = new Date(referenceDate.toDate());
      oneMonthAfterReference.setMonth(oneMonthAfterReference.getMonth() + 1);

      // Reset credits if:
      // 1. One month has passed since reference date
      // 2. AND the expiry date is still in the future (subscription hasn't expired)
      if (
        now.toDate() >= oneMonthAfterReference &&
        purchase.expiryDate.toDate().toDateString() >
          now.toDate().toDateString()
      ) {
        writeBatch.update(userRef, {
          lesson_credit: 65,
          lastCreditReset: now,
          premium: true,
        });
        processedUsers.add(purchase.userId);
        resetCount++;
      }
    }

    if (processedUsers.size > 0) {
      await writeBatch.commit();
      console.log(
        `Reset credits for ${resetCount} premium users, expired ${expiredCount} users`
      );
    }
  }
}
