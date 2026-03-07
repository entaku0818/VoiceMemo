import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as https from "https";

admin.initializeApp();

const SLACK_WEBHOOK_URL = functions.config().slack.webhook_url;

interface FeedbackData {
  category: string;
  message: string;
  appVersion: string;
  buildNumber: string;
  osVersion: string;
  deviceModel: string;
  createdAt: admin.firestore.Timestamp;
}

export const onFeedbackCreated = functions
  .region("asia-northeast1")
  .firestore.document("feedbacks/{feedbackId}")
  .onCreate(async (snap) => {
    const data = snap.data() as FeedbackData;

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
