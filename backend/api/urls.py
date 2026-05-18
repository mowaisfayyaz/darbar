from django.urls import path
from . import views

urlpatterns = [
    path('auth/register/', views.register, name='register'),
    path('auth/login/', views.login, name='login'),
    path('request/', views.process_request, name='process_request'),
    path('bookings/<uuid:pk>/', views.get_booking, name='get_booking'),
    path('bookings/user/<str:user_id>/', views.get_user_bookings, name='get_user_bookings'),
    path('logs/<uuid:pk>/', views.get_agent_logs, name='get_agent_logs'),
    path('providers/', views.list_providers, name='list_providers'),
    path('confirm/', views.confirm_booking, name='confirm_booking'),
    path('notifications/<str:user_id>/', views.get_notifications, name='get_notifications'),
    path('notifications/read/<uuid:notification_id>/', views.mark_notification_read, name='mark_notification_read'),
    
    # Google OAuth Endpoints
    path('auth/google/url/', views.google_auth_url, name='google_auth_url'),
    path('auth/google/callback/', views.google_auth_callback, name='google_auth_callback'),
    path('auth/google/status/', views.google_auth_status, name='google_auth_status'),
    path('auth/google/disconnect/', views.google_disconnect, name='google_disconnect'),
]
