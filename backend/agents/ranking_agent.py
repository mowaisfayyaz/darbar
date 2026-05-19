import math
from api.models import AgentLog

# Mock coordinates for known Islamabad areas (for distance scoring)
AREA_COORDS = {
    'g-13': (33.6319, 72.9710),
    'g-14': (33.6250, 72.9600),
    'f-6':  (33.7290, 73.0690),
    'f-7':  (33.7210, 73.0580),
    'f-8':  (33.7130, 73.0470),
    'f-10': (33.6970, 73.0250),
    'f-11': (33.6890, 73.0140),
    'f-14': (33.6400, 72.9800),
    'e-11': (33.7100, 73.0300),
    'i-8':  (33.6900, 73.0700),
    'i-9':  (33.6800, 73.0600),
    'i-10': (33.6700, 73.0500),
    'i-14': (33.6500, 72.9900),
    'h-13': (33.6450, 73.0000),
}

def _get_area_coords(area_name: str):
    """Get mock coordinates for an area name."""
    if not area_name:
        return None
    key = area_name.strip().lower()
    return AREA_COORDS.get(key)

def _haversine_km(lat1, lon1, lat2, lon2):
    """Calculate distance between two points in km."""
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    c = 2 * math.asin(math.sqrt(a))
    return R * c

def rank_candidates(candidates: list, target_location: str, booking_id=None):
    """
    Ranks candidates using a weighted scoring formula:
    - Distance score  (40%) — closer is better
    - Rating score    (35%) — higher is better  
    - Jobs done score (25%) — more reviews is better
    """
    agent_name = "Ranking Agent"
    action_taken = f"Ranking {len(candidates)} candidates for location: {target_location}"
    
    target_coords = _get_area_coords(target_location)
    
    ranked = []
    for cand in candidates:
        # Rating score (0-1 scale, max rating = 5.0)
        rating_score = min(cand.get('rating', 0), 5.0) / 5.0
        
        # Review count score (0-1 scale, capped at 100 reviews)
        review_score = min(cand.get('review_count', 0), 100) / 100.0
        
        # Distance score (0-1 scale, closer = higher score)
        distance_km = None
        if target_coords:
            cand_lat = cand.get('lat')
            cand_lng = cand.get('lng')
            if cand_lat and cand_lng:
                distance_km = _haversine_km(target_coords[0], target_coords[1], cand_lat, cand_lng)
            else:
                # Use area name matching as fallback
                cand_area = cand.get('area', '')
                cand_coords = _get_area_coords(cand_area)
                if cand_coords:
                    distance_km = _haversine_km(target_coords[0], target_coords[1], cand_coords[0], cand_coords[1])
        
        if distance_km is not None:
            # Max useful distance = 20km, closer = higher score
            distance_score = max(0, 1.0 - (distance_km / 20.0))
        else:
            distance_score = 0.5  # Neutral if we can't calculate
        
        # Weighted total
        total_score = (distance_score * 0.40) + (rating_score * 0.35) + (review_score * 0.25)
        
        cand['total_score'] = round(total_score, 4)
        cand['distance_km'] = round(distance_km, 2) if distance_km is not None else None
        cand['distance_score'] = round(distance_score, 3)
        cand['rating_score'] = round(rating_score, 3)
        cand['review_score'] = round(review_score, 3)
        ranked.append(cand)
        
    ranked.sort(key=lambda x: x.get('total_score', 0), reverse=True)
    
    # Build detailed reasoning
    if ranked:
        top = ranked[0]
        dist_info = f"{top['distance_km']}km away" if top.get('distance_km') else "distance unknown"
        reasoning = (
            f"Ranked {len(ranked)} candidates. "
            f"Top candidate: {top.get('business_name')} "
            f"(Score: {top['total_score']}, Rating: {top.get('rating')}/5, "
            f"Reviews: {top.get('review_count')}, Distance: {dist_info}). "
            f"Formula: Distance(40%) + Rating(35%) + Reviews(25%)."
        )
    else:
        reasoning = "No candidates to rank."
    
    if booking_id:
        AgentLog.objects.create(
            booking_id=booking_id,
            agent_name=agent_name,
            action_taken=action_taken,
            reasoning=reasoning
        )
        
    return ranked
