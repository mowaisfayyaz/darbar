# pyrefly: ignore [missing-import]
from django.db import models
# pyrefly: ignore [missing-import]
from django.utils import timezone
import uuid

class User(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    email = models.EmailField(unique=True, blank=True, null=True)
    phone = models.CharField(max_length=50, unique=True)
    password = models.CharField(max_length=255)
    location = models.CharField(max_length=255, blank=True, null=True)
    google_email = models.EmailField(blank=True, null=True, unique=True)
    is_google_linked = models.BooleanField(default=False)
    is_apify_enabled = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return self.name

class Provider(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    business_name = models.CharField(max_length=255)
    email = models.EmailField(unique=True, blank=True, null=True)
    phone = models.CharField(max_length=50)
    password = models.CharField(max_length=255)
    website = models.URLField(blank=True, null=True)
    rating = models.FloatField(default=0.0)
    review_count = models.IntegerField(default=0)
    category = models.CharField(max_length=100)
    price_indicator = models.CharField(max_length=10, blank=True, null=True)

    city = models.CharField(max_length=100)
    area = models.CharField(max_length=100)
    lat = models.FloatField(blank=True, null=True)
    lng = models.FloatField(blank=True, null=True)

    is_available = models.BooleanField(default=True)
    device_token = models.CharField(max_length=255, blank=True, null=True)
    google_email = models.EmailField(blank=True, null=True, unique=True)
    is_google_linked = models.BooleanField(default=False)
    is_apify_enabled = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)

    profile_photo = models.CharField(max_length=500, blank=True, default='')
    years_of_experience = models.IntegerField(default=0)

    # Added for Apify Integration
    place_id = models.CharField(max_length=255, blank=True, null=True, unique=True)
    address = models.TextField(blank=True, null=True)
    google_maps_url = models.URLField(max_length=500, blank=True, null=True)

    def __str__(self):
        return f"{self.business_name} ({self.category})"




class Booking(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    booking_id = models.CharField(max_length=50, unique=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='bookings')
    provider = models.ForeignKey(Provider, on_delete=models.SET_NULL, null=True, related_name='bookings')
    service_type = models.CharField(max_length=100)
    location = models.CharField(max_length=255)
    scheduled_time = models.DateTimeField(blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return self.booking_id

class BookingAttempt(models.Model):
    STATUS_CHOICES = (
        ('sent', 'Sent'),
        ('accepted', 'Accepted'),
        ('timeout', 'Timeout'),
        ('declined', 'Declined'),
    )
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    booking = models.ForeignKey(Booking, on_delete=models.CASCADE, related_name='attempts')
    provider = models.ForeignKey(Provider, on_delete=models.CASCADE)
    sent_at = models.DateTimeField(default=timezone.now)
    responded_at = models.DateTimeField(blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='sent')
    failure_reason = models.TextField(blank=True, null=True)

class AgentLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    booking = models.ForeignKey(Booking, on_delete=models.CASCADE, related_name='agent_logs', blank=True, null=True)
    agent_name = models.CharField(max_length=100)
    action_taken = models.CharField(max_length=255)
    reasoning = models.TextField()
    timestamp = models.DateTimeField(default=timezone.now)

class Reminder(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('sent', 'Sent'),
    )
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    booking = models.ForeignKey(Booking, on_delete=models.CASCADE, related_name='reminders')
    remind_at = models.DateTimeField()
    type = models.CharField(max_length=50)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')

class Notification(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications', blank=True, null=True)
    provider = models.ForeignKey(Provider, on_delete=models.CASCADE, related_name='notifications', blank=True, null=True)
    title = models.CharField(max_length=255)
    body = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)

class SystemSetting(models.Model):
    key = models.CharField(max_length=100, unique=True)
    value = models.TextField()

    def __str__(self):
        return f"{self.key}: {self.value}"


class ServiceGig(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider = models.ForeignKey(Provider, on_delete=models.CASCADE, related_name='gigs')
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    photos = models.JSONField(default=list, blank=True)  # List of URLs
    price_min = models.IntegerField(default=0)
    price_max = models.IntegerField(default=0)
    estimated_time = models.CharField(max_length=100, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"{self.title} - {self.provider.business_name}"


class DiscountBanner(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider = models.ForeignKey(Provider, on_delete=models.CASCADE, related_name='discounts')
    title = models.CharField(max_length=255)
    discount_percent = models.IntegerField(default=0)
    valid_until = models.DateField()
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.discount_percent}% off - {self.provider.business_name}"


class ProviderExperience(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider = models.ForeignKey(Provider, on_delete=models.CASCADE, related_name='experience')
    years_of_experience = models.IntegerField(default=0)
    past_workplaces = models.JSONField(default=list, blank=True)  # List of strings/dicts
    certifications = models.TextField(blank=True)
    cert_image = models.CharField(max_length=500, blank=True, default='')

    def __str__(self):
        return f"Experience for {self.provider.business_name}"


class Review(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    booking = models.OneToOneField(Booking, on_delete=models.CASCADE, related_name='review')
    provider = models.ForeignKey(Provider, on_delete=models.CASCADE, related_name='reviews')
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    rating = models.IntegerField(default=5)  # 1-5
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"Review ({self.rating}) by {self.user.name} for {self.provider.business_name}"
