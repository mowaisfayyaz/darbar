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
    
    # Query Database — filter by category and availability
    providers = Provider.objects.filter(
        category__icontains=service_type,
        city__icontains='Islamabad',
        is_available=True
    )
    
    # Apply area filter if a specific location was provided
    if location and location.lower() not in ('unknown', ''):
        area_providers = providers.filter(area__icontains=location)
        if area_providers.exists():
            providers = area_providers
        # If no providers in the exact area, keep the broader city-wide results
    
    candidate_list = list(providers.values(
        'id', 'business_name', 'phone', 'rating', 
        'review_count', 'area', 'city', 'lat', 'lng', 'category'
    ))
    
    # Build detailed reasoning for the agent log
    if candidate_list:
        names = ', '.join([c['business_name'] for c in candidate_list[:5]])
        reasoning = f"Found {len(candidate_list)} providers matching '{service_type}' in Islamabad. Top candidates: {names}."
    else:
        reasoning = f"No providers found matching '{service_type}' in '{location}'. The search may need broader criteria."
    
    if booking_id:
        AgentLog.objects.create(
            booking_id=booking_id,
            agent_name=agent_name,
            action_taken=action_taken,
            reasoning=reasoning
        )
        
    return candidate_list
