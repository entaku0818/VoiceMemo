import * as admin from "firebase-admin";
import * as https from "https";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {getFirestore} from "firebase-admin/firestore";

admin.initializeApp();

const slackWebhookUrl = defineSecret("SLACK_WEBHOOK_URL");

interface FeedbackData {
  category: string;
  message: string;
  email?: string;
  appVersion: string;
  buildNumber: string;
  osVersion: string;
  deviceModel: string;
}

export const submitFeedback = onCall(
  {
    region: "asia-northeast1",
    secrets: [slackWebhookUrl],
  },
  async (request) => {
    const data = request.data as FeedbackData;

    if (!data.category || !data.message) {
      throw new HttpsError("invalid-argument", "category and message are required");
    }

    // Firestore に保存 (app-data database, asia-northeast1)
    const db = getFirestore("app-data");
    await db.collection("feedbacks").add({
      ...data,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Slack に通知
    const categoryEmoji: Record<string, string> = {
      "バグ報告": "🐛",
      "機能要望": "✨",
      "その他": "💬",
    };

    const emoji = categoryEmoji[data.category] ?? "💬";

    const payload = {
      username: "VoiLog Feedback",
      icon_emoji: ":microphone:",
      text: `${emoji} *VoiLog に新しいフィードバックが届きました*`,
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
            ...(data.email ? [{
              title: "メールアドレス",
              value: data.email,
              short: true,
            }] : []),
            {
              title: "内容",
              value: data.message,
              short: false,
            },
          ],
        },
      ],
    };

    await postToSlack(slackWebhookUrl.value(), payload);

    return {success: true};
  }
);

function postToSlack(webhookUrl: string, payload: object): Promise<void> {
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
      res.on("data", () => {});
      res.on("end", () => resolve());
    });

    req.on("error", reject);
    req.write(body);
    req.end();
  });
}
