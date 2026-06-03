import os
from api.models import Provider, AgentLog, SystemSetting, User
from agents.apify_service import trigger_apify_search

def discover_providers(intent_data: dict, user_id=None, booking_id=None):
    """
    Takes structured intent data.
    Checks user & admin Apify settings, triggers live scrape if enabled,
    then queries local DB for candidates.
    Returns a list of candidate providers with their details.
    """
    agent_name = "Discovery Agent"
    service_type = intent_data.get('service_type', '')
    location = intent_data.get('location', '')
    action_taken = f"Discovering providers for {service_type} in {location}"

    # 1. Retrieve User Apify setting directly via user_id
    #    (booking_id doesn't exist yet at this stage of the pipeline)
    user_apify_enabled = False
    if user_id:
        try:
            user = User.objects.get(id=user_id)
            user_apify_enabled = user.is_apify_enabled
        except Exception:
            pass

    # 2. Check Global Admin Setting
    setting, _ = SystemSetting.objects.get_or_create(key='apify_enabled_by_admin', defaults={'value': 'true'})
    admin_apify_enabled = (setting.value.lower() == 'true')

    # 3. Execute Apify FIRST (before location resolver) if both toggles are ON.
    #    Apify saves scraped providers into the local DB, so when the location
    #    resolver runs next it will find the newly added records.
    apify_triggered_now = False
    if admin_apify_enabled or user_apify_enabled:
        try:
            print(f"[Apify] Triggering search: {service_type} in {location or 'Islamabad'} synchronously")
            trigger_apify_search(service_type, location or "Islamabad")
            apify_triggered_now = True
            print(f"[Apify] Search completed successfully.")
        except Exception as e:
            print(f"[Apify] Failed: {e}")

    # 4. Resolve location against DB
    #    If Apify ran above, newly scraped providers are now in DB, so this
    #    location check will find them.
    city_filter = None
    if location and location.lower() not in ('unknown', ''):
        loc_clean = location.strip()

        # Try direct city match first
        city_matches = Provider.objects.filter(city__icontains=loc_clean)
        if city_matches.exists():
            city_filter = city_matches.first().city
        else:
            # Try area/neighborhood match to infer the city
            area_matches = Provider.objects.filter(area__icontains=loc_clean)
            if area_matches.exists():
                city_filter = area_matches.first().city
            else:
                # No DB coverage for this location at all — return empty
                print(f"[Discovery] No DB coverage for location '{location}'. Returning empty.")
                return [], apify_triggered_now
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
        
    return candidate_list, apify_triggered_now
