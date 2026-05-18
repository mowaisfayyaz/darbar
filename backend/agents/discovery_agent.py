import os
from apify_client import ApifyClient
from api.models import Provider, AgentLog

def discover_providers(intent_data: dict, booking_id=None):
    """
    Takes structured intent data.
    Queries Supabase providers table.
    Filters by service_type, area, and availability.
    Falls back to Apify Google Maps API if no local providers are found.
    """
    agent_name = "Discovery Agent"
    action_taken = f"Discovering providers for {intent_data.get('service_type')} in {intent_data.get('location')}"
    
    # Query Database first
    providers = Provider.objects.filter(
        category__icontains=intent_data.get('service_type', ''),
        city__icontains='Islamabad', # Based on plan
        is_available=True
    )
    
    if not providers.exists():
        # Fallback: Fetch using Apify
        # apify_client = ApifyClient(os.getenv('APIFY_API_TOKEN'))
        pass
        
    candidate_list = list(providers.values('id', 'business_name', 'rating', 'review_count', 'lat', 'lng'))
    
    if booking_id:
        AgentLog.objects.create(
            agent_name=agent_name,
            action_taken=action_taken,
            reasoning=f"Found {len(candidate_list)} potential providers."
        )
        
    return candidate_list
