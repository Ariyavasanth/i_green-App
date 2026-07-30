import { GoogleGenAI } from "@google/genai";
import cloudinary from "cloudinary";
import express from "express";
import multer from "multer";

const app = express();
const upload = multer({ storage: multer.memoryStorage() });

cloudinary.v2.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
  secure: true,
});

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

app.post("/cloudinary/upload-image", upload.single("file"), async (req, res) => {
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
  const apiKey = process.env.CLOUDINARY_API_KEY;
  const apiSecret = process.env.CLOUDINARY_API_SECRET;

  if (!cloudName || !apiKey || !apiSecret) {
    return res.status(500).json({ error: "Cloudinary environment variables are not configured" });
  }

  if (!req.file) {
    return res.status(400).json({ error: "Missing image file" });
  }

  const folder = req.body.folder || "employee_management/employees/profile";
  const publicIdBase = `${req.body.employeeId || "employee"}_${Date.now()}`;

  try {
    const result = await new Promise((resolve, reject) => {
      const stream = cloudinary.v2.uploader.upload_stream(
        {
          folder,
          public_id: publicIdBase,
          resource_type: "image",
          overwrite: true,
          use_filename: false,
          unique_filename: false,
        },
        (error, uploaded) => {
          if (error) reject(error);
          else resolve(uploaded);
        },
      );
      stream.end(req.file.buffer);
    });

    return res.json({
      secureUrl: result.secure_url,
      publicId: result.public_id,
      folder: result.folder,
    });
  } catch (error) {
    console.error("Cloudinary upload failed", error);
    return res.status(502).json({ error: "Unable to upload image to Cloudinary" });
  }
});

app.listen(Number(process.env.PORT || 3000), "0.0.0.0", () => {
  console.log(`Invoice Gemini token server listening on port ${process.env.PORT || 3000}`);
});
