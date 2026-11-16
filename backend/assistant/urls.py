from django.urls import path
from .views import (
    HealthCheckView,
    ChatAssistantView,
    GenerateImageView,
    EditImageView,
    CreditsView,
    SessionHistoryView
)

urlpatterns = [
    path('health/', HealthCheckView.as_view(), name='health_check'),
    path('assistant/credits/', CreditsView.as_view(), name='assistant_credits'),
    path('assistant/chat/', ChatAssistantView.as_view(), name='assistant_chat'),
    path('assistant/generate-image/', GenerateImageView.as_view(), name='generate_image'),
    path('assistant/edit-image/', EditImageView.as_view(), name='edit_image'),
    path('assistant/session/<uuid:session_id>/', SessionHistoryView.as_view(), name='session_history'),
]
