import { GoogleGenAI } from "@google/genai";
import express from "express";

const app = express();

app.get("/health", (_req, res) => res.json({ ok: true }));
app.post("/token", async (_req, res) => {
  if (!process.env.GEMINI_API_KEY) {
    return res.status(500).json({ error: "GEMINI_API_KEY is not configured" });
  }
  try {
    const client = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
    const token = await client.authTokens.create({
      config: {
        uses: 1,
        expireTime: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
        newSessionExpireTime: new Date(Date.now() + 60 * 1000).toISOString(),
        // Ephemeral Live tokens currently require the v1alpha API.
        httpOptions: { apiVersion: "v1alpha" },
      },
    });
    return res.json({ token: token.name });
  } catch (error) {
    console.error("Gemini token creation failed", error);
    return res.status(502).json({ error: "Unable to create Gemini Live token" });
  }
});

app.listen(Number(process.env.PORT || 3000), "0.0.0.0", () => {
  console.log(`Invoice Gemini token server listening on port ${process.env.PORT || 3000}`);
});
