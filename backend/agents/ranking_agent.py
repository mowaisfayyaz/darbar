from api.models import AgentLog

def rank_candidates(candidates: list, target_location: str, booking_id=None):
    """
    Ranks candidates using a scoring formula:
    - distance score (40%)
    - rating score (35%)
    - jobs done / review count score (25%)
    """
    agent_name = "Ranking Agent"
    action_taken = "Ranking discovered candidates"
    
    ranked = []
    for cand in candidates:
        # Mock calculation
        score = (cand.get('rating', 0) * 0.35) + (min(cand.get('review_count', 0), 100) / 100 * 0.25)
        # Distance calculation via Google Maps API should be added here
        cand['total_score'] = score
        ranked.append(cand)
        
    ranked.sort(key=lambda x: x.get('total_score', 0), reverse=True)
    
    if booking_id:
        AgentLog.objects.create(
            agent_name=agent_name,
            action_taken=action_taken,
            reasoning=f"Ranked {len(ranked)} candidates based on scoring formula."
        )
        
    return ranked
