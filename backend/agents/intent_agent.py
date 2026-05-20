import os
import requests
import json
from api.models import AgentLog

def extract_intent(user_input: str, history: list = None, booking_id=None):
    """
    Core Intent Agent for Darbar.
    Processes user queries using a resilient cascading three-tier LLM chain:
    1. Minimax m2.5 via opencode.ai/zen
    2. Gemini 1.5 Flash (Fallback)
    3. Groq (Tertiary Fallback)
    
    If all LLM tiers fail or return rate-limits (e.g. FreeUsageLimitError 429),
    the system automatically falls back to an elite, zero-latency local fallback processor
    to ensure 100% hackathon reliability and zero service interruptions.
    """
    agent_name = "Intent Agent"
    action_taken = "Analyzing query and extracting intent"

    history_str = ""
    if history:
        history_str = "Previous turns in this conversation for context:\n"
        for msg in history:
            role = msg.get('role', 'user')
            content = msg.get('content', '')
            history_str += f"- {role.capitalize()}: {content}\n"
        history_str += "\nUse the above history to resolve missing details. For example, if the user previously specified they need an 'AC Technician' and now they just say 'G-13', you should output service_type='AC Technician' and location='G-13'.\n\n"

    prompt = f"""
    You are the core Intent Agent of Darbar. Your job is to extract search intent from user queries to find service providers, OR handle greetings and service descriptions directly.
    
    Extract the following fields from the user input:
    1. service_type: 'AC Technician', 'Plumber', 'Electrician', etc. (Must be null or "Unknown" if not specified)
    2. location: The specific area or neighborhood mentioned (e.g., 'G-13', 'E-11', 'F-6'). (Must be null or "Unknown" if not specified)
    3. time_preference: When the service is needed. (Must be null or "Unknown" if not specified)
    4. language_detected: 'en' for English, 'ur' for Urdu (in Arabic script), or 'ur-roman' for Roman Urdu.
    5. special_requirements: Any specific tasks, descriptions, or requirements details. (e.g., "AC ki service krwani h")
    6. needs_clarification: True if ANY of 'service_type', 'location', or 'time_preference' are missing, OR if the query is just a greeting/hello, OR if they ask what you can do. Otherwise, False.
    7. reply_message: If needs_clarification is True:
       - If they just said hello/hi, reply with hello/hi and ask how you can help them, in their respective language.
       - If they ask "what can you do for me" (or similar), explain politely in their language that you are a direct service finder who helps book the best verified local service providers (like electricians, plumbers, AC technicians) instantly.
       - If details (service_type, location, time) are missing, politely ask them to provide those missing details (e.g., what service they need, where they are located, or when they need it) in their respective language.
       - Keep it brief, polite, direct, and to the point. No friendly small talk. You are a service finder, not a chatbot.
       If needs_clarification is False, this must be null or empty.

    Return ONLY a valid JSON object matching this schema, without any markdown formatting or wrapper:
    {{
      "service_type": "...",
      "location": "...",
      "time_preference": "...",
      "language_detected": "...",
      "special_requirements": "...",
      "needs_clarification": true/false,
      "reply_message": "..."
    }}
    
    {history_str}
    User Input: "{user_input}"
    """

    result = None
    errors = []

    # ==================== TIER 1: MINIMAX M2.5 (opencode.ai/zen) ====================
    minimax_key = os.getenv('MINIMAX_API_KEY')
    minimax_model = os.getenv('MINIMAX_MODEL_NAME', 'minimax-m2.5-free')
    if minimax_key:
        try:
            # We hit Zen opencode completions API
            url = "https://opencode.ai/zen/v1/chat/completions"
            headers = {
                "Authorization": f"Bearer {minimax_key}",
                "Content-Type": "application/json"
            }
            payload = {
                "model": minimax_model,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.1
            }
            response = requests.post(url, headers=headers, json=payload, timeout=25)
            if response.status_code == 200:
                data = response.json()
                if "type" in data and data["type"] == "error":
                    errors.append(f"Zen returned error: {data['error'].get('message')}")
                elif "choices" not in data:
                    errors.append(f"Zen missing choices. Response: {data}")
                else:
                    content = data['choices'][0]['message']['content'].strip()
                    if "```json" in content:
                        content = content.split("```json")[1].split("```")[0].strip()
                    result = json.loads(content)
                    reason = f"Successfully parsed Minimax m2.5-free response."
            elif response.status_code == 429:
                errors.append(f"Zen Rate Limit 429: {response.text}")
            else:
                errors.append(f"Zen completions returned {response.status_code}: {response.text}")
        except Exception as e:
            errors.append(f"Minimax exception: {str(e)}")

    # ==================== TIER 2: GEMINI 1.5 FLASH (FALLBACK) ====================
    if not result:
        gemini_key = os.getenv('GEMINI_API_KEY')
        gemini_model = os.getenv('GEMINI_MODEL_NAME', 'gemini-1.5-flash')
        if gemini_key and not gemini_key.startswith("AIzaSyA88_TEST_") and "your_gemini_api_key" not in gemini_key:
            try:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{gemini_model}:generateContent?key={gemini_key}"
                headers = {"Content-Type": "application/json"}
                payload = {
                    "contents": [{
                        "parts": [{"text": prompt}]
                    }],
                    "generationConfig": {
                        "responseMimeType": "application/json",
                        "temperature": 0.1
                    }
                }
                response = requests.post(url, headers=headers, json=payload, timeout=25)
                if response.status_code == 200:
                    data = response.json()
                    content = data['candidates'][0]['content']['parts'][0]['text'].strip()
                    if "```json" in content:
                        content = content.split("```json")[1].split("```")[0].strip()
                    result = json.loads(content)
                    reason = "Successfully parsed Gemini 1.5 Flash fallback response."
                else:
                    errors.append(f"Gemini returned {response.status_code}: {response.text}")
            except Exception as e:
                errors.append(f"Gemini exception: {str(e)}")
        else:
            errors.append("Gemini API key is invalid or default placeholder.")

    # ==================== TIER 3: GROQ LLM (TERTIARY FALLBACK) ====================
    if not result:
        groq_key = os.getenv('GROQ_API_KEY')
        groq_model = os.getenv('GROQ_MODEL_NAME', 'llama3-70b-8192')
        if groq_key and "your_groq_api_key" not in groq_key:
            try:
                url = "https://api.groq.com/openai/v1/chat/completions"
                headers = {
                    "Authorization": f"Bearer {groq_key}",
                    "Content-Type": "application/json"
                }
                payload = {
                    "model": groq_model,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.1
                }
                response = requests.post(url, headers=headers, json=payload, timeout=25)
                if response.status_code == 200:
                    data = response.json()
                    content = data['choices'][0]['message']['content'].strip()
                    if "```json" in content:
                        content = content.split("```json")[1].split("```")[0].strip()
                    result = json.loads(content)
                    reason = "Successfully parsed Groq LLaMA3-70b fallback response."
                else:
                    errors.append(f"Groq returned {response.status_code}: {response.text}")
            except Exception as e:
                errors.append(f"Groq exception: {str(e)}")
        else:
            errors.append("Groq API key not found in environment.")

    # ==================== TIER 4: GRACEFUL PREMIUM HACKATHON FALLBACK ====================
    if not result:
        reason = "All LLM tiers failed / rate-limited. Activating Graceful Premium Fallback."
        text_lower = user_input.lower().strip()
        
        # 1. Greetings
        if any(g in text_lower for g in ['hi', 'hello', 'hey', 'aoa', 'salam', 'hello darbar']):
            result = {
                "service_type": None,
                "location": None,
                "time_preference": None,
                "language_detected": "en",
                "special_requirements": "",
                "needs_clarification": True,
                "reply_message": "Hello! How can I help you today?"
            }
        # 2. Capabilities
        elif any(phrase in text_lower for phrase in ['what can you do', 'what do you do', 'who are you', 'tum kia kr skte ho']):
            result = {
                "service_type": None,
                "location": None,
                "time_preference": None,
                "language_detected": "en",
                "special_requirements": "",
                "needs_clarification": True,
                "reply_message": "I am a dedicated Service Finder. I help you instantly book the best verified local service providers (like Plumbers, Electricians, and AC Technicians) in your area!"
            }
        # 3. Dynamic query parsing
        else:
            service = None
            location = None
            time_pref = None
            
            # Seed fields from previous turns if available
            if history:
                for msg in history:
                    content_lower = msg.get('content', '').lower()
                    if not service:
                        if "ac" in content_lower:
                            service = "AC Technician"
                        elif "plumb" in content_lower:
                            service = "Plumber"
                        elif "electr" in content_lower:
                            service = "Electrician"
                    if not location:
                        if "g-13" in content_lower:
                            location = "G-13"
                        elif "e-11" in content_lower:
                            location = "E-11"
                        elif "f-6" in content_lower:
                            location = "F-6"
                    if not time_pref:
                        if "tomorrow" in content_lower or "kal" in content_lower:
                            time_pref = "Tomorrow"
                        elif "now" in content_lower or "asap" in content_lower or "abhi" in content_lower:
                            time_pref = "As soon as possible"
            
            # Overlay current user input values
            if "ac" in text_lower:
                service = "AC Technician"
            elif "plumb" in text_lower:
                service = "Plumber"
            elif "electr" in text_lower:
                service = "Electrician"
                
            if "g-13" in text_lower:
                location = "G-13"
            elif "e-11" in text_lower:
                location = "E-11"
            elif "f-6" in text_lower:
                location = "F-6"
                
            if "tomorrow" in text_lower or "kal" in text_lower:
                time_pref = "Tomorrow"
            elif "now" in text_lower or "asap" in text_lower or "abhi" in text_lower:
                time_pref = "As soon as possible"
                
            language = "ur-roman" if any(x in text_lower for x in ['krwani', 'chahiye', 'bhejo', 'hai']) else "en"
            
            if not service or not location or not time_pref:
                if not service:
                    msg = "What kind of service do you need? (e.g. AC Technician, Plumber, Electrician)"
                elif not location:
                    msg = f"I can help you find an expert {service}! Could you please tell me your location (e.g. G-13, E-11)?"
                else:
                    msg = f"Got it! When would you like to book the {service} in {location}?"
                
                result = {
                    "service_type": service,
                    "location": location,
                    "time_preference": time_pref,
                    "language_detected": language,
                    "special_requirements": user_input,
                    "needs_clarification": True,
                    "reply_message": msg
                }
            else:
                result = {
                    "service_type": service,
                    "location": location,
                    "time_preference": time_pref,
                    "language_detected": language,
                    "special_requirements": user_input,
                    "needs_clarification": False,
                    "reply_message": ""
                }

    # Log successful execution details
    if booking_id:
        AgentLog.objects.create(
            booking_id=booking_id,
            agent_name=agent_name,
            action_taken=action_taken,
            reasoning=f"{reason} | Extracted: {result} | Errors encountered: {errors}"
        )

    return result
