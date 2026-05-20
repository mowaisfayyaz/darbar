import os
from api.models import Provider, AgentLog

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
    
    # Dynamically resolve city based on location parameter
    city_filter = None
    
    if location and location.lower() not in ('unknown', ''):
        loc_clean = location.strip()
        
        # 1. Direct city check
        city_matches = Provider.objects.filter(city__icontains=loc_clean)
        if city_matches.exists():
            city_filter = city_matches.first().city
        else:
            # 2. Area/neighborhood check to infer the city
            area_matches = Provider.objects.filter(area__icontains=loc_clean)
            if area_matches.exists():
                city_filter = area_matches.first().city
            else:
                # The user explicitly requested an area/city that we have no coverage for
                # Do not cross-match from another city! Return empty candidates list immediately.
                if booking_id:
                    AgentLog.objects.create(
                        booking_id=booking_id,
                        agent_name=agent_name,
                        action_taken=action_taken,
                        reasoning=f"No matching service coverage found in our database for location '{location}'."
                    )
                return []
    else:
        # Default fallback city if location is unspecified in the request
        city_filter = "Islamabad"
    
    # Query Database — filter by category, resolved city, and availability
    providers = Provider.objects.filter(
        category__icontains=service_type,
        city__icontains=city_filter,
        is_available=True
    )
    
    # Apply area filter if a specific area was provided and matched
    if location and location.lower() not in ('unknown', ''):
        area_providers = providers.filter(area__icontains=location)
        if area_providers.exists():
            providers = area_providers
        # If no providers in the exact area, keep the broader city-wide results for this city only
    
    candidate_list = list(providers.values(
        'id', 'business_name', 'phone', 'rating', 
        'review_count', 'area', 'city', 'lat', 'lng', 'category'
    ))
    
    # Build detailed reasoning for the agent log
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
