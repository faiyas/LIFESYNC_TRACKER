#!/bin/bash
# ==============================================================================
# LifeSync AI Assistant - 1-Click Instabox / Linux Server Setup & Deployment
# Runs 100% FREE on Instabox VM with Cloudflare Tunnel (HTTPS)
# ==============================================================================

set -e

echo "=========================================="
echo "🚀 Setting up LifeSync AI Assistant Backend"
echo "=========================================="

# 1. Update system packages and ensure python3-venv is present
if command -v apt-get >/dev/null 2>&1; then
    echo "📦 Checking system dependencies..."
    sudo apt-get update -y && sudo apt-get install -y python3-venv python3-pip curl wget
fi

# 2. Setup Virtual Environment
cd "$(dirname "$0")"
if [ ! -d "venv" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv venv
fi

echo "⚡ Activating virtual environment..."
source venv/bin/activate

# 3. Install Python requirements
echo "📥 Installing python packages..."
pip install --upgrade pip
pip install -r requirements.txt

# 4. Run migrations
echo "🗄️ Running database migrations..."
python manage.py makemigrations assistant
python manage.py migrate

# 5. Check if Cloudflared is installed (for 100% Free Public HTTPS URL)
if ! command -v cloudflared >/dev/null 2>&1; then
    echo "🌐 Installing Cloudflared tunnel client..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        sudo dpkg -i cloudflared.deb || true
        rm -f cloudflared.deb
    elif [ "$ARCH" = "aarch64" ]; then
        curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
        sudo dpkg -i cloudflared.deb || true
        rm -f cloudflared.deb
    fi
fi

# 6. Stop any previous instances
echo "🔄 Clearing old processes..."
pkill -f "manage.py runserver" || true
pkill -f "cloudflared tunnel" || true

# 7. Start Django Server
echo "🚀 Starting Django server on 0.0.0.0:8000..."
nohup python manage.py runserver 0.0.0.0:8000 > django.log 2>&1 &
sleep 2

# Verify server running
if curl -s http://127.0.0.1:8000/api/health/ > /dev/null; then
    echo "✅ Django backend is running successfully!"
else
    echo "⚠️ Warning: Django server might still be starting, check django.log"
fi

# 8. Start Cloudflare Tunnel for free HTTPS URL
echo "🌐 Starting Cloudflare Public Tunnel..."
nohup cloudflared tunnel --url http://127.0.0.1:8000 > cloudflared.log 2>&1 &
sleep 4

echo "==========================================================="
echo "🎉 DEPLOYMENT COMPLETE!"
echo ""
echo "Your public HTTPS URL will appear below from Cloudflare:"
grep -o 'https://[-a-zA-Z0-9@:%._\+~#=]*\.trycloudflare.com' cloudflared.log | tail -n 1 || echo "Check cloudflared.log with: cat cloudflared.log"
echo ""
echo "👉 Copy that https://....trycloudflare.com URL and paste it into"
echo "   your LifeSync Tracker App Settings -> AI Assistant URL!"
echo "==========================================================="
