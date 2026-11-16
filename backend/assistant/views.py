from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.conf import settings
from .models import ConversationSession, ChatMessage
from .serializers import ConversationSessionSerializer, ChatMessageSerializer
from .services.nvidia_llm_service import NvidiaLlmService
from .services.image_gen_service import ImageGenService
from .services.intent_parser import IntentParser

class HealthCheckView(APIView):
    """Verifies that the backend is alive and reports NVIDIA API status."""
    def get(self, request):
        api_key = getattr(settings, 'NVIDIA_API_KEY', '')
        has_key = bool(api_key and not api_key.startswith("nvapi-your-nvidia"))
        return Response({
            "status": "online",
            "service": "LifeSync AI Assistant Backend",
            "nvidia_api_configured": has_key,
            "llm_model": getattr(settings, 'NVIDIA_LLM_MODEL', 'meta/llama-3.3-70b-instruct'),
            "image_model": getattr(settings, 'NVIDIA_IMAGE_MODEL', 'stabilityai/stable-diffusion-3-medium'),
        })

class ChatAssistantView(APIView):
    """
    Primary multi-modal Assistant endpoint.
    Accepts text or transcribed voice messages, queries NVIDIA LLM,
    extracts action intents (reminders, expenses, images), and returns voice-ready responses.
    """
    def post(self, request):
        user_text = request.data.get('message', '').strip()
        if not user_text:
            return Response({"error": "Message content cannot be empty"}, status=status.HTTP_400_BAD_REQUEST)

        session_id = request.data.get('session_id')
        current_time = request.data.get('current_time', '2026-11-16 21:50')

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
        # If action is image generation, generate it immediately!
        if action_type == 'image':
            image_prompt = action_payload.get('prompt', user_text)
            img_result = ImageGenService.generate_image(image_prompt)
            generated_image_url = img_result.get('image_url')

        # Save assistant message
        assistant_msg = ChatMessage.objects.create(
            session=session,
            role='assistant',
            content=clean_reply,
            action_type=action_type,
            action_payload=action_payload,
            image_url=generated_image_url
        )

        return Response({
            "status": "success",
            "session_id": str(session.id),
            "reply": clean_reply,
            "action_type": action_type,
            "action_payload": action_payload,
            "image_url": generated_image_url,
            "message_id": assistant_msg.id
        })

class GenerateImageView(APIView):
    """Standalone image generation endpoint."""
    def post(self, request):
        prompt = request.data.get('prompt', '').strip()
        if not prompt:
            return Response({"error": "Prompt cannot be empty"}, status=status.HTTP_400_BAD_REQUEST)

        result = ImageGenService.generate_image(prompt)
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
