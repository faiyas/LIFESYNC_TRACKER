import base64
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.conf import settings
from .models import ConversationSession, ChatMessage, ApiUsageTracker
from .serializers import ConversationSessionSerializer, ChatMessageSerializer
from .services.nvidia_llm_service import NvidiaLlmService
from .services.image_gen_service import ImageGenService
from .services.intent_parser import IntentParser

class HealthCheckView(APIView):
    """Verifies that the backend is alive, reports NVIDIA API status and remaining daily credits."""
    def get(self, request):
        api_key = getattr(settings, 'NVIDIA_API_KEY', '')
        has_key = bool(api_key and not api_key.startswith("nvapi-your-nvidia"))
        stats = ApiUsageTracker.get_today_stats()
        return Response({
            "status": "online",
            "service": "LifeSync AI Assistant Backend",
            "nvidia_api_configured": has_key,
            "llm_model": getattr(settings, 'NVIDIA_LLM_MODEL', 'nvidia/nemotron-3.5-bolt-e4b'),
            "image_model": "Flux.1 Schnell / SDXL (Unlimited Free)",
            "credits": stats,
        })

class CreditsView(APIView):
    """Returns real-time credit consumption stats for LLM and image generation."""
    def get(self, request):
        stats = ApiUsageTracker.get_today_stats()
        return Response({
            "status": "success",
            "credits": stats
        })

class ChatAssistantView(APIView):
    """
    Primary multi-modal Assistant endpoint.
    Accepts text or voice messages, queries NVIDIA NIM,
    extracts action intents (reminders, expenses, images), and returns voice-ready responses.
    """
    def post(self, request):
        user_text = request.data.get('message', '').strip()
        if not user_text:
            return Response({"error": "Message content cannot be empty"}, status=status.HTTP_400_BAD_REQUEST)

        session_id = request.data.get('session_id')
        current_time = request.data.get('current_time', '2026-11-16 22:50')
        base_url = request.build_absolute_uri('/')

        # Get or create conversation session
        if session_id:
            try:
                session = ConversationSession.objects.get(id=session_id)
            except ConversationSession.DoesNotExist:
                session = ConversationSession.objects.create(title=user_text[:30])
        else:
            session = ConversationSession.objects.create(title=user_text[:30])

        # Save user message
        ChatMessage.objects.create(
            session=session,
            role='user',
            content=user_text
        )

        # Build recent conversation history for LLM context (last 8 messages)
        recent_messages = session.messages.order_by('-created_at')[:8]
        chat_history = []
        for msg in reversed(recent_messages):
            chat_history.append({"role": msg.role, "content": msg.content})

        # Call NVIDIA LLM
        raw_response = NvidiaLlmService.chat(chat_history, current_time_str=current_time)

        # Parse speech text and action intent
        clean_reply, action_type, action_payload = IntentParser.parse_response(raw_response)

        generated_image_url = None
        base64_data = ""

        # If action is image generation, generate it immediately with caching
        if action_type == 'image':
            image_prompt = action_payload.get('prompt', user_text)
            img_result = ImageGenService.generate_image(image_prompt, base_url=base_url)
            generated_image_url = img_result.get('image_url') or img_result.get('direct_url')
            base64_data = img_result.get('base64_data', '')

        # Save assistant message
        assistant_msg = ChatMessage.objects.create(
            session=session,
            role='assistant',
            content=clean_reply,
            action_type=action_type,
            action_payload=action_payload,
            image_url=generated_image_url
        )

        # Include updated credit balance in every response
        stats = ApiUsageTracker.get_today_stats()

        return Response({
            "status": "success",
            "session_id": str(session.id),
            "reply": clean_reply,
            "action_type": action_type,
            "action_payload": action_payload,
            "image_url": generated_image_url,
            "base64_data": base64_data,
            "message_id": assistant_msg.id,
            "credits": stats
        })

class GenerateImageView(APIView):
    """Standalone image generation endpoint with pre-download."""
    def post(self, request):
        prompt = request.data.get('prompt', '').strip()
        if not prompt:
            return Response({"error": "Prompt cannot be empty"}, status=status.HTTP_400_BAD_REQUEST)

        base_url = request.build_absolute_uri('/')
        result = ImageGenService.generate_image(prompt, base_url=base_url)
        return Response(result)

class EditImageView(APIView):
    """
    Reference Image / Editing Endpoint:
    - mode="rembg": Removes background, returns transparent PNG
    - mode="edit" or "blend": Modifies/Adds to reference image with prompt (e.g. 'Add a person', 'Make anime')
    """
    def post(self, request):
        image_b64 = request.data.get('image', '')
        instruction = request.data.get('prompt', '').strip()
        mode = request.data.get('mode', 'edit') # 'rembg', 'edit', 'blend'
        base_url = request.build_absolute_uri('/')

        if not image_b64:
            # Check if uploaded as multipart file
            if 'file' in request.FILES:
                image_bytes = request.FILES['file'].read()
            else:
                return Response({"error": "No reference image provided"}, status=status.HTTP_400_BAD_REQUEST)
        else:
            # Decode base64 string
            if ',' in image_b64:
                image_b64 = image_b64.split(',', 1)[1]
            try:
                image_bytes = base64.b64decode(image_b64)
            except Exception as e:
                return Response({"error": f"Invalid base64 image: {e}"}, status=status.HTTP_400_BAD_REQUEST)

        if mode == 'rembg':
            result = ImageGenService.remove_background(image_bytes, base_url=base_url)
        else:
            if not instruction:
                instruction = "Enhance this photo, highly detailed, photorealistic 8k"
            result = ImageGenService.edit_with_reference(image_bytes, instruction, base_url=base_url)

        stats = ApiUsageTracker.get_today_stats()
        result['credits'] = stats
        return Response(result)

class SessionHistoryView(APIView):
    """Retrieve full history for a conversation session."""
    def get(self, request, session_id):
        try:
            session = ConversationSession.objects.get(id=session_id)
            serializer = ConversationSessionSerializer(session)
            return Response(serializer.data)
        except ConversationSession.DoesNotExist:
            return Response({"error": "Session not found"}, status=status.HTTP_404_NOT_FOUND)
