import os
import re
import uuid
from apify_client import ApifyClient
from api.models import Provider

# Common Pakistan cities for fallback city detection
PAKISTAN_CITIES = [
    "karachi", "lahore", "islamabad", "rawalpindi", "faisalabad",
    "multan", "peshawar", "quetta", "sialkot", "gujranwala",
    "hyderabad", "bahawalpur", "sargodha", "sukkur", "abbottabad"
]

def extract_city_from_address(address: str, location_hint: str = "") -> str:
    """
    Tries to extract a city name from a full address string.
    Falls back to checking the location_hint for known Pakistan cities.
    """
    if address:
        addr_lower = address.lower()
        for city in PAKISTAN_CITIES:
            if city in addr_lower:
                return city.capitalize()
    
    # Fallback: check if the location hint contains a known city
    if location_hint:
        loc_lower = location_hint.lower()
        for city in PAKISTAN_CITIES:
            if city in loc_lower:
                return city.capitalize()

    return location_hint  # Last resort: use whatever was passed as location

def trigger_apify_search(category, location):
    """
    Triggers the Apify Actor to search for providers on Google Maps.
    Saves the new providers to the local database.
    """
    token = os.getenv("APIFY_API_TOKEN", "").strip().strip('"').strip("'")
    if not token or token == "your_apify_api_token_here":
        print("[Apify] API token is not set or is placeholder. Skipping.")
        return []

    client = ApifyClient(token)
    
    search_term = f"{category} {location}, pakistan"
    
    run_input = {
        "country": "US",
        "language": "en",
        "maxItems": 5,
        "searchTerms": [search_term]
    }
    
    print(f"[Apify] Starting actor run for: '{search_term}'")
    
    try:
        run = client.actor("jco0GaQY70XZcwqDI").call(run_input=run_input)
        items = client.dataset(run["defaultDatasetId"]).iterate_items()
        
        new_providers = []
        for item in items:
            place_id = item.get("placeId")
            if not place_id:
                continue
                
            # Skip if already in DB
            if Provider.objects.filter(place_id=place_id).exists():
                continue

            # city can be null in Apify results — extract from address as fallback
            city_raw = item.get("city")
            if not city_raw:
                city_raw = extract_city_from_address(
                    item.get("address", ""),
                    location_hint=location
                )
            
            business_name = item.get("title") or "Unknown Business"
            cat = item.get("categoryName") or category
            
            provider = Provider(
                id=uuid.uuid4(),
                business_name=business_name,
                category=cat,
                phone=item.get("phone") or "",
                website=item.get("website") or "",
                rating=float(item.get("totalScore") or 0.0),
                review_count=item.get("reviewsCount") or 0,
                city=city_raw,
                area=item.get("neighborhood") or "",
                address=item.get("address") or "",
                google_maps_url=item.get("url") or "",
                place_id=place_id,
                price_indicator=item.get("price") or "",
                is_available=True,
                is_apify_enabled=True,
                password="apify_scraped_no_login",
            )
            provider.save()
            new_providers.append(provider)
            
        print(f"[Apify] Done. {len(new_providers)} new providers saved to DB.")
        return new_providers
    except Exception as e:
        print(f"[Apify] Error: {e}")
        return []
