from django.http import HttpResponse
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth.hashers import make_password, check_password
from django.db.models import Q
from .models import User, Provider, Booking, AgentLog, Notification
from .serializers import ProviderSerializer, BookingSerializer, AgentLogSerializer

from agents.intent_agent import extract_intent
from agents.discovery_agent import discover_providers
from agents.ranking_agent import rank_candidates
from agents.decision_agent import make_decision
from agents.booking_agent import attempt_booking
from agents.followup_agent import schedule_reminders
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

    if not identifier or not password:
        return Response({'error': 'Email/phone and password are required.'}, status=status.HTTP_400_BAD_REQUEST)

    if role == 'provider':
        try:
            provider = Provider.objects.get(Q(phone=identifier) | Q(email=identifier))
            if not check_password(password, provider.password):
                return Response({'error': 'Incorrect password.'}, status=status.HTTP_401_UNAUTHORIZED)
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
    notifications = Notification.objects.filter(user_id=user_id).order_by('-created_at')[:20]
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
    bookings = Booking.objects.filter(user_id=user_id).order_by('-created_at')
    serializer = BookingSerializer(bookings, many=True)
    return Response(serializer.data)


@api_view(['POST'])
def process_request(request):
    """
    Main orchestrator entry point.
    Expects: {"user_id": "uuid", "text": "Mujhe kal subah G-13 mein AC technician chahiye"}
    """
    user_id = request.data.get('user_id')
    raw_text = request.data.get('text')

    if not user_id or not raw_text:
        return Response({"error": "user_id and text are required"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)

    booking_id_human = f"BK-2026-{get_random_string(6).upper()}"
    booking = Booking.objects.create(
        booking_id=booking_id_human,
        user=user,
        service_type="Unknown",
        location="Unknown"
    )

    try:
        intent_data = extract_intent(raw_text, booking_id=booking.id)
        
        if intent_data.get('needs_clarification', False):
            booking.status = 'cancelled'
            booking.service_type = intent_data.get('service_type', 'Unknown')
            booking.location = intent_data.get('location', 'Unknown')
            booking.save()
            return Response({
                "status": "clarification",
                "booking_id": str(booking.id),
                "message": intent_data.get('reply_message', 'Please provide service type, location, and time details.')
            }, status=status.HTTP_200_OK)

        booking.service_type = intent_data.get('service_type', 'Unknown')
        booking.location = intent_data.get('location', 'Unknown')
        booking.save()

        candidates = discover_providers(intent_data, booking_id=booking.id)
        ranked_candidates = rank_candidates(candidates, target_location=booking.location, booking_id=booking.id)

        language = intent_data.get('language_detected', 'en')
        selected_provider_data, reasoning = make_decision(ranked_candidates, booking_id=booking.id, language=language)

        if not selected_provider_data:
            booking.status = 'cancelled'
            booking.save()
            return Response({"status": "failed", "reason": reasoning, "booking_id": str(booking.id)})

        provider = Provider.objects.get(id=selected_provider_data['id'])
        booking.provider = provider
        booking.save()

        attempt = attempt_booking(booking_obj=booking, provider_obj=provider)
        schedule_reminders(booking)

        return Response({
            "status": "processing",
            "booking_id": str(booking.id),
            "human_booking_id": booking.booking_id,
            "message": reasoning,
            "provider_name": provider.business_name,
            "provider_rating": provider.rating,
        })

    except Exception as e:
        AgentLog.objects.create(
            booking=booking,
            agent_name="System",
            action_taken="Error processing request",
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
        return Response({'status': booking.status, 'booking_id': str(booking.id)})
    except Booking.DoesNotExist:
        return Response(status=status.HTTP_404_NOT_FOUND)


@api_view(['GET'])
def google_auth_url(request):
    try:
        url = get_authorization_url()
        return Response({'url': url})
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
def google_auth_callback(request):
    code = request.GET.get('code')
    if not code:
        return HttpResponse("Missing authorization code", status=400)
    try:
        email = exchange_code_for_tokens(code)
        success_html = f"""
        <html>
        <body style="font-family: sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; background: #f5f5f5; margin: 0;">
            <div style="text-align: center; padding: 2.5rem; background: white; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.08); max-width: 400px; width: 90%;">
                <div style="font-size: 4rem; color: #4CAF50; margin-bottom: 1rem;">✔</div>
                <h1 style="color: #2c3e50; margin: 0 0 0.5rem 0; font-size: 1.6rem;">Google Account Linked!</h1>
                <p style="color: #7f8c8d; font-size: 1rem; margin-bottom: 2rem; line-height: 1.5;">
                    Darbar has successfully linked to <strong>{email}</strong>.
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
    linked, email = is_google_linked()
    return Response({'linked': linked, 'email': email})


@api_view(['POST'])
def google_disconnect(request):
    success = disconnect_google()
    return Response({'success': success})

