"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onFeedbackCreated = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const https = require("https");
admin.initializeApp();
const SLACK_WEBHOOK_URL = functions.config().slack.webhook_url;
exports.onFeedbackCreated = functions
    .region("asia-northeast1")
    .firestore.document("feedbacks/{feedbackId}")
    .onCreate(async (snap) => {
    var _a;
    const data = snap.data();
    const categoryEmoji = {
        "バグ報告": "🐛",
        "機能要望": "✨",
        "その他": "💬",
    };
    const emoji = (_a = categoryEmoji[data.category]) !== null && _a !== void 0 ? _a : "💬";
    const payload = {
        text: `${emoji} *新しいフィードバックが届きました*`,
        attachments: [
            {
                color: data.category === "バグ報告" ? "#e74c3c" : "#2ecc71",
                fields: [
                    {
                        title: "カテゴリ",
                        value: data.category,
                        short: true,
                    },
                    {
                        title: "バージョン",
                        value: `${data.appVersion} (${data.buildNumber})`,
                        short: true,
                    },
                    {
                        title: "デバイス",
                        value: `${data.deviceModel} / iOS ${data.osVersion}`,
                        short: true,
                    },
                    {
                        title: "内容",
                        value: data.message,
                        short: false,
                    },
                ],
            },
        ],
    };
    await postToSlack(SLACK_WEBHOOK_URL, payload);
});
function postToSlack(webhookUrl, payload) {
    return new Promise((resolve, reject) => {
        const body = JSON.stringify(payload);
        const url = new URL(webhookUrl);
        const options = {
            hostname: url.hostname,
            path: url.pathname,
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Content-Length": Buffer.byteLength(body),
            },
        };
        const req = https.request(options, (res) => {
            res.on("data", () => { });
            res.on("end", () => resolve());
        });
        req.on("error", reject);
        req.write(body);
        req.end();
    });
}
//# sourceMappingURL=index.js.map