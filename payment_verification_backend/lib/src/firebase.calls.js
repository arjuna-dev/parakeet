"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.FirebaseCalls = void 0;
const firebase_admin_1 = require("firebase-admin");
var Timestamp = firebase_admin_1.firestore.Timestamp;
class FirebaseCalls {
    constructor(firestore) {
        this.firestore = firestore;
    }
    async createOrUpdatePurchase(purchaseData) {
        const purchases = this.firestore.collection("purchases");
        const purchaseId = `${purchaseData.iapSource}_${purchaseData.orderId}`;
        const purchase = purchases.doc(purchaseId);
        await purchase.set(purchaseData);
        this.updateUserWithPurchase(purchase);
    }
    async updatePurchase(purchaseData) {
        const purchases = this.firestore.collection("purchases");
        const purchaseId = `${purchaseData.iapSource}_${purchaseData.orderId}`;
        const purchase = purchases.doc(purchaseId);
        await purchase.update(purchaseData);
        this.updateUserWithPurchase(purchase);
    }
    async updateUserWithPurchase(purchaseRef) {
        var _a, _b, _c, _d, _e;
        const purchaseDoc = await purchaseRef.get();
        if (typeof ((_a = purchaseDoc === null || purchaseDoc === void 0 ? void 0 : purchaseDoc.data()) === null || _a === void 0 ? void 0 : _a.userId) != undefined) {
            const userRef = this.firestore.collection("users").doc((_b = purchaseDoc === null || purchaseDoc === void 0 ? void 0 : purchaseDoc.data()) === null || _b === void 0 ? void 0 : _b.userId);
            if (!["1m"].includes((_c = purchaseDoc === null || purchaseDoc === void 0 ? void 0 : purchaseDoc.data()) === null || _c === void 0 ? void 0 : _c.productId))
                return;
            if (((_d = purchaseDoc === null || purchaseDoc === void 0 ? void 0 : purchaseDoc.data()) === null || _d === void 0 ? void 0 : _d.status) == "ACTIVE") {
                userRef.update({ premium: true });
            }
            else if (((_e = purchaseDoc === null || purchaseDoc === void 0 ? void 0 : purchaseDoc.data()) === null || _e === void 0 ? void 0 : _e.status) == "EXPIRED") {
                userRef.update({ premium: false });
            }
        }
    }
    async expireSubscriptions() {
        const documents = await this.firestore.collection("purchases")
            .where("expiryDate", "<=", Timestamp.now())
            .where("status", "==", "ACTIVE")
            .get();
        if (!documents.size)
            return;
        const writeBatch = this.firestore.batch();
        documents.docs.forEach((doc) => {
            if (["1m"].includes(doc.data().productId)) {
                const userRef = this.firestore.collection("users").doc(doc.data().userId);
                userRef.update({ premium: false });
            }
            writeBatch.update(doc.ref, { status: "EXPIRED" });
        });
        await writeBatch.commit();
    }
}
exports.FirebaseCalls = FirebaseCalls;
//# sourceMappingURL=firebase.calls.js.map