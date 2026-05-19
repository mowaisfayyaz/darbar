from api.models import AgentLog

def make_decision(ranked_candidates: list, booking_id=None, language="en"):
    """
    Picks the #1 ranked candidate automatically.
    Generates human readable reasoning in the user's language (English or Roman Urdu).
    """
    agent_name = "Decision Agent"
    
    if not ranked_candidates:
        reasoning = "No providers available in your area right now."
        if language == "ur-roman":
            reasoning = "Is waqt aapke area mein koi provider available nahi hai."
        
        if booking_id:
            AgentLog.objects.create(
                booking_id=booking_id,
                agent_name=agent_name,
                action_taken="No provider available — decision failed",
                reasoning=reasoning
            )
        return None, reasoning
        
    selected = ranked_candidates[0]
    
    # Build detailed reasoning
    name = selected.get('business_name', 'Unknown')
    rating = selected.get('rating', 0)
    reviews = selected.get('review_count', 0)
    dist = selected.get('distance_km')
    score = selected.get('total_score', 0)
    area = selected.get('area', '')
    
    if language == "ur-roman":
        dist_part = f", {dist}km door" if dist else ""
        reasoning_text = (
            f"Humne {name} ko select kiya kyunke inki rating {rating}/5 hai"
            f"{dist_part}, aur {reviews} logon ne inhe review kiya hai. "
            f"Yeh aapke area mein sabse behtareen provider hain."
        )
    else:
        dist_part = f", only {dist}km away" if dist else ""
        reasoning_text = (
            f"Selected {name} because they have the highest match score ({score}). "
            f"They are rated {rating}/5 with {reviews} verified reviews{dist_part}."
        )
    
    if area:
        if language == "ur-roman":
            reasoning_text += f" Yeh {area} mein hain."
        else:
            reasoning_text += f" Based in {area}."
    
    action_taken = f"Selected {name} as the best provider (score: {score})"
    
    if booking_id:
        AgentLog.objects.create(
            booking_id=booking_id,
            agent_name=agent_name,
            action_taken=action_taken,
            reasoning=reasoning_text
        )
        
    return selected, reasoning_text
