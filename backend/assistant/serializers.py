from rest_framework import serializers
from .models import ConversationSession, ChatMessage, GeneratedImageRecord

class ChatMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChatMessage
        fields = ['id', 'role', 'content', 'action_type', 'action_payload', 'image_url', 'created_at']

class ConversationSessionSerializer(serializers.ModelSerializer):
    messages = ChatMessageSerializer(many=True, read_only=True)

    class Meta:
        model = ConversationSession
        fields = ['id', 'title', 'created_at', 'updated_at', 'messages']

class GeneratedImageRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = GeneratedImageRecord
        fields = ['id', 'prompt', 'image_url', 'image_file', 'created_at']
