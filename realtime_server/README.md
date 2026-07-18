# Invoice Gemini Live token server

The permanent Gemini API key stays in this Node server. Flutter receives only a one-use temporary token.

```powershell
cd realtime_server
npm install
$env:GEMINI_API_KEY='YOUR_GEMINI_API_KEY'
npm start
```

The Android emulator uses `http://10.0.2.2:3000/token`. For the physical phone, run Flutter with a reachable HTTPS server URL:

```powershell
flutter run --dart-define=INVOICE_GEMINI_TOKEN_URL=https://YOUR_SERVER/token
```
