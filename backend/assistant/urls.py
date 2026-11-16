from django.urls import path
from .views import (
    HealthCheckView,
    ChatAssistantView,
    GenerateImageView,
    EditImageView,
    CreditsView,
    SessionHistoryView,
    BackupPushView,
    BackupPullView,
    BackupStatsView
)

urlpatterns = [
    path('health/', HealthCheckView.as_view(), name='health_check'),
    path('assistant/credits/', CreditsView.as_view(), name='assistant_credits'),
    path('assistant/chat/', ChatAssistantView.as_view(), name='assistant_chat'),
    path('assistant/generate-image/', GenerateImageView.as_view(), name='generate_image'),
    path('assistant/edit-image/', EditImageView.as_view(), name='edit_image'),
    path('assistant/session/<uuid:session_id>/', SessionHistoryView.as_view(), name='session_history'),

    # Device Cloud Backup & Sync Endpoints
    path('backup/push/', BackupPushView.as_view(), name='backup_push'),
    path('backup/pull/<str:device_id>/', BackupPullView.as_view(), name='backup_pull'),
    path('backup/stats/<str:device_id>/', BackupStatsView.as_view(), name='backup_stats'),
]
