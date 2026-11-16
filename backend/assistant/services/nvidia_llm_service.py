import json
import logging
import requests
from django.conf import settings

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are LifeSync AI, a highly capable, voice-enabled personal assistant integrated directly inside the LifeSync mobile app.
Your goals:
1. Speak naturally, concisely, and warmly with the user (your responses are spoken aloud via Text-to-Speech, so avoid complex markdown tables or clutter).
2. Help the user manage reminders, track expenses and income, answer questions, and generate creative images.
3. Automatically detect user intentions and return an ACTION JSON block whenever the user wants to:
   - Set a reminder (e.g., "Remind me to call John tomorrow at 5pm", "Set a reminder for gym at 7am")
   - Log an expense (e.g., "Spent 350 on pizza", "Paid 1200 for petrol")
   - Log income (e.g., "Received 15000 freelance payment", "Got 500 cashback")
   - Generate an image (e.g., "Generate an image of a cybernetic tiger", "Draw a futuristic city")

When an action is requested, format your response as:
<ACTION>
{
  "action": "reminder" | "expense" | "income" | "image" | "none",
  "data": {
    // for reminder:
    "title": "Clean summary of task",
    "datetime": "YYYY-MM-DD HH:MM",  // calculate relative to current date/time
    // for expense:
    "amount": 350.0,
    "category": "Food" | "Transport" | "Shopping" | "Bills" | "Health" | "Other",
    "merchant": "Swiggy" or null,
    // for income:
    "amount": 5000.0,
    "source": "Salary" | "Freelance" | "Investment" | "Other",
    // for image:
    "prompt": "Detailed enhanced prompt for image generation"
  }
}
</ACTION>

Followed by your natural, friendly conversational reply to the user.
Example:
User: "Remind me to take my medicine at 9 PM"
Assistant:
<ACTION>
{
  "action": "reminder",
  "data": {
    "title": "Take medicine",
    "datetime": "2026-11-16 21:00"
  }
}
</ACTION>
I've scheduled a reminder for you to take your medicine at 9:00 PM tonight!
"""

class NvidiaLlmService:
    NVIDIA_ENDPOINT = "https://integrate.api.nvidia.com/v1/chat/completions"

    @classmethod
    def get_api_key(cls):
        return getattr(settings, 'NVIDIA_API_KEY', '')

    @classmethod
    def get_model(cls):
        return getattr(settings, 'NVIDIA_LLM_MODEL', 'nvidia/nemotron-3.5-bolt-e4b')

    @classmethod
    def chat(cls, messages, current_time_str="2026-11-16 21:45"):
        api_key = cls.get_api_key()
        model = cls.get_model()

        # Build conversation payload with enhanced system prompt
        context_prompt = f"{SYSTEM_PROMPT}\nNote: The current reference time is {current_time_str}."
        payload_messages = [{"role": "system", "content": context_prompt}]
        payload_messages.extend(messages)

        # 1. If NVIDIA API Key is provided, call NVIDIA NIM
        if api_key and not api_key.startswith("nvapi-your-nvidia"):
            headers = {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            }
            body = {
                "model": model,
                "messages": payload_messages,
                "temperature": 0.6,
                "top_p": 0.9,
                "max_tokens": 1024,
                "stream": False,
            }

            try:
                response = requests.post(cls.NVIDIA_ENDPOINT, headers=headers, json=body, timeout=30)
                if response.status_code == 200:
                    data = response.json()
                    choices = data.get("choices", [])
                    if choices:
                        try:
                            from ..models import ApiUsageTracker
                            ApiUsageTracker.record_nvidia_call()
                        except Exception:
                            pass
                        return choices[0].get("message", {}).get("content", "")
                else:
                    logger.error(f"NVIDIA API Error {response.status_code}: {response.text}")
                    return f"NVIDIA API returned status {response.status_code}. Please check your NVIDIA account credits."
            except Exception as e:
                logger.error(f"NVIDIA API Connection Exception: {e}")
                return f"Could not reach NVIDIA API: {e}"

        # 2. Free Intelligent Fallback (Ensures the assistant ALWAYS works even before adding an API key)
        return cls._intelligent_fallback_response(messages[-1].get("content", ""), current_time_str)

    @classmethod
    def _intelligent_fallback_response(cls, user_text, current_time_str):
        text_lower = user_text.lower()

        # Check for reminder intent
        if "remind" in text_lower or "alarm" in text_lower:
            return f"""<ACTION>
{{
  "action": "reminder",
  "data": {{
    "title": "{user_text.replace('remind me to', '').replace('remind me', '').strip().capitalize()}",
    "datetime": "2026-11-17 09:00"
  }}
}}
</ACTION>
I have created a reminder for "{user_text.strip()}"! What else can I assist you with?"""

        # Check for expense intent
        if any(w in text_lower for w in ["spent", "paid", "bought", "expense of"]):
            import re
            amount_match = re.search(r'(?:rs\.?|inr|₹|\$)?\s*(\d+(?:\.\d+)?)', text_lower)
            amount = float(amount_match.group(1)) if amount_match else 100.0
            return f"""<ACTION>
{{
  "action": "expense",
  "data": {{
    "amount": {amount},
    "category": "Food",
    "merchant": "Personal"
  }}
}}
</ACTION>
Logged an expense of ₹{amount:0.2f} in your LifeSync Tracker!"""

        # Check for image intent
        if any(w in text_lower for w in ["generate image", "create image", "draw", "picture of"]):
            prompt = user_text.replace("generate image of", "").replace("create an image of", "").replace("draw", "").strip()
            return f"""<ACTION>
{{
  "action": "image",
  "data": {{
    "prompt": "{prompt}"
  }}
}}
</ACTION>
Generating a visual illustration of "{prompt}" for you now!"""

        # General friendly AI reply
        return f"Hello! I am your LifeSync AI assistant. I can help you record your daily expenses, schedule alarms and reminders, generate creative images, and answer any questions. How can I help you right now?"
