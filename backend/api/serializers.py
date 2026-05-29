from rest_framework import serializers
from .models import User, Provider, Booking, BookingAttempt, AgentLog, Reminder, ServiceGig, DiscountBanner, ProviderExperience, Review

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = '__all__'

class ProviderSerializer(serializers.ModelSerializer):
    class Meta:
        model = Provider
        fields = '__all__'

class ServiceGigSerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceGig
        fields = '__all__'

class DiscountBannerSerializer(serializers.ModelSerializer):
    class Meta:
        model = DiscountBanner
        fields = '__all__'

class ProviderExperienceSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProviderExperience
        fields = '__all__'

class ReviewSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.name', read_only=True)
    class Meta:
        model = Review
        fields = '__all__'

class AgentLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AgentLog
        fields = '__all__'

class BookingAttemptSerializer(serializers.ModelSerializer):
    provider = ProviderSerializer(read_only=True)
    class Meta:
        model = BookingAttempt
        fields = '__all__'

class BookingSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    provider = ProviderSerializer(read_only=True)
    agent_logs = AgentLogSerializer(many=True, read_only=True)
    attempts = BookingAttemptSerializer(many=True, read_only=True)
    review = ReviewSerializer(read_only=True)
    
    class Meta:
        model = Booking
        fields = '__all__'
