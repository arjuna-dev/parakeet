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
exports.expireSubscriptions = exports.handlePlayStoreServerEvent = exports.handleAppStoreServerEvent = exports.verifyPurchase = void 0;
const Functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const firebase_calls_1 = require("./firebase.calls");
const constants_1 = require("./constants");
const app_store_purchase_handler_1 = require("./app-store.purchase_handler");
const google_play_purchase_handler_1 = require("./google-play.purchase_handler");
const products_1 = require("./products");
const https_1 = require("firebase-functions/v1/https");
admin.initializeApp();
const functions = Functions.region(constants_1.CLOUD_REGION);
const firebaseCalls = new firebase_calls_1.FirebaseCalls(admin.firestore());
const purchaseHandlers = {
    "google_play": new google_play_purchase_handler_1.GooglePlayPurchaseHandler(firebaseCalls),
    "app_store": new app_store_purchase_handler_1.AppStorePurchaseHandler(firebaseCalls),
};
exports.verifyPurchase = functions.https.onCall(async (data, context) => {
    var _a;
    // check for auth
    if (!context.auth) {
        console.warn("verifyPurchase was called no authentication");
        throw new https_1.HttpsError("unauthenticated", "Request was not authenticated.");
    }
    const productData = products_1.productDataMap[data.productId];
    // product data was unknown
    if (!productData) {
        console.warn(`verifyPurchase was called for an unknown product ("${data.productId}")`);
        return false;
    }
    // called from unknown source
    if (!purchaseHandlers[data.source]) {
        console.warn(`verifyPurchase called for an unknown source ("${data.source}")`);
        return false;
    }
    // validate the purchase
    return purchaseHandlers[data.source].verifyPurchase((_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid, productData, data.verificationData);
});
exports.handleAppStoreServerEvent = purchaseHandlers.app_store.handleServerEvent;
exports.handlePlayStoreServerEvent = purchaseHandlers.google_play
    .handleServerEvent;
exports.expireSubscriptions = functions.pubsub.schedule("0 0 * * *")
    .timeZone("Europe/Berlin")
    .onRun(() => firebaseCalls.expireSubscriptions());
//# sourceMappingURL=index.js.map