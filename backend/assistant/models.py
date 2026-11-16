import uuid
from django.db import models
from django.utils import timezone

class ConversationSession(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=255, default='New Conversation')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.title} ({self.id})"

class ChatMessage(models.Model):
    ROLE_CHOICES = [
        ('user', 'User'),
        ('assistant', 'Assistant'),
        ('system', 'System'),
    ]

    session = models.ForeignKey(ConversationSession, related_name='messages', on_delete=models.CASCADE)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)
    content = models.TextField()
    
    # Tool/Action Intent metadata
    action_type = models.CharField(max_length=50, default='none')
    action_payload = models.JSONField(default=dict, blank=True)
    
    # Optional image attachment
    image_url = models.URLField(max_length=1000, blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"[{self.role.upper()}] {self.content[:40]}..."

class GeneratedImageRecord(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    prompt = models.TextField()
    image_url = models.URLField(max_length=1000, blank=True, null=True)
    image_file = models.ImageField(upload_to='generated_images/', blank=True, null=True)
    mode = models.CharField(max_length=50, default='text2img')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Image: {self.prompt[:40]} ({self.created_at})"

class ApiUsageTracker(models.Model):
    date = models.DateField(default=timezone.now, unique=True)
    nvidia_calls = models.IntegerField(default=0)
    image_calls = models.IntegerField(default=0)
    last_called_at = models.DateTimeField(auto_now=True)

    @classmethod
    def record_nvidia_call(cls):
        today = timezone.now().date()
        obj, _ = cls.objects.get_or_create(date=today)
        obj.nvidia_calls += 1
        obj.save(update_fields=['nvidia_calls', 'last_called_at'])
        return obj

    @classmethod
    def record_image_call(cls):
        today = timezone.now().date()
        obj, _ = cls.objects.get_or_create(date=today)
        obj.image_calls += 1
        obj.save(update_fields=['image_calls', 'last_called_at'])
        return obj

    @classmethod
    def get_today_stats(cls):
        today = timezone.now().date()
        obj, _ = cls.objects.get_or_create(date=today)
        remaining = max(0, 1000 - obj.nvidia_calls)
        return {
            "date": str(today),
            "nvidia_used": obj.nvidia_calls,
            "nvidia_limit": 1000,
            "nvidia_remaining": remaining,
            "image_generated_today": obj.image_calls,
            "image_limit": "Unlimited (Free)",
        }

class DeviceProfile(models.Model):
    """Identifies unique client phone/device for cloud backups without login requirements."""
    device_id = models.CharField(max_length=100, unique=True)
    device_name = models.CharField(max_length=200, default='Android Device')
    last_backup_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.device_name} ({self.device_id})"

class SyncedTransaction(models.Model):
    """Cloud backup of an income or expense transaction captured or added on the device."""
    device = models.ForeignKey(DeviceProfile, on_delete=models.CASCADE, related_name='transactions')
    local_id = models.CharField(max_length=100) # Local SQLite ID
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    is_income = models.BooleanField(default=False)
    category = models.CharField(max_length=100, default='General')
    merchant = models.CharField(max_length=200, default='Payment')
    source = models.CharField(max_length=50, default='manual') # 'notification', 'sms', 'screenshot', 'manual', 'ai_assistant'
    transaction_id = models.CharField(max_length=100, blank=True, null=True)
    account_ending = models.CharField(max_length=10, blank=True, null=True)
    date = models.CharField(max_length=20)
    time = models.CharField(max_length=20, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('device', 'local_id')
        ordering = ['-created_at']

    def __str__(self):
        kind = "INCOME" if self.is_income else "EXPENSE"
        return f"[{kind}] ₹{self.amount} - {self.merchant} ({self.device.device_id[:8]})"
