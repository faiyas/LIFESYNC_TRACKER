# LIFESYNC_TRACKER 🚀

A comprehensive personal life tracker & AI assistant mobile app built with **Flutter**, backed by an automated **Django + NVIDIA NIM API** cloud backend.

---

## 🌟 Key Features

### 1. 🤖 LifeSync AI Voice Assistant (Powered by NVIDIA NIM)
- **100% Free LLM**: Powered by Meta Llama 3.3 70B Instruct via NVIDIA NIM.
- **Voice Text-to-Speech**: Conversational voice responses directly in the app.
- **Auto Action Execution**:
  - Automatically schedules device push reminders & alarms.
  - Automatically logs expenses and incomes into the local SQLite database.
- **AI Image Generation**: Generates high-quality AI images on demand (FLUX / SDXL + Pollinations.ai free fallback).

### 2. ⚡ Automated Payment Tracking (UPI, SMS & Screenshot Fallback)
- **Zero-Manual Entry**: Auto-detects UPI app transaction notifications (GPay, PhonePe, Paytm, CRED).
- **Background SMS Listener**: Parses banking debit/credit SMS messages.
- **Screenshot Auto-Watcher**: Ingests payment confirmation screenshots from your gallery.
- **Multi-Dimensional Deduplication**: Deduplicates by Transaction Reference ID, Account last 4 digits, Merchant/Sender, Amount, and Time proximity.
- **Strict Table Isolation**: Debited transactions ➔ `expenses`, Credited transactions ➔ `income`.

### 3. ☁️ Django Backend on Instabox (Zero Cost Cloud Setup)
- Located in `backend/`
- One-click deploy script `deploy.sh` installs dependencies and automatically sets up a **Cloudflare Public Tunnel** (`trycloudflare.com`).
- Zero domain cost, zero static IP needed.

---

## 📁 Repository Structure

```text
├── backend/                  # Django REST API Backend (NVIDIA NIM, Image Gen, Actions)
│   ├── assistant/            # Assistant app (LLM services, models, intent parser)
│   ├── core/                 # Django core settings & routing
│   ├── deploy.sh             # 1-click Instabox deployment script
│   └── requirements.txt
├── lib/                      # Flutter Mobile Application
│   ├── features/
│   │   ├── ai_assistant/     # AI Voice Assistant UI & Action Executor
│   │   └── payment_scanner/  # Payment parser, deduplication & listeners
│   ├── database/             # Drift / SQLite offline-first database
│   ├── screens/              # Dashboard, Expenses, Income, Habits, Navigation
│   └── services/             # Notifications, scheduling, TTS
└── android/                  # Native Android Kotlin services & receivers
```

---

## 🚀 Quick Start

### 1. Deploy Backend to Instabox
```bash
cd backend
nano .env   # Add your free NVIDIA API Key: NVIDIA_API_KEY=nvapi-...
chmod +x deploy.sh
./deploy.sh
```
Copy the generated Cloudflare URL (`https://....trycloudflare.com`).

### 2. Run Flutter App
```bash
flutter pub get
flutter run
```
Go to **Settings ➔ AI Voice Assistant (NVIDIA NIM)** and paste your backend Cloudflare URL.
