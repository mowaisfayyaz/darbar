import os
from api.models import Provider, AgentLog, SystemSetting, Booking
from agents.apify_service import trigger_apify_search

def discover_providers(intent_data: dict, booking_id=None):
    """
    Takes structured intent data.
    Queries Supabase providers table.
    Filters by service_type, area, and availability.
    Returns a list of candidate providers with their details.
    """
    agent_name = "Discovery Agent"
    service_type = intent_data.get('service_type', '')
    location = intent_data.get('location', '')
    action_taken = f"Discovering providers for {service_type} in {location}"

    # 1. Retrieve User Context
    user_apify_enabled = False
    if booking_id:
        try:
            booking = Booking.objects.get(id=booking_id)
            user_apify_enabled = booking.user.is_apify_enabled
        except Exception:
            pass

    # 2. Check Global Admin Setting
    setting, _ = SystemSetting.objects.get_or_create(key='apify_enabled_by_admin', defaults={'value': 'true'})
    admin_apify_enabled = (setting.value.lower() == 'true')

    # 3. Execute Apify FIRST if both are enabled
    if admin_apify_enabled and user_apify_enabled:
        try:
            action_taken_apify = f"Triggering Apify to find {service_type} in {location or 'Islamabad'}"
            if booking_id:
                AgentLog.objects.create(
                    booking_id=booking_id,
                    agent_name=agent_name,
                    action_taken=action_taken_apify,
                    reasoning="Both Admin and User Apify settings are enabled. Fetching live data from Google Maps."
                )
            # We trigger Apify. It saves the results to the local DB.
            trigger_apify_search(service_type, location or "Islamabad")
        except Exception as e:
            print(f"Failed to run Apify integration: {e}")

    # 4. Resolve location against DB
    city_filter = None
    if location and location.lower() not in ('unknown', ''):
        loc_clean = location.strip()
        
        city_matches = Provider.objects.filter(city__icontains=loc_clean)
        if city_matches.exists():
            city_filter = city_matches.first().city
        else:
            area_matches = Provider.objects.filter(area__icontains=loc_clean)
            if area_matches.exists():
                city_filter = area_matches.first().city
            else:
                if booking_id:
                    AgentLog.objects.create(
                        booking_id=booking_id,
                        agent_name=agent_name,
                        action_taken=action_taken,
                        reasoning=f"No matching service coverage found in our database for location '{location}'."
                    )
                return []
    else:
        city_filter = "Islamabad"
    
    # 5. Query Database for Candidates
    providers = Provider.objects.filter(
        category__icontains=service_type,
        city__icontains=city_filter,
        is_available=True
    )
    
    if location and location.lower() not in ('unknown', ''):
        area_providers = providers.filter(area__icontains=location)
        if area_providers.exists():
            providers = area_providers
    
    candidate_list = list(providers.values(
        'id', 'business_name', 'phone', 'rating', 
        'review_count', 'area', 'city', 'lat', 'lng', 'category'
    ))
    
    # 6. Build reasoning and log
    if candidate_list:
        names = ', '.join([c['business_name'] for c in candidate_list[:5]])
        reasoning = f"Found {len(candidate_list)} providers matching '{service_type}' in {city_filter}. Top candidates: {names}."
    else:
        reasoning = f"No providers found matching '{service_type}' in '{location}' ({city_filter}). The search may need broader criteria."
    
    if booking_id:
        AgentLog.objects.create(
            booking_id=booking_id,
            agent_name=agent_name,
            action_taken=action_taken,
            reasoning=reasoning
        )
        
    return candidate_list
