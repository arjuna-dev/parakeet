"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.GooglePlayPurchaseHandler = void 0;
const purchase_handler_1 = require("./purchase-handler");
const googleapis_1 = require("googleapis");
const google_auth_library_1 = require("google-auth-library");
const firebase_admin_1 = require("firebase-admin");
const service_account_json_1 = __importDefault(require("../lib/assets/service-account.json"));
const constants_1 = require("./constants");
const products_1 = require("./products");
const Functions = __importStar(require("firebase-functions"));
const functions = Functions.region(constants_1.CLOUD_REGION);
class GooglePlayPurchaseHandler extends purchase_handler_1.PurchaseHandler {
    constructor(firebaseCalls) {
        super();
        this.firebaseCalls = firebaseCalls;
        this.handleServerEvent = functions.pubsub.topic(constants_1.GOOGLE_PLAY_PUBSUB_TOPIC)
            .onPublish(async (message) => {
            let event;
            try {
                event = JSON.parse(Buffer.from(message.data, "base64").toString("ascii"));
            }
            catch (e) {
                console.error("Could not parse Google Play billing event", e);
                return;
            }
            // if (event.testNotification) return;
            const { purchaseToken, subscriptionId, sku } = Object.assign(Object.assign({}, event.subscriptionNotification), event.oneTimeProductNotification);
            const productData = products_1.productDataMap[subscriptionId !== null && subscriptionId !== void 0 ? subscriptionId : sku];
            if (!productData)
                return;
            const notificationType = subscriptionId ? "SUBSCRIPTION" : sku ? "NON_SUBSCRIPTION" : null;
            if (productData.type !== notificationType)
                return;
            switch (notificationType) {
                case "SUBSCRIPTION":
                    await this.handleSubscription(null, productData, purchaseToken);
                    break;
                case "NON_SUBSCRIPTION":
                    await this.handleNonSubscription(null, productData, purchaseToken);
                    break;
            }
        });
        this.androidPublisher = new googleapis_1.androidpublisher_v3.Androidpublisher({
            auth: new google_auth_library_1.GoogleAuth({
                credentials: service_account_json_1.default,
                scopes: ["https://www.googleapis.com/auth/androidpublisher"],
            }),
        });
    }
    async handleSubscription(userId, productData, token) {
        var _a, _b, _c;
        try {
            const response = await this.androidPublisher.purchases.subscriptions.get({
                packageName: constants_1.ANDROID_PACKAGE_ID,
                subscriptionId: productData.productId,
                token,
            });
            if (!response.data.orderId) {
                console.error("Could not handle purchase without order id");
                return false;
            }
            // Update order id if necessary
            let orderId = response.data.orderId;
            const orderIdMatch = /^(.+)?[.]{2}[0-9]+$/g.exec(orderId);
            if (orderIdMatch) {
                orderId = orderIdMatch[1];
            }
            const purchaseData = {
                iapSource: "google_play",
                orderId: orderId,
                productId: productData.productId,
                purchaseDate: firebase_admin_1.firestore.Timestamp.fromMillis(parseInt((_a = response.data.startTimeMillis) !== null && _a !== void 0 ? _a : "0", 10)),
                type: "SUBSCRIPTION",
                expiryDate: firebase_admin_1.firestore.Timestamp.fromMillis(parseInt((_b = response.data.expiryTimeMillis) !== null && _b !== void 0 ? _b : "0", 10)),
                status: [
                    "PENDING",
                    "ACTIVE",
                    "ACTIVE",
                    "PENDING",
                    "EXPIRED",
                ][(_c = response.data.paymentState) !== null && _c !== void 0 ? _c : 4],
            };
            if (userId) {
                await this.firebaseCalls.createOrUpdatePurchase(Object.assign(Object.assign({}, purchaseData), { userId }));
            }
            else {
                await this.firebaseCalls.updatePurchase(purchaseData);
            }
            return true;
        }
        catch (e) {
            console.log("could not verify the purchase because of error", e);
            return false;
        }
    }
    async handleNonSubscription(userId, productData, token) {
        var _a, _b;
        try {
            const response = await this.androidPublisher.purchases.products.get({
                packageName: constants_1.ANDROID_PACKAGE_ID,
                productId: productData.productId,
                token,
            });
            if (!response.data.orderId) {
                console.error("Could not handle purchase without order id");
                return false;
            }
            const purchaseData = {
                iapSource: "google_play",
                orderId: response.data.orderId,
                productId: productData.productId,
                purchaseDate: firebase_admin_1.firestore.Timestamp.fromMillis(parseInt((_a = response.data.purchaseTimeMillis) !== null && _a !== void 0 ? _a : "0", 10)),
                type: "NON_SUBSCRIPTION",
                status: [
                    "COMPLETE",
                    "CANCELED",
                    "PENDING",
                ][(_b = response.data.purchaseState) !== null && _b !== void 0 ? _b : 0],
            };
            if (userId) {
                await this.firebaseCalls.createOrUpdatePurchase(Object.assign(Object.assign({}, purchaseData), { userId }));
            }
            else {
                await this.firebaseCalls.updatePurchase(purchaseData);
            }
            return true;
        }
        catch (e) {
            console.log("could not verify the purchase because of error", e);
            return false;
        }
    }
}
exports.GooglePlayPurchaseHandler = GooglePlayPurchaseHandler;
//# sourceMappingURL=google-play.purchase_handler.js.map