"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PurchaseHandler = void 0;
class PurchaseHandler {
    async verifyPurchase(userId, productData, token) {
        if (productData.type == "SUBSCRIPTION") {
            return this.handleSubscription(userId, productData, token);
        }
        else if (productData.type == "NON_SUBSCRIPTION") {
            return this.handleNonSubscription(userId, productData, token);
        }
        else {
            return false;
        }
    }
}
exports.PurchaseHandler = PurchaseHandler;
//# sourceMappingURL=purchase-handler.js.map