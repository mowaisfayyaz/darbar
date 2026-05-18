from api.models import AgentLog

def make_decision(ranked_candidates: list, booking_id=None, language="en"):
    """
    Picks the #1 ranked candidate automatically.
    Generates human readable reasoning in the user's language.
    """
    agent_name = "Decision Agent"
    
    if not ranked_candidates:
        return None, "No providers available."
        
    selected_provider = ranked_candidates[0]
    
    # Generate reasoning in appropriate language using Minimax (Mocked)
    reasoning_text = f"Selected {selected_provider.get('business_name')} because they have a high rating of {selected_provider.get('rating')} and {selected_provider.get('review_count')} reviews."
    
    if language == "ur-roman":
        reasoning_text = f"Humne {selected_provider.get('business_name')} ko select kiya kyunke inki rating {selected_provider.get('rating')} hai."
        
    action_taken = f"Selected {selected_provider.get('business_name')} as the best provider."
    
    if booking_id:
        AgentLog.objects.create(
            agent_name=agent_name,
            action_taken=action_taken,
            reasoning=reasoning_text
        )
        
    return selected_provider, reasoning_text
