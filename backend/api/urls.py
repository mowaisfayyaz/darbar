# pyrefly: ignore [missing-import]
from django.urls import path
from . import views

urlpatterns = [
    # Authentication
    path('auth/register/', views.register, name='register'),
    path('auth/login/', views.login, name='login'),
    
    # Core Agent Orchestrator
    path('request/', views.process_request, name='process_request'),
    path('request/select/', views.select_provider, name='select_provider'),
    
    # Bookings (Customer)
    path('bookings/<uuid:pk>/', views.get_booking, name='get_booking'),
    path('bookings/user/<str:user_id>/', views.get_user_bookings, name='get_user_bookings'),
    path('confirm/', views.confirm_booking, name='confirm_booking'),
    
    # Agent Logs (Traces)
    path('logs/<uuid:pk>/', views.get_agent_logs, name='get_agent_logs'),
    
    # Providers
    path('providers/', views.list_providers, name='list_providers'),
    
    # Provider Dashboard Endpoints
    path('provider/bookings/<str:provider_id>/', views.get_provider_bookings, name='get_provider_bookings'),
    path('provider/respond/', views.provider_respond, name='provider_respond'),
    path('provider/stats/<str:provider_id>/', views.get_provider_stats, name='get_provider_stats'),
    path('provider/toggle-availability/<str:provider_id>/', views.toggle_provider_availability, name='toggle_provider_availability'),
    
    # Notifications
    path('notifications/<str:user_id>/', views.get_notifications, name='get_notifications'),
    path('notifications/read/<uuid:notification_id>/', views.mark_notification_read, name='mark_notification_read'),
    
    # Google OAuth Endpoints
    path('auth/google/url/', views.google_auth_url, name='google_auth_url'),
    path('auth/google/callback/', views.google_auth_callback, name='google_auth_callback'),
    path('auth/google/status/', views.google_auth_status, name='google_auth_status'),
    path('auth/google/disconnect/', views.google_disconnect, name='google_disconnect'),
    path('auth/google-login/', views.google_login, name='google_login'),
    path('auth/google/config/', views.google_config, name='google_config'),
]
