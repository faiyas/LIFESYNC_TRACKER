# LifeSync AI Assistant - Backend (Django + NVIDIA NIM API)

100% Free AI Assistant Backend providing:
- **LLM Conversations**: Llama 3.3 70B via NVIDIA NIM API (Free 1,000 requests/day).
- **Image Generation**: NVIDIA SDXL / FLUX + Pollinations.ai 100% free fallback.
- **Voice-Ready Outputs**: Direct conversational text output for mobile text-to-speech.
- **Action Intent Parser**: Automatically extracts reminders, expenses, and incomes for Flutter to execute.
- **Cloudflare Tunnel**: Free public HTTPS URL without needing a domain or public IP.

---

## 🚀 How to Run on Instabox (in 3 Commands)

Open your Instabox terminal (`user@instabox-machinefaiyas:~$`) and run:

### Step 1: Clone or Copy backend folder into Instabox
If using git:
```bash
git clone <your-repo-url>
cd tracker/flutter/backend
```
Or simply upload/copy the `backend` folder to `~/backend` and run:
```bash
cd ~/backend
```

### Step 2: Configure your NVIDIA API Key
Edit `.env` (or run):
```bash
nano .env
```
Paste your NVIDIA NIM API key:
```env
NVIDIA_API_KEY=nvapi-your-key-here
```
*(Get a free key instantly at https://build.nvidia.com - click 'Get API Key')*

### Step 3: Run the Auto-Deploy Script
```bash
chmod +x deploy.sh
./deploy.sh
```

The script will automatically install dependencies, run migrations, start Django on port 8000, and launch a Cloudflare Tunnel.

At the end of the output, you will see a public URL like:
```text
https://random-words.trycloudflare.com
```

Copy this URL and paste it into the LifeSync Tracker mobile app under **Settings ➔ AI Assistant Backend URL**!

---

## 🛠️ API Endpoints

- **GET `/api/health/`** - Backend health & NVIDIA key status check.
- **POST `/api/assistant/chat/`** - Main chat endpoint.
  - Body: `{"message": "Remind me to buy groceries tomorrow 10am", "session_id": "optional-uuid"}`
  - Response:
    ```json
    {
      "status": "success",
      "reply": "I have set a reminder for groceries tomorrow at 10:00 AM.",
      "action_type": "reminder",
      "action_payload": {
        "title": "Buy groceries",
        "time": "2026-11-17 10:00:00"
      }
    }
    ```
- **POST `/api/assistant/generate-image/`** - Dedicated image generator.
  - Body: `{"prompt": "A futuristic city in watercolor style"}`
  - Response: `{"status": "success", "image_url": "https://..."}`
