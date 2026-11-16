from django.urls import path
from .views import HealthCheckView, ChatAssistantView, GenerateImageView, SessionHistoryView

urlpatterns = [
    path('health/', HealthCheckView.as_view(), name='health_check'),
    path('assistant/chat/', ChatAssistantView.as_view(), name='assistant_chat'),
    path('assistant/generate-image/', GenerateImageView.as_view(), name='generate_image'),
    path('assistant/session/<uuid:session_id>/', SessionHistoryView.as_view(), name='session_history'),
]
