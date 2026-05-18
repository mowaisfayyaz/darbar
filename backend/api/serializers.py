from rest_framework import serializers
from .models import User, Provider, Booking, BookingAttempt, AgentLog, Reminder

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = '__all__'

class ProviderSerializer(serializers.ModelSerializer):
    class Meta:
        model = Provider
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
    provider = ProviderSerializer(read_only=True)
    agent_logs = AgentLogSerializer(many=True, read_only=True)
    attempts = BookingAttemptSerializer(many=True, read_only=True)
    
    class Meta:
        model = Booking
        fields = '__all__'
