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
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppStorePurchaseHandler = void 0;
const purchase_handler_1 = require("./purchase-handler");
const products_1 = require("./products");
const appleReceiptVerify = __importStar(require("node-apple-receipt-verify"));
const constants_1 = require("./constants");
const firebase_admin_1 = require("firebase-admin");
const Functions = __importStar(require("firebase-functions"));
const jwt_decode_1 = require("jwt-decode");
var Timestamp = firebase_admin_1.firestore.Timestamp;
const functions = Functions.region(constants_1.CLOUD_REGION);
class AppStorePurchaseHandler extends purchase_handler_1.PurchaseHandler {
    constructor(firebaseCalls) {
        super();
        this.firebaseCalls = firebaseCalls;
        this.handleServerEvent = functions.https.onRequest(async (req, res) => {
            // console.log("NEW MESSAGE!!!");
            // console.log("REQUEST BODY: " + JSON.stringify(req.body));
            const decodedBody = (0, jwt_decode_1.jwtDecode)(req.body.signedPayload);
            const signedInfo = (0, jwt_decode_1.jwtDecode)(decodedBody.data.signedTransactionInfo);
            const eventData = {
                notificationType: decodedBody.notificationType,
                productId: signedInfo.productId,
                expiresDate: signedInfo.expiresDate,
                originTransactionId: signedInfo.originalTransactionId,
            };
            // console.log("Signed Payload " + JSON.stringify(decodedBody));
            // console.log("Signed Info " + JSON.stringify(signedInfo));
            // console.log("Event data" + JSON.stringify(eventData));
            const productData = products_1.productDataMap[eventData.productId];
            if (!productData) {
                console.log("No matching product data for product: " + eventData.productId);
                res.status(403).send();
                return;
            }
            if (productData.type == "SUBSCRIPTION") {
                try {
                    await this.firebaseCalls.updatePurchase({
                        iapSource: "app_store",
                        orderId: eventData.originTransactionId,
                        expiryDate: Timestamp.fromMillis(parseInt(eventData.expiresDate, 10)),
                        status: Date.now() >= parseInt(eventData.expiresDate, 10) ?
                            "EXPIRED" : "ACTIVE",
                    });
                }
                catch (e) {
                    console.log("Could not update purchase", eventData);
                }
            }
            res.status(200).send();
        });
        appleReceiptVerify.config({
            verbose: true,
            secret: constants_1.APP_STORE_SHARED_SECRET,
            extended: true,
            environment: ["production"],
            excludeOldTransactions: true,
        });
    }
    async handleSubscription(userId, productData, token) {
        return this.handleValidation(userId, token);
    }
    async handleNonSubscription(userId, productData, token) {
        return this.handleValidation(userId, token);
    }
    // eslint-disable-next-line max-len
    async handleValidation(userId, token) {
        var _a, _b;
        let products;
        try {
            products = await appleReceiptVerify.validate({ receipt: token });
        }
        catch (e) {
            if (e instanceof appleReceiptVerify.EmptyError) {
                console.log("Reciept was valid but empty");
                return true;
            }
            else if (e instanceof appleReceiptVerify.ServiceUnavailableError) {
                console.log("App store is currently unavailable");
                return false;
            }
            return false;
        }
        // handle product verification
        for (const product of products) {
            const productData = products_1.productDataMap[product.productId];
            if (!productData)
                continue;
            switch (productData.type) {
                case "SUBSCRIPTION":
                    // handle Subscription
                    await this.firebaseCalls.createOrUpdatePurchase({
                        iapSource: "app_store",
                        orderId: product.originalTransactionId,
                        productId: product.productId,
                        userId: userId,
                        purchaseDate: firebase_admin_1.firestore.Timestamp.fromMillis(product.purchaseDate),
                        type: productData.type,
                        // eslint-disable-next-line max-len
                        expiryDate: firebase_admin_1.firestore.Timestamp.fromMillis((_a = product.expirationDate) !== null && _a !== void 0 ? _a : 0),
                        status: ((_b = product.expirationDate) !== null && _b !== void 0 ? _b : 0) <= Date.now() ? "EXPIRED" : "ACTIVE",
                    });
                    break;
                case "NON_SUBSCRIPTION":
                    // handle non subscription
                    await this.firebaseCalls.createOrUpdatePurchase({
                        iapSource: "app_store",
                        orderId: product.originalTransactionId,
                        productId: product.productId,
                        userId: userId,
                        purchaseDate: firebase_admin_1.firestore.Timestamp.fromMillis(product.purchaseDate),
                        type: productData.type,
                        status: "COMPLETE",
                    });
                    break;
            }
        }
        return true;
    }
}
exports.AppStorePurchaseHandler = AppStorePurchaseHandler;
//# sourceMappingURL=app-store.purchase_handler.js.map