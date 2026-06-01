import os
import uuid
from apify_client import ApifyClient
from api.models import Provider

def trigger_apify_search(category, location):
    """
    Triggers the Apify Actor to search for providers on Google Maps.
    Saves the new providers to the local database.
    """
    token = os.getenv("APIFY_API_TOKEN")
    if not token or token == "your_apify_api_token_here":
        print("Apify API token is not set.")
        return []

    client = ApifyClient(token)
    
    search_term = f"{category} {location}, pakistan"
    
    run_input = {
        "country": "US",
        "language": "en",
        "maxItems": 40,
        "searchTerms": [search_term]
    }
    
    print(f"Triggering Apify search for: {search_term}")
    
    try:
        run = client.actor("jco0GaQY70XZcwqDI").call(run_input=run_input)
        
        items = client.dataset(run["defaultDatasetId"]).iterate_items()
        
        new_providers = []
        for item in items:
            place_id = item.get("placeId")
            if not place_id:
                continue
                
            # Check if exists
            if Provider.objects.filter(place_id=place_id).exists():
                continue
                
            # Create new provider
            business_name = item.get("title") or "Unknown Business"
            
            # Map Apify category if available, otherwise use requested category
            cat = item.get("categoryName") or category
            
            provider = Provider(
                id=uuid.uuid4(),
                business_name=business_name,
                category=cat,
                phone=item.get("phone") or "",
                website=item.get("website") or "",
                rating=float(item.get("totalScore") or 0.0),
                review_count=item.get("reviewsCount") or 0,
                city=item.get("city") or location,
                area=item.get("neighborhood") or "",
                address=item.get("address") or "",
                google_maps_url=item.get("url") or "",
                place_id=place_id,
                price_indicator=item.get("price") or "",
                is_available=True,
                is_apify_enabled=True,
                password="apify_scraped_no_login", # Dummy password for scraped providers
            )
            provider.save()
            new_providers.append(provider)
            
        print(f"Apify search completed. Added {len(new_providers)} new providers.")
        return new_providers
    except Exception as e:
        print(f"Apify Error: {e}")
        return []
