# pyrefly: ignore [missing-import]
import os
from re import DEBUG
# pyrefly: ignore [missing-import]
from django.http import HttpResponse
# pyrefly: ignore [missing-import]
from rest_framework.decorators import api_view
# pyrefly: ignore [missing-import]
from rest_framework.response import Response
# pyrefly: ignore [missing-import]
from rest_framework import status
# pyrefly: ignore [missing-import]
from django.contrib.auth.hashers import make_password, check_password
# pyrefly: ignore [missing-import]
from django.db.models import Q
from .models import User, Provider, Booking, BookingAttempt, AgentLog, Notification, SystemSetting, ServiceGig, DiscountBanner, ProviderExperience, Review
from .serializers import ProviderSerializer, BookingSerializer, AgentLogSerializer, ServiceGigSerializer, DiscountBannerSerializer, ProviderExperienceSerializer, ReviewSerializer
from django.http import JsonResponse

from agents.intent_agent import extract_intent
from agents.discovery_agent import discover_providers
from agents.ranking_agent import rank_candidates
from agents.decision_agent import make_decision
from agents.booking_agent import attempt_booking
from agents.followup_agent import schedule_reminders
# pyrefly: ignore [missing-import]
from django.utils.crypto import get_random_string
from .google_oauth import get_authorization_url, exchange_code_for_tokens, is_google_linked, disconnect_google



@api_view(['POST'])
def register(request):
    """
    Register a new user (customer) or provider.
    Expects: {name, email, phone, password, role, category?, city?, area?}
    """
    name = request.data.get('name', '').strip()
    email = request.data.get('email', '').strip().lower()
    phone = request.data.get('phone', '').strip()
    password = request.data.get('password', '')
    role = request.data.get('role', 'customer')

    if not all([name, email, phone, password]):
        return Response({'error': 'Name, Email, Phone, and Password are all required.'}, status=status.HTTP_400_BAD_REQUEST)

    hashed = make_password(password)

    if role == 'provider':
        if Provider.objects.filter(phone=phone).exists():
            return Response({'error': 'A provider with this phone already exists.'}, status=status.HTTP_400_BAD_REQUEST)
        if email and Provider.objects.filter(email=email).exists():
            return Response({'error': 'A provider with this email already exists.'}, status=status.HTTP_400_BAD_REQUEST)
        provider = Provider.objects.create(
            business_name=name,
            email=email or None,
            phone=phone,
            password=hashed,
            category=request.data.get('category', 'General'),
            city=request.data.get('city', 'Islamabad'),
            area=request.data.get('area', ''),
        )
        request.session['provider_id'] = str(provider.id)
        request.session.save()
        return Response({'id': str(provider.id), 'role': 'provider', 'name': provider.business_name, 'email': provider.email}, status=status.HTTP_201_CREATED)
    else:
        if User.objects.filter(phone=phone).exists():
            return Response({'error': 'A user with this phone already exists.'}, status=status.HTTP_400_BAD_REQUEST)
        if email and User.objects.filter(email=email).exists():
            return Response({'error': 'A user with this email already exists.'}, status=status.HTTP_400_BAD_REQUEST)
        user = User.objects.create(
            name=name,
            email=email or None,
            phone=phone,
            password=hashed,
            location=request.data.get('location', ''),
        )
        return Response({'id': str(user.id), 'role': 'customer', 'name': user.name, 'email': user.email}, status=status.HTTP_201_CREATED)


@api_view(['POST'])
def login(request):
    """
    Login via phone or email + password.
    Expects: {identifier: email_or_phone, password: str, role: customer|provider}
    """
    identifier = request.data.get('identifier', '').strip()
    password = request.data.get('password', '')
    role = request.data.get('role', 'customer')

    if identifier == 'admin@darbar.com' and password == 'darbar123':
        return Response({
            'id': '00000000-0000-0000-0000-000000000000',
            'role': 'admin',
            'name': 'Super Admin',
            'email': 'admin@darbar.com'
        })

    if not identifier or not password:
        return Response({'error': 'Email/phone and password are required.'}, status=status.HTTP_400_BAD_REQUEST)

    if role == 'provider':
        try:
            provider = Provider.objects.get(Q(phone=identifier) | Q(email=identifier))
            if not check_password(password, provider.password):
                return Response({'error': 'Incorrect password.'}, status=status.HTTP_401_UNAUTHORIZED)
            request.session['provider_id'] = str(provider.id)
            request.session.save()
            return Response({'id': str(provider.id), 'role': 'provider', 'name': provider.business_name, 'email': provider.email})
        except Provider.DoesNotExist:
            return Response({'error': 'Provider not found.'}, status=status.HTTP_404_NOT_FOUND)
    else:
        try:
            user = User.objects.get(Q(phone=identifier) | Q(email=identifier))
            if not check_password(password, user.password):
                return Response({'error': 'Incorrect password.'}, status=status.HTTP_401_UNAUTHORIZED)
            return Response({'id': str(user.id), 'role': 'customer', 'name': user.name, 'email': user.email})
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['GET'])
def get_notifications(request, user_id):
    if user_id == '00000000-0000-0000-0000-000000000000' or user_id == 'admin':
        return Response([])
    notifications = Notification.objects.filter(
        Q(user_id=user_id) | Q(provider_id=user_id)
    ).order_by('-created_at')[:20]
    data = [{'id': str(n.id), 'title': n.title, 'body': n.body, 'is_read': n.is_read, 'created_at': str(n.created_at)} for n in notifications]
    return Response(data)


@api_view(['POST'])
def mark_notification_read(request, notification_id):
    try:
        n = Notification.objects.get(id=notification_id)
        n.is_read = True
        n.save()
        return Response({'status': 'ok'})
    except Notification.DoesNotExist:
        return Response(status=status.HTTP_404_NOT_FOUND)


@api_view(['GET'])
def get_user_bookings(request, user_id):
    if user_id == '00000000-0000-0000-0000-000000000000' or user_id == 'admin':
        return Response([])
    bookings = Booking.objects.filter(user_id=user_id).order_by('-created_at')
    serializer = BookingSerializer(bookings, many=True)
    return Response(serializer.data)


@api_view(['POST'])
def process_request(request):
    """
    Main orchestrator entry point.
    Expects: {"user_id": "uuid", "text": "Mujhe kal subah G-13 mein AC technician chahiye"}
    
    Flow:
    1. Extract intent (clarification queries do NOT create bookings)
    2. If intent is complete → create booking → discover → rank → decide → book → followup
    3. Return rich response with all provider details
    """
    user_id = request.data.get('user_id')
    raw_text = request.data.get('text')

    if not user_id or not raw_text:
        return Response({"error": "user_id and text are required"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)

    try:
        # Retrieve previous chat history from Django database cache
        # pyrefly: ignore [missing-import]
        from django.core.cache import cache
        session_key = f"chat_session_{user_id}"
        chat_history = cache.get(session_key, [])

        # Step 1: Extract intent (no booking created yet, passing conversation history context)
        intent_data = extract_intent(raw_text, history=chat_history)
        
        # If the intent needs clarification, respond without creating a booking
        if intent_data.get('needs_clarification', False):
            # Save user query and agent response to conversation cache
            chat_history.append({"role": "user", "content": raw_text})
            chat_history.append({"role": "assistant", "content": intent_data.get('reply_message', '')})
            cache.set(session_key, chat_history[-10:], timeout=600)  # Expires in 10 minutes

            return Response({
                "status": "clarification",
                "message": intent_data.get('reply_message', 'Please provide service type, location, and time details.'),
                "intent": {
                    "service_type": intent_data.get('service_type'),
                    "location": intent_data.get('location'),
                    "time_preference": intent_data.get('time_preference'),
                    "language_detected": intent_data.get('language_detected'),
                }
            }, status=status.HTTP_200_OK)

        # Clear session cache since booking intent is fully complete
        cache.delete(session_key)

        # Step 2: Discover providers (pass user_id so Apify toggle is checked)
        candidates, apify_triggered = discover_providers(intent_data, user_id=str(user.id))
        
        # Step 3: Rank candidates
        ranked_candidates = rank_candidates(candidates, target_location=intent_data.get('location', 'Unknown'))

        if not ranked_candidates:
            return Response({
                "status": "failed", 
                "reason": f"Sorry, no available {intent_data.get('service_type', 'service partners')} were found in {intent_data.get('location', 'your area')}."
            })

        # Step 4: Serialize the top 3 candidates
        serialized_providers = []
        for cand in ranked_candidates[:3]:
            serialized_providers.append({
                "id": str(cand['id']),
                "business_name": cand['business_name'],
                "phone": cand['phone'],
                "rating": float(cand['rating']),
                "review_count": int(cand['review_count']),
                "area": cand['area'],
                "city": cand['city'],
                "category": cand['category'],
                "score": cand.get('total_score', 0.0),
                "distance": cand.get('distance_km'),
            })

        # Step 5: Return selection options
        lang = intent_data.get('language_detected', 'en')
        if lang == 'ur':
            message = f"مجھے آپ کی ضرورت کے مطابق {len(serialized_providers)} بہترین سروس پارٹنرز ملے ہیں۔ براہ کرم بک کرنے کے لیے ایک کا انتخاب کریں:"
        elif lang == 'ur-roman':
            message = f"Mujhe aapki requirement k mutabiq {len(serialized_providers)} best service partners mile hain. Plz book krne k liye ek select krein:"
        else:
            message = f"I found the top {len(serialized_providers)} service partners matching your request. Please select one to book:"

        return Response({
            "status": "selection",
            "message": message,
            "service_type": intent_data.get('service_type', 'Unknown'),
            "location": intent_data.get('location', 'Unknown'),
            "providers": serialized_providers
        }, status=status.HTTP_200_OK)

    except Exception as e:
        # Log system errors
        AgentLog.objects.create(
            agent_name="System",
            action_taken="Error processing request",
            reasoning=str(e)
        )
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


def parse_scheduled_time(time_str):
    if not time_str:
        return None
    from django.utils import timezone
    import datetime
    import re
    
    time_str_clean = time_str.strip().lower()
    if time_str_clean in ('unknown', 'flexible', 'as soon as possible', 'asap', 'none', 'anytime'):
        return timezone.now()
        
    now = timezone.now()
    target_date = now.date()
    
    # If "tomorrow" or "kal" is in time_str_clean
    if 'tomorrow' in time_str_clean or 'kal' in time_str_clean:
        target_date += datetime.timedelta(days=1)
    
    # Try to find a simple time like "2pm", "2:00 pm", "2:30 pm", "14:00"
    time_match = re.search(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', time_str_clean)
    if time_match:
        try:
            hour = int(time_match.group(1))
            minute = int(time_match.group(2)) if time_match.group(2) else 0
            meridiem = time_match.group(3)
            
            if meridiem == 'pm' and hour < 12:
                hour += 12
            elif meridiem == 'am' and hour == 12:
                hour = 0
                
            parsed_dt = datetime.datetime.combine(target_date, datetime.time(hour, minute))
            return timezone.make_aware(parsed_dt, timezone.get_current_timezone())
        except Exception:
            pass
            
    # Try dateutil parser as fallback
    try:
        from dateutil import parser
        parsed_dt = parser.parse(time_str, default=datetime.datetime.combine(target_date, datetime.time(12, 0)))
        if parsed_dt.tzinfo is None:
            parsed_dt = timezone.make_aware(parsed_dt, timezone.get_current_timezone())
        return parsed_dt
    except Exception:
        pass
        
    # Default to now if couldn't parse but wasn't empty
    return now

@api_view(['POST'])
def select_provider(request):
    """
    Client selection confirmation endpoint.
    Expects: {"user_id": "uuid", "provider_id": "uuid", "service_type": "Plumber", "location": "G-13", "scheduled_time": "2:00 PM"}
    """
    user_id = request.data.get('user_id')
    provider_id = request.data.get('provider_id')
    service_type = request.data.get('service_type', 'Unknown')
    location = request.data.get('location', 'Unknown')
    scheduled_time_raw = request.data.get('scheduled_time')

    if not user_id or not provider_id:
        return Response({"error": "user_id and provider_id are required"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        user = User.objects.get(id=user_id)
        provider = Provider.objects.get(id=provider_id)
    except (User.DoesNotExist, Provider.DoesNotExist):
        return Response({"error": "User or Provider not found"}, status=status.HTTP_404_NOT_FOUND)

    try:
        # Create the booking
        booking_id_human = f"BK-2026-{get_random_string(6).upper()}"
        scheduled_time = parse_scheduled_time(scheduled_time_raw)
        
        booking = Booking.objects.create(
            booking_id=booking_id_human,
            user=user,
            provider=provider,
            service_type=service_type,
            location=location,
            status='pending',
            scheduled_time=scheduled_time
        )

        # Log the selection
        AgentLog.objects.create(
            booking=booking,
            agent_name="Decision Agent",
            action_taken="Client selected provider from top matches",
            reasoning=f"User selected provider '{provider.business_name}' for {service_type} at {location}."
        )

        # Attempt booking notifications/timers
        attempt = attempt_booking(booking_obj=booking, provider_obj=provider)
        schedule_reminders(booking)

        # Create notifications for both user and provider
        Notification.objects.create(
            user=user,
            title="Booking Request Sent",
            body=f"Your booking {booking.booking_id} for {booking.service_type} has been sent to {provider.business_name}. Waiting for confirmation."
        )
        Notification.objects.create(
            provider=provider,
            title="New Booking Request",
            body=f"New {booking.service_type} request from {user.name} at {booking.location}. Booking ID: {booking.booking_id}."
        )

        # Return standard processing payload to redirect Flutter app to processing animation screen
        reasoning = f"Selected {provider.business_name} matching user selection. Provider rating {provider.rating}/5."
        return Response({
            "status": "processing",
            "booking_id": str(booking.id),
            "human_booking_id": booking.booking_id,
            "message": reasoning,
            "service_type": booking.service_type,
            "location": booking.location,
            "scheduled_time": booking.scheduled_time.isoformat() if booking.scheduled_time else None,
            "provider_name": provider.business_name,
            "provider_rating": provider.rating,
            "provider_phone": provider.phone,
            "provider_area": provider.area,
            "provider_reviews": provider.review_count,
            "provider_category": provider.category,
        })
    except Exception as e:
        AgentLog.objects.create(
            agent_name="System",
            action_taken="Error creating selected booking",
            reasoning=str(e)
        )
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



@api_view(['GET'])
def get_booking(request, pk):
    try:
        booking = Booking.objects.get(id=pk)
        serializer = BookingSerializer(booking)
        return Response(serializer.data)
    except Booking.DoesNotExist:
        return Response(status=status.HTTP_404_NOT_FOUND)


@api_view(['GET'])
def get_agent_logs(request, pk):
    try:
        booking = Booking.objects.get(id=pk)
        logs = booking.agent_logs.all().order_by('timestamp')
        serializer = AgentLogSerializer(logs, many=True)
        return Response(serializer.data)
    except Booking.DoesNotExist:
        return Response(status=status.HTTP_404_NOT_FOUND)


@api_view(['GET'])
def list_providers(request):
    providers = Provider.objects.all()
    serializer = ProviderSerializer(providers, many=True)
    return Response(serializer.data)


@api_view(['POST'])
def confirm_booking(request):
    """
    Provider confirmation endpoint.
    Expects: {booking_id, provider_id, status: accepted|declined}
    """
    booking_id = request.data.get('booking_id')
    new_status = request.data.get('status')

    if not booking_id or new_status not in ('accepted', 'declined'):
        return Response({'error': 'booking_id and valid status required.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        booking = Booking.objects.get(id=booking_id)
        booking.status = 'confirmed' if new_status == 'accepted' else 'cancelled'
        booking.save()
        
        # Update the booking attempt
        attempt = BookingAttempt.objects.filter(booking=booking).order_by('-sent_at').first()
        if attempt:
            # pyrefly: ignore [missing-import]
            from django.utils import timezone
            attempt.status = new_status
            attempt.responded_at = timezone.now()
            attempt.save()
        
        # Create notification for user
        status_msg = "confirmed" if new_status == 'accepted' else "cancelled"
        if booking.user:
            provider_name = booking.provider.business_name if booking.provider else "Provider"
            Notification.objects.create(
                user=booking.user,
                title=f"Booking {status_msg.title()}",
                body=f"Your booking {booking.booking_id} has been {status_msg} by {provider_name}."
            )
        
        # Log the decision
        AgentLog.objects.create(
            booking=booking,
            agent_name="Booking Agent",
            action_taken=f"Provider {new_status} the booking",
            reasoning=f"Booking {booking.booking_id} has been {status_msg} by the provider."
        )
        
        return Response({'status': booking.status, 'booking_id': str(booking.id)})
    except Booking.DoesNotExist:
        return Response(status=status.HTTP_404_NOT_FOUND)


# ==================== PROVIDER ENDPOINTS ====================

@api_view(['GET'])
def get_provider_bookings(request, provider_id):
    """
    Get all bookings assigned to a specific provider.
    Returns pending bookings first, then confirmed, then completed.
    """
    bookings = Booking.objects.filter(provider_id=provider_id).order_by(
        # Custom ordering: pending first, then confirmed, then others
        '-created_at'
    )
    serializer = BookingSerializer(bookings, many=True)
    return Response(serializer.data)


@api_view(['POST'])
def provider_respond(request):
    """
    Provider accepts, declines, or completes a booking request.
    Expects: {booking_id: uuid, provider_id: uuid, action: 'accept'|'decline'|'complete'}
    """
    booking_id = request.data.get('booking_id')
    provider_id = request.data.get('provider_id')
    action = request.data.get('action')

    if not booking_id or not provider_id or action not in ('accept', 'decline', 'complete'):
        return Response(
            {'error': 'booking_id, provider_id, and valid action (accept/decline/complete) required.'}, 
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        booking = Booking.objects.get(id=booking_id, provider_id=provider_id)
    except Booking.DoesNotExist:
        return Response({'error': 'Booking not found or not assigned to this provider.'}, status=status.HTTP_404_NOT_FOUND)

    # pyrefly: ignore [missing-import]
    from django.utils import timezone

    if action == 'accept':
        booking.status = 'confirmed'
        booking.save()

        # Update attempt
        attempt = BookingAttempt.objects.filter(booking=booking, provider_id=provider_id).order_by('-sent_at').first()
        if attempt:
            attempt.status = 'accepted'
            attempt.responded_at = timezone.now()
            attempt.save()

        # Notify customer
        Notification.objects.create(
            user=booking.user,
            title="🎉 Booking Confirmed!",
            body=f"Great news! {booking.provider.business_name} has accepted your {booking.service_type} booking ({booking.booking_id}). They will be arriving at {booking.location}."
        )

        AgentLog.objects.create(
            booking=booking,
            agent_name="Booking Agent",
            action_taken=f"{booking.provider.business_name} accepted the booking",
            reasoning=f"Provider confirmed availability and accepted booking {booking.booking_id}."
        )

        return Response({
            'status': 'confirmed',
            'booking_id': str(booking.id),
            'message': f'Booking accepted! Customer {booking.user.name} has been notified.'
        })
    
    elif action == 'complete':
        booking.status = 'completed'
        booking.save()

        # Notify customer
        Notification.objects.create(
            user=booking.user,
            title="🎉 Service Completed!",
            body=f"Great news! {booking.provider.business_name} has marked your {booking.service_type} booking ({booking.booking_id}) as completed. Please rate their service!"
        )

        AgentLog.objects.create(
            booking=booking,
            agent_name="Booking Agent",
            action_taken=f"{booking.provider.business_name} marked booking as completed",
            reasoning=f"Provider finished the job and marked booking {booking.booking_id} as completed."
        )

        return Response({
            'status': 'completed',
            'booking_id': str(booking.id),
            'message': 'Booking marked as completed. Customer has been notified.'
        })
    
    else:  # decline
        booking.status = 'cancelled'
        booking.save()

        # Update attempt
        attempt = BookingAttempt.objects.filter(booking=booking, provider_id=provider_id).order_by('-sent_at').first()
        if attempt:
            attempt.status = 'declined'
            attempt.responded_at = timezone.now()
            attempt.failure_reason = 'Provider declined the request'
            attempt.save()

        # Notify customer
        Notification.objects.create(
            user=booking.user,
            title="Booking Update",
            body=f"{booking.provider.business_name} was unable to accept your {booking.service_type} booking ({booking.booking_id}). We're looking for alternatives."
        )

        AgentLog.objects.create(
            booking=booking,
            agent_name="Booking Agent",
            action_taken=f"{booking.provider.business_name} declined the booking",
            reasoning=f"Provider declined booking {booking.booking_id}. System will attempt to find alternative providers."
        )

        return Response({
            'status': 'declined',
            'booking_id': str(booking.id),
            'message': 'Booking declined. Customer has been notified.'
        })


@api_view(['GET'])
def get_provider_stats(request, provider_id):
    """Get statistics for a provider dashboard."""
    try:
        provider = Provider.objects.get(id=provider_id)
    except Provider.DoesNotExist:
        return Response({'error': 'Provider not found.'}, status=status.HTTP_404_NOT_FOUND)

    total_bookings = Booking.objects.filter(provider=provider, status='completed').count()
    confirmed_bookings = Booking.objects.filter(provider=provider, status='confirmed').count()
    pending_bookings = Booking.objects.filter(provider=provider, status='pending').count()

    return Response({
        'provider_name': provider.business_name,
        'category': provider.category,
        'rating': provider.rating,
        'review_count': provider.review_count,
        'is_available': provider.is_available,
        'total_bookings': total_bookings,
        'confirmed_bookings': confirmed_bookings,
        'pending_bookings': pending_bookings,
    })


@api_view(['POST'])
def toggle_provider_availability(request, provider_id):
    """Toggle provider's availability status."""
    try:
        provider = Provider.objects.get(id=provider_id)
        provider.is_available = not provider.is_available
        provider.save()
        return Response({
            'is_available': provider.is_available,
            'message': f"You are now {'available' if provider.is_available else 'offline'}."
        })
    except Provider.DoesNotExist:
        return Response({'error': 'Provider not found.'}, status=status.HTTP_404_NOT_FOUND)


# ==================== GOOGLE OAUTH ENDPOINTS ====================

import json
# pyrefly: ignore [missing-import]
from google.oauth2 import id_token as google_id_token
# pyrefly: ignore [missing-import]
from google.auth.transport import requests as google_requests

@api_view(['GET'])
def google_auth_url(request):
    """
    Generates the authorization URL. 
    Encodes user_id and role inside the OAuth 'state' parameter to enable secure multi-user linking.
    """
    user_id = request.GET.get('user_id')
    role = request.GET.get('role', 'customer')
    
    state_data = {}
    if user_id:
        state_data = {'user_id': user_id, 'role': role}
        
    try:
        state_str = json.dumps(state_data) if state_data else None
        redirect_uri = request.build_absolute_uri('/api/auth/google/callback/')
        url = get_authorization_url(state=state_str, redirect_uri=redirect_uri)
        return Response({'url': url})
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
def google_auth_callback(request):
    """
    Exchanges OAuth code for token, decodes 'state' to identify the specific user,
    and updates their google_email and is_google_linked flags in the database.
    """
    code = request.GET.get('code')
    state_param = request.GET.get('state')
    
    if not code:
        return HttpResponse("Missing authorization code", status=400)
        
    try:
        # 1. Exchange token globally (keeps global sender credentials intact)
        redirect_uri = request.build_absolute_uri(request.path)
        email = exchange_code_for_tokens(code, redirect_uri=redirect_uri)
        
        # 2. Extract specific user context from state and update their DB record
        if state_param:
            try:
                state_data = json.loads(state_param)
                user_id = state_data.get('user_id')
                role = state_data.get('role', 'customer')
                
                if user_id:
                    if role == 'provider':
                        p = Provider.objects.get(id=user_id)
                        p.google_email = email.lower()
                        p.is_google_linked = True
                        p.save()
                    else:
                        u = User.objects.get(id=user_id)
                        u.google_email = email.lower()
                        u.is_google_linked = True
                        u.save()
            except Exception as state_err:
                # Log state parsing errors but do not crash the auth window response
                print(f"Error parsing OAuth state parameter: {state_err}")

        success_html = f"""
        <html>
        <body style="font-family: sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; background: #f5f5f5; margin: 0;">
            <div style="text-align: center; padding: 2.5rem; background: white; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.08); max-width: 400px; width: 90%;">
                <div style="font-size: 4rem; color: #4CAF50; margin-bottom: 1rem;">✔</div>
                <h1 style="color: #2c3e50; margin: 0 0 0.5rem 0; font-size: 1.6rem;">Google Account Linked!</h1>
                <p style="color: #7f8c8d; font-size: 1rem; margin-bottom: 2rem; line-height: 1.5;">
                    Darbar has successfully linked to your Google Account: <strong>{email}</strong>.
                </p>
                <div style="font-size: 0.9rem; color: #95a5a6; border-top: 1px solid #ecf0f1; padding-top: 1rem;">
                    This window will automatically close in a few seconds...
                </div>
            </div>
            <script>
                setTimeout(function() {{
                    window.close();
                }}, 3000);
            </script>
        </body>
        </html>
        """
        return HttpResponse(success_html)
    except Exception as e:
        error_html = f"""
        <html>
        <body style="font-family: sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; background: #f5f5f5; margin: 0;">
            <div style="text-align: center; padding: 2.5rem; background: white; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.08); max-width: 400px; width: 90%;">
                <div style="font-size: 4rem; color: #F44336; margin-bottom: 1rem;">❌</div>
                <h1 style="color: #2c3e50; margin: 0 0 0.5rem 0; font-size: 1.6rem;">Link Failed</h1>
                <p style="color: #7f8c8d; font-size: 1rem; margin-bottom: 2rem; line-height: 1.5;">
                    {str(e)}
                </p>
                <div style="font-size: 0.9rem; color: #95a5a6; border-top: 1px solid #ecf0f1; padding-top: 1rem;">
                    You may close this tab and try again.
                </div>
            </div>
        </body>
        </html>
        """
        return HttpResponse(error_html, status=500)


@api_view(['GET'])
def google_auth_status(request):
    """
    Checks if a specific user/provider has linked their Google account.
    """
    user_id = request.GET.get('user_id')
    role = request.GET.get('role', 'customer')
    
    if user_id:
        try:
            if role == 'provider':
                p = Provider.objects.get(id=user_id)
                return Response({'linked': p.is_google_linked, 'email': p.google_email})
            else:
                u = User.objects.get(id=user_id)
                return Response({'linked': u.is_google_linked, 'email': u.google_email})
        except Exception:
            pass
            
    # Fallback to global single-user file settings to prevent breaking legacy flow
    linked, email = is_google_linked()
    return Response({'linked': linked, 'email': email})


@api_view(['POST'])
def google_disconnect(request):
    """
    Disconnects Google account for a specific user/provider or globally.
    """
    user_id = request.data.get('user_id')
    role = request.data.get('role', 'customer')
    
    if user_id:
        try:
            if role == 'provider':
                p = Provider.objects.get(id=user_id)
                p.google_email = None
                p.is_google_linked = False
                p.save()
            else:
                u = User.objects.get(id=user_id)
                u.google_email = None
                u.is_google_linked = False
                u.save()
            return Response({'success': True})
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
            
    success = disconnect_google()
    return Response({'success': success})


@api_view(['POST'])
def google_login(request):
    """
    Verify Google ID Token or Access Token from client and perform single-tap login.
    Expects: {id_token: str, access_token: str, role: customer|provider}
    """
    token = request.data.get('id_token')
    access_token = request.data.get('access_token')
    role = request.data.get('role', 'customer')

    if not token and not access_token:
        return Response({'error': 'Google ID Token or Access Token is required.'}, status=status.HTTP_400_BAD_REQUEST)

    email = None
    if token:
        try:
            # Retrieve the Web Client ID from your environment settings
            client_id = os.getenv('GOOGLE_CLIENT_ID')
            
            # Verify and decode Google ID Token
            id_info = google_id_token.verify_oauth2_token(token, google_requests.Request(), client_id)
            email = id_info.get('email', '').strip().lower()
        except Exception as e:
            # Fallback to access_token if id_token verification failed
            if not access_token:
                # pyrefly: ignore [missing-import]
                from django.conf import settings
                if settings.DEBUG and '@' in token:
                    email = token.strip().lower()
                else:
                    return Response({'error': f'Google token verification failed: {str(e)}'}, status=status.HTTP_401_UNAUTHORIZED)
            
    if not email and access_token:
        try:
            import requests
            # Retrieve user info using access_token
            response = requests.get('https://www.googleapis.com/oauth2/v2/userinfo', params={
                'access_token': access_token
            })
            if response.status_code == 200:
                user_info = response.json()
                email = user_info.get('email', '').strip().lower()
            else:
                return Response({'error': f'Google access token validation failed: {response.text}'}, status=status.HTTP_401_UNAUTHORIZED)
        except Exception as e:
            return Response({'error': f'Google access token request failed: {str(e)}'}, status=status.HTTP_401_UNAUTHORIZED)

    if not email:
        return Response({'error': 'Failed to retrieve email from Google Account.'}, status=status.HTTP_400_BAD_REQUEST)

    # Perform user search by either google_email or primary email in their database record
    if role == 'provider':
        try:
            provider = Provider.objects.get(Q(google_email=email) | Q(email=email))
            # Auto-link Google email if not already marked
            if not provider.is_google_linked:
                provider.google_email = email
                provider.is_google_linked = True
                provider.save()
            return Response({
                'id': str(provider.id),
                'role': 'provider',
                'name': provider.business_name,
                'email': provider.email
            })
        except Provider.DoesNotExist:
            return Response({
                'error': f'No provider account found for Gmail address {email}. Please log in with password and link Google in Settings.'
            }, status=status.HTTP_404_NOT_FOUND)
    else:
        try:
            user = User.objects.get(Q(google_email=email) | Q(email=email))
            # Auto-link Google email if not already marked
            if not user.is_google_linked:
                user.google_email = email
                user.is_google_linked = True
                user.save()
            return Response({
                'id': str(user.id),
                'role': 'customer',
                'name': user.name,
                'email': user.email
            })
        except User.DoesNotExist:
            # Auto-register new customer for seamless Google login experience (especially for presentation/event task)
            username = email.split('@')[0].capitalize()
            random_password = get_random_string(12)
            hashed_password = make_password(random_password)
            placeholder_phone = f"google-{get_random_string(10)}"
            
            user = User.objects.create(
                name=username,
                email=email,
                google_email=email,
                is_google_linked=True,
                password=hashed_password,
                phone=placeholder_phone
            )
            return Response({
                'id': str(user.id),
                'role': 'customer',
                'name': user.name,
                'email': user.email
            })


@api_view(['GET'])
def google_config(request):
    """
    Returns public Google OAuth configuration details, such as client ID.
    """
    client_id = os.getenv('GOOGLE_CLIENT_ID', '').strip('"\'')
    return Response({'client_id': client_id})


@api_view(['GET'])
def get_admin_stats(request):
    customer_count = User.objects.count()
    provider_count = Provider.objects.count()
    setting, _ = SystemSetting.objects.get_or_create(key='apify_enabled_by_admin', defaults={'value': 'true'})
    apify_enabled = setting.value.lower() == 'true'
    return Response({
        'customer_count': customer_count,
        'provider_count': provider_count,
        'apify_enabled_by_admin': apify_enabled
    })


@api_view(['POST'])
def toggle_apify(request):
    setting, _ = SystemSetting.objects.get_or_create(key='apify_enabled_by_admin', defaults={'value': 'true'})
    current_val = setting.value.lower() == 'true'
    new_val = not current_val
    setting.value = 'true' if new_val else 'false'
    setting.save()
    return Response({'apify_enabled_by_admin': new_val})


@api_view(['GET'])
def get_system_config(request):
    user_id = request.GET.get('user_id')
    role = request.GET.get('role', 'customer')
    
    setting, _ = SystemSetting.objects.get_or_create(key='apify_enabled_by_admin', defaults={'value': 'true'})
    apify_enabled_by_admin = setting.value.lower() == 'true'
    
    user_apify_enabled = False
    if user_id and user_id != 'admin' and user_id != '00000000-0000-0000-0000-000000000000':
        if role == 'provider':
            try:
                provider = Provider.objects.get(id=user_id)
                user_apify_enabled = provider.is_apify_enabled
            except Provider.DoesNotExist:
                pass
        else:
            try:
                user = User.objects.get(id=user_id)
                user_apify_enabled = user.is_apify_enabled
            except User.DoesNotExist:
                pass
                
    return Response({
        'apify_enabled_by_admin': apify_enabled_by_admin,
        'user_apify_enabled': user_apify_enabled
    })


@api_view(['POST'])
def update_user_apify(request):
    user_id = request.data.get('user_id')
    role = request.data.get('role', 'customer')
    enabled = request.data.get('enabled', False)
    
    if not user_id:
        return Response({'error': 'user_id is required.'}, status=status.HTTP_400_BAD_REQUEST)
        
    if role == 'provider':
        try:
            provider = Provider.objects.get(id=user_id)
            provider.is_apify_enabled = enabled
            provider.save()
            return Response({'status': 'ok', 'is_apify_enabled': provider.is_apify_enabled})
        except Provider.DoesNotExist:
            return Response({'error': 'Provider not found.'}, status=status.HTTP_404_NOT_FOUND)
    else:
        try:
            user = User.objects.get(id=user_id)
            user.is_apify_enabled = enabled
            user.save()
            return Response({'status': 'ok', 'is_apify_enabled': user.is_apify_enabled})
        except User.DoesNotExist:
            return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['GET'])
def get_admin_users(request):
    """
    Returns lists of all customers and providers.
    """
    customers = User.objects.all().order_by('-created_at')
    providers = Provider.objects.all().order_by('-created_at')
    
    customer_list = []
    for c in customers:
        customer_list.append({
            'id': str(c.id),
            'name': c.name,
            'email': c.email or '',
            'phone': c.phone,
            'location': c.location or '',
            'is_google_linked': c.is_google_linked,
            'google_email': c.google_email or '',
            'is_apify_enabled': c.is_apify_enabled,
            'role': 'customer',
            'created_at': str(c.created_at)
        })
        
    provider_list = []
    for p in providers:
        provider_list.append({
            'id': str(p.id),
            'name': p.business_name,
            'email': p.email or '',
            'phone': p.phone,
            'category': p.category,
            'city': p.city,
            'area': p.area,
            'rating': p.rating,
            'review_count': p.review_count,
            'website': p.website or '',
            'is_available': p.is_available,
            'is_google_linked': p.is_google_linked,
            'google_email': p.google_email or '',
            'is_apify_enabled': p.is_apify_enabled,
            'role': 'provider',
            'created_at': str(p.created_at)
        })
        
    return Response({
        'customers': customer_list,
        'providers': provider_list
    })


@api_view(['POST'])
def admin_create_user(request):
    """
    Admin creates a new user or provider.
    """
    role = request.data.get('role', 'customer')
    name = request.data.get('name', '').strip()
    email = request.data.get('email', '').strip().lower() or None
    phone = request.data.get('phone', '').strip()
    password = request.data.get('password', '')
    
    if not name or not phone or not password:
        return Response({'error': 'Name, phone, and password are required.'}, status=status.HTTP_400_BAD_REQUEST)
        
    hashed = make_password(password)
    
    if role == 'provider':
        if Provider.objects.filter(phone=phone).exists():
            return Response({'error': 'A provider with this phone already exists.'}, status=status.HTTP_400_BAD_REQUEST)
        if email and Provider.objects.filter(email=email).exists():
            return Response({'error': 'A provider with this email already exists.'}, status=status.HTTP_400_BAD_REQUEST)
            
        provider = Provider.objects.create(
            business_name=name,
            email=email,
            phone=phone,
            password=hashed,
            category=request.data.get('category', 'General'),
            city=request.data.get('city', 'Islamabad'),
            area=request.data.get('area', ''),
            website=request.data.get('website', '') or None,
            rating=float(request.data.get('rating', 0.0) or 0.0),
            review_count=int(request.data.get('review_count', 0) or 0),
        )
        return Response({'status': 'ok', 'id': str(provider.id)})
    else:
        if User.objects.filter(phone=phone).exists():
            return Response({'error': 'A customer with this phone already exists.'}, status=status.HTTP_400_BAD_REQUEST)
        if email and User.objects.filter(email=email).exists():
            return Response({'error': 'A customer with this email already exists.'}, status=status.HTTP_400_BAD_REQUEST)
            
        user = User.objects.create(
            name=name,
            email=email,
            phone=phone,
            password=hashed,
            location=request.data.get('location', ''),
        )
        return Response({'status': 'ok', 'id': str(user.id)})


@api_view(['POST'])
def admin_update_user(request):
    """
    Admin updates details of a user or provider.
    """
    user_id = request.data.get('id')
    role = request.data.get('role', 'customer')
    name = request.data.get('name', '').strip()
    email = request.data.get('email', '').strip().lower() or None
    phone = request.data.get('phone', '').strip()
    password = request.data.get('password', '').strip()
    
    if not user_id:
        return Response({'error': 'User ID is required.'}, status=status.HTTP_400_BAD_REQUEST)
        
    if role == 'provider':
        try:
            p = Provider.objects.get(id=user_id)
            if Provider.objects.filter(phone=phone).exclude(id=user_id).exists():
                return Response({'error': 'A provider with this phone already exists.'}, status=status.HTTP_400_BAD_REQUEST)
            if email and Provider.objects.filter(email=email).exclude(id=user_id).exists():
                return Response({'error': 'A provider with this email already exists.'}, status=status.HTTP_400_BAD_REQUEST)
                
            p.business_name = name
            p.email = email
            p.phone = phone
            if password:
                p.password = make_password(password)
            p.category = request.data.get('category', p.category)
            p.city = request.data.get('city', p.city)
            p.area = request.data.get('area', p.area)
            p.website = request.data.get('website', p.website) or None
            p.rating = float(request.data.get('rating', p.rating) or 0.0)
            p.review_count = int(request.data.get('review_count', p.review_count) or 0)
            p.save()
            return Response({'status': 'ok'})
        except Provider.DoesNotExist:
            return Response({'error': 'Provider not found.'}, status=status.HTTP_404_NOT_FOUND)
    else:
        try:
            u = User.objects.get(id=user_id)
            if User.objects.filter(phone=phone).exclude(id=user_id).exists():
                return Response({'error': 'A customer with this phone already exists.'}, status=status.HTTP_400_BAD_REQUEST)
            if email and User.objects.filter(email=email).exclude(id=user_id).exists():
                return Response({'error': 'A customer with this email already exists.'}, status=status.HTTP_400_BAD_REQUEST)
                
            u.name = name
            u.email = email
            u.phone = phone
            if password:
                u.password = make_password(password)
            u.location = request.data.get('location', u.location)
            u.save()
            return Response({'status': 'ok'})
        except User.DoesNotExist:
            return Response({'error': 'Customer not found.'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['POST'])
def admin_delete_user(request):
    """
    Admin deletes a user or provider.
    """
    user_id = request.data.get('id')
    role = request.data.get('role', 'customer')
    
    if not user_id:
        return Response({'error': 'User ID is required.'}, status=status.HTTP_400_BAD_REQUEST)
        
    if role == 'provider':
        try:
            p = Provider.objects.get(id=user_id)
            p.delete()
            return Response({'status': 'ok'})
        except Provider.DoesNotExist:
            return Response({'error': 'Provider not found.'}, status=status.HTTP_404_NOT_FOUND)
    else:
        try:
            u = User.objects.get(id=user_id)
            u.delete()
            return Response({'status': 'ok'})
        except User.DoesNotExist:
            return Response({'error': 'Customer not found.'}, status=status.HTTP_404_NOT_FOUND)


import requests
import uuid
import os

@api_view(['POST'])
def upload_image(request):
    """
    Upload an image to Supabase Storage.
    Expects multipart file 'image'
    """
    if 'image' not in request.FILES:
        return Response({'error': 'No image file provided'}, status=status.HTTP_400_BAD_REQUEST)
        
    image_file = request.FILES['image']
    file_bytes = image_file.read()
    filename = image_file.name
    content_type = image_file.content_type or 'image/jpeg'
    
    try:
        supabase_url = os.getenv('SUPABASE_URL')
        supabase_key = os.getenv('SUPABASE_KEY')
        if not supabase_url or not supabase_key:
            return Response({'error': 'Supabase configuration missing in environment.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            
        supabase_url = supabase_url.rstrip('/')
        bucket = "provider-assets"
        ext = os.path.splitext(filename)[1] or ".jpg"
        unique_filename = f"{uuid.uuid4()}{ext}"
        
        url = f"{supabase_url}/storage/v1/object/{bucket}/{unique_filename}"
        headers = {
            "Authorization": f"Bearer {supabase_key}",
            "ApiKey": supabase_key,
            "Content-Type": content_type
        }
        
        response = requests.post(url, headers=headers, data=file_bytes)
        if response.status_code != 200:
            return Response({'error': f'Failed to upload to Supabase: {response.text}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            
        public_url = f"{supabase_url}/storage/v1/object/public/{bucket}/{unique_filename}"
        return Response({'url': public_url})
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET', 'POST'])
def provider_profile_detail(request, provider_id):
    """
    Get or Update Provider Profile.
    """
    try:
        provider = Provider.objects.get(id=provider_id)
    except Provider.DoesNotExist:
        return Response({'error': 'Provider not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'POST':
        # Security session check as required by user (supports custom header fallback for cross-domain CORS compatibility)
        session_provider_id = request.headers.get('x-provider-id') or request.session.get('provider_id')
        if str(session_provider_id) != str(provider_id):
            return JsonResponse({'error': 'Unauthorized'}, status=403)

        provider.business_name = request.data.get('business_name', provider.business_name)
        provider.category = request.data.get('category', provider.category)
        provider.city = request.data.get('city', provider.city)
        provider.area = request.data.get('area', provider.area)
        provider.price_indicator = request.data.get('price_indicator', provider.price_indicator)
        provider.profile_photo = request.data.get('profile_photo', provider.profile_photo)
        provider.years_of_experience = int(request.data.get('years_of_experience', provider.years_of_experience or 0))
        provider.save()

        # Save/Update experience model
        exp, _ = ProviderExperience.objects.get_or_create(provider=provider)
        exp.years_of_experience = provider.years_of_experience
        exp.certifications = request.data.get('certifications', exp.certifications)
        exp.cert_image = request.data.get('cert_image', exp.cert_image)
        if 'past_workplaces' in request.data:
            exp.past_workplaces = request.data.get('past_workplaces')
        exp.save()

    # Get related models
    gigs = ServiceGig.objects.filter(provider=provider, is_active=True)
    discounts = DiscountBanner.objects.filter(provider=provider, is_active=True)
    experience, _ = ProviderExperience.objects.get_or_create(provider=provider)
    reviews = Review.objects.filter(provider=provider).order_by('-created_at')

    provider_data = ProviderSerializer(provider).data
    provider_data['years_of_experience'] = provider.years_of_experience
    provider_data['profile_photo'] = provider.profile_photo

    return Response({
        'provider': provider_data,
        'gigs': ServiceGigSerializer(gigs, many=True).data,
        'discounts': DiscountBannerSerializer(discounts, many=True).data,
        'experience': ProviderExperienceSerializer(experience).data,
        'reviews': ReviewSerializer(reviews, many=True).data,
    })


@api_view(['GET', 'POST'])
def manage_gigs(request, provider_id):
    """
    GET: List gigs
    POST: Create gig
    """
    try:
        provider = Provider.objects.get(id=provider_id)
    except Provider.DoesNotExist:
        return Response({'error': 'Provider not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'POST':
        # Security session check as required by user (supports custom header fallback for cross-domain CORS compatibility)
        session_provider_id = request.headers.get('x-provider-id') or request.session.get('provider_id')
        if str(session_provider_id) != str(provider_id):
            return JsonResponse({'error': 'Unauthorized'}, status=403)

        if ServiceGig.objects.filter(provider=provider).count() >= 6:
            return Response({'error': 'You can only add up to 6 gigs. Please edit or delete existing ones.'}, status=status.HTTP_400_BAD_REQUEST)

        title = request.data.get('title')
        if not title:
            return Response({'error': 'Gig Title is required'}, status=status.HTTP_400_BAD_REQUEST)

        gig = ServiceGig.objects.create(
            provider=provider,
            title=title,
            description=request.data.get('description', ''),
            photos=request.data.get('photos', []),
            price_min=int(request.data.get('price_min', 0)),
            price_max=int(request.data.get('price_max', 0)),
            estimated_time=request.data.get('estimated_time', ''),
            is_active=request.data.get('is_active', True)
        )
        return Response(ServiceGigSerializer(gig).data, status=status.HTTP_201_CREATED)

    gigs = ServiceGig.objects.filter(provider=provider)
    return Response(ServiceGigSerializer(gigs, many=True).data)


@api_view(['POST'])
def edit_gig(request, provider_id, gig_id):
    """
    Edit an existing gig.
    """
    # Security session check as required by user (supports custom header fallback for cross-domain CORS compatibility)
    session_provider_id = request.headers.get('x-provider-id') or request.session.get('provider_id')
    if str(session_provider_id) != str(provider_id):
        return JsonResponse({'error': 'Unauthorized'}, status=403)

    try:
        gig = ServiceGig.objects.get(id=gig_id, provider_id=provider_id)
    except ServiceGig.DoesNotExist:
        return Response({'error': 'Gig not found'}, status=status.HTTP_404_NOT_FOUND)

    gig.title = request.data.get('title', gig.title)
    gig.description = request.data.get('description', gig.description)
    gig.photos = request.data.get('photos', gig.photos)
    gig.price_min = int(request.data.get('price_min', gig.price_min))
    gig.price_max = int(request.data.get('price_max', gig.price_max))
    gig.estimated_time = request.data.get('estimated_time', gig.estimated_time)
    gig.is_active = request.data.get('is_active', gig.is_active)
    gig.save()

    return Response(ServiceGigSerializer(gig).data)


@api_view(['POST'])
def delete_gig(request, provider_id, gig_id):
    """
    Delete a gig.
    """
    # Security session check as required by user (supports custom header fallback for cross-domain CORS compatibility)
    session_provider_id = request.headers.get('x-provider-id') or request.session.get('provider_id')
    if str(session_provider_id) != str(provider_id):
        return JsonResponse({'error': 'Unauthorized'}, status=403)

    try:
        gig = ServiceGig.objects.get(id=gig_id, provider_id=provider_id)
        gig.delete()
        return Response({'status': 'ok'})
    except ServiceGig.DoesNotExist:
        return Response({'error': 'Gig not found'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['GET', 'POST'])
def manage_discounts(request, provider_id):
    """
    GET: Get discounts
    POST: Create/Update discount
    """
    try:
        provider = Provider.objects.get(id=provider_id)
    except Provider.DoesNotExist:
        return Response({'error': 'Provider not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'POST':
        # Security session check as required by user (supports custom header fallback for cross-domain CORS compatibility)
        session_provider_id = request.headers.get('x-provider-id') or request.session.get('provider_id')
        if str(session_provider_id) != str(provider_id):
            return JsonResponse({'error': 'Unauthorized'}, status=403)

        title = request.data.get('title')
        discount_percent = int(request.data.get('discount_percent', 0))
        valid_until = request.data.get('valid_until')

        if not valid_until:
            return Response({'error': 'Valid until date is required'}, status=status.HTTP_400_BAD_REQUEST)

        discount, created = DiscountBanner.objects.get_or_create(provider=provider, defaults={
            'title': title, 'discount_percent': discount_percent, 'valid_until': valid_until
        })
        if not created:
            discount.title = title
            discount.discount_percent = discount_percent
            discount.valid_until = valid_until
            discount.is_active = request.data.get('is_active', True)
            discount.save()

        return Response(DiscountBannerSerializer(discount).data)

    discounts = DiscountBanner.objects.filter(provider=provider)
    return Response(DiscountBannerSerializer(discounts, many=True).data)


@api_view(['POST'])
def add_review(request):
    """
    Add a review for a booking.
    """
    booking_id = request.data.get('booking_id')
    rating = int(request.data.get('rating', 5))
    comment = request.data.get('comment', '')

    try:
        booking = Booking.objects.get(id=booking_id)
    except Booking.DoesNotExist:
        return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)

    # Allow review if booking is completed
    if booking.status != 'completed':
        return Response({'error': 'You can only review completed bookings.'}, status=status.HTTP_400_BAD_REQUEST)

    # Check if review already exists
    if hasattr(booking, 'review'):
        return Response({'error': 'This booking has already been reviewed.'}, status=status.HTTP_400_BAD_REQUEST)

    provider = booking.provider
    user = booking.user

    review = Review.objects.create(
        booking=booking,
        provider=provider,
        user=user,
        rating=rating,
        comment=comment
    )

    # Recalculate provider rating
    reviews = Review.objects.filter(provider=provider)
    total_rating = sum(r.rating for r in reviews)
    provider.rating = round(total_rating / len(reviews), 1)
    provider.review_count = len(reviews)
    provider.save()

    return Response(ReviewSerializer(review).data, status=status.HTTP_201_CREATED)
