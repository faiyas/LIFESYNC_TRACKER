import re
import json

class IntentParser:
    @classmethod
    def parse_response(cls, raw_text: str) -> tuple[str, str, dict]:
        """
        Parses raw text from the LLM.
        Returns:
            (clean_speech_text, action_type, action_payload)
        """
        if not raw_text:
            return ("", "none", {})

        action_type = "none"
        action_payload = {}
        clean_text = raw_text

        # Match <ACTION>...</ACTION> blocks
        action_match = re.search(r'<ACTION>\s*(\{.*?\})\s*</ACTION>', raw_text, re.DOTALL)
        if action_match:
            json_str = action_match.group(1)
            try:
                parsed = json.loads(json_str)
                action_type = parsed.get("action", "none")
                action_payload = parsed.get("data", {})
            except Exception:
                pass
            
            # Remove the <ACTION> block from spoken text
            clean_text = re.sub(r'<ACTION>.*?</ACTION>', '', raw_text, flags=re.DOTALL).strip()

        # Clean any remaining JSON or markdown markers so speech reads smoothly
        clean_text = clean_text.replace("```json", "").replace("```", "").strip()

        return (clean_text, action_type, action_payload)
