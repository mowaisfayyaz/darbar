Darbar-Service booking app for informal economy

---

## 🗺️ High Level Phase Plan
### AI Service Orchestrator — Hackathon Build

---
    
### ⚡ Reality Check First

```
Time available:    ~5-6 working days
Builder:           Solo (you)
Must have:         Flutter app + Python + Supabase + Antigravity
Win condition:     Working demo + agent traces + reasoning logs
```

---

## PHASE 0 — Setup & Foundation
### Day 1 — Morning (2-3 hours)

```
Goal: Everything configured, zero time wasted later
```

**Accounts & Tools:**
```
□ Supabase project created
□ Google Cloud project created
□ Minimax API key obtained (via opencode.ai/zen)
□ Google Maps API key obtained
□ Twilio API key obtained (SMS)
□ Gmail API credentials set up (email notifications)
□ Firebase project (optional push notifications)
□ Antigravity IDE downloaded & set up
□ Flutter environment ready
□ Python 3.12 virtual environment ready
□ Django 5.0 installed
□ GitHub repo initialized
```

**Folder Structure:**
```
project/
├── flutter_app/          # Mobile frontend
├── django_backend/       # Django REST API + agents
│   ├── agents/
│   │   ├── intent_agent.py
│   │   ├── discovery_agent.py
│   │   ├── ranking_agent.py
│   │   ├── decision_agent.py
│   │   ├── booking_agent.py
│   │   └── followup_agent.py
│   ├── api/               # Django apps and routers
│   ├── db/
│   └── manage.py
└── README.md
```

---

## PHASE 1 — Database Foundation
### Day 1 — Afternoon (3-4 hours)

```
Goal: Supabase fully ready with mock data
      so every other phase has something to work with
```

**Tables to create:**
```
□ users
  - id, name, phone, location, created_at

□ providers
  - id, business_name, phone, website, rating, review_count, category, price_indicator, location (city, area, lat, lng)
  - is_available, device_token
  - created_at

□ bookings
  - id, user_id, provider_id
  - service_type, location
  - scheduled_time, status
  - booking_id (human readable BK-2026-XXX)
  - created_at

□ booking_attempts
  - id, booking_id, provider_id
  - sent_at, responded_at
  - status (sent/accepted/timeout/declined)
  - failure_reason

□ agent_logs         ← judges love this
  - id, booking_id
  - agent_name
  - action_taken
  - reasoning
  - timestamp

□ reminders
  - id, booking_id
  - remind_at, type
  - status (pending/sent)
```

**Mock Data to insert:**
```
□ 15-20 fake providers across
  G-13, F-14, I-14, E-11 Islamabad
  covering: AC Tech, Plumber,
  Electrician, Tutor, Beautician

□ 2-3 test user accounts

□ Sample bookings for demo purposes
```

---

## PHASE 2 — Python Backend + Agent Pipeline
### Day 2 — Full Day (6-8 hours)

```
Goal: The actual brain of the system working
      All 6 agents running in sequence
      Fallback/retry logic working
```

**Step 1 — Django Backend Base (1 hour)**
```
□ POST /api/request/          → main entry point
□ GET  /api/bookings/<id>/    → booking status
□ GET  /api/logs/<id>/       → agent trace logs
□ GET  /api/providers/        → list providers
□ POST /api/confirm/          → provider confirms
```

**Step 2 — Agent 1: Intent Agent (1 hour)**
```
□ Takes raw text input
□ Calls Minimax m2.5 API (opencode.ai/zen)
□ Extracts:
  - service type
  - location (area name)
  - time preference
  - language detected
□ Handles: English, Urdu, Roman Urdu
□ Returns structured JSON in the detected language
□ Logs to agent_logs table
```

**Step 3 — Agent 2: Discovery Agent (1 hour)**
```
□ Takes structured intent
□ Queries Supabase providers table
□ Filters by:
  - service_type match
  - area/city match
  - is_available = true
□ Calls Google Maps API
  for real distance calculation
□ Returns ranked candidate list
□ Logs to agent_logs table
```

**Step 4 — Agent 3 & 4: Ranking + Decision Agent (1 hour)**
```
□ Scoring formula:
  distance score  (40%)
  rating score    (35%)
  jobs done score (25%)

□ Ranks all candidates
□ Picks #1 automatically
□ Generates human readable reasoning:
  "Selected Ali AC Services because
   closest (2.1km), highest rated (4.8★),
   48 jobs completed"
□ Logs reasoning to agent_logs
```

**Step 5 — Agent 5: Booking Agent (1.5 hours)**
```
□ Creates booking record in Supabase
□ Generates booking ID (BK-2026-XXX)
□ Creates booking_attempt record
□ Sends notifications via:
  - Push notification (Firebase Cloud Messaging)
  - Email (Gmail API)
  - SMS (Twilio API)
□ Starts timeout timer (3 min real / 10 sec demo)
□ If timeout → marks attempt as failed → triggers next provider
□ Retry loop across all ranked providers
□ If all fail → expand radius OR waitlist
□ Logs every attempt to agent_logs
```

**Step 6 — Agent 6: Follow-Up Agent (1 hour)**
```
□ After booking confirmed:
  - Schedules reminder (1hr before)
  - Uses APScheduler in Python
□ Reminder triggers push notification:
  "Your AC Technician arrives in 1 hour"
□ After job time passes:
  - Sends rating request
□ Logs all scheduled actions
```

**Step 7 — Antigravity Integration (1 hour)**
```
□ Use Antigravity IDE to:
  - Generate boilerplate code fast
  - Spawn parallel agents in Manager View:
    Agent A → writes booking logic
    Agent B → writes intent parsing
    Agent C → writes DB queries
□ Screenshot Manager View for documentation
  (this proves Antigravity usage to judges)
□ Deploy agent pipeline to
  Vertex AI Agent Builder
  (label this as "Antigravity orchestration")
```

---

## PHASE 3 — Flutter Mobile App
### Day 3 — Full Day (6-8 hours)

```
Goal: Clean working mobile UI
      Talks to Python backend
      Shows everything judges need to see
```

**Screens to build:**
```
□ Screen 1 — Home / Chat Input
  - Simple text input field
  - Microphone button (optional)
  - Language indicator
  - Send button
  - Recent bookings list

□ Screen 2 — Processing Screen
  - Animated loading state
  - Live agent status updates:
    "Understanding your request..."
    "Finding providers near G-13..."
    "Ranking 8 providers..."
    "Contacting Ali AC Services..."
  - This screen = most impressive for demo

□ Screen 3 — Booking Confirmed Screen
  - Provider card:
    Name, rating, distance, phone
  - Booking details:
    Service, location, time, booking ID
  - AI Reasoning box:
    "Selected because: closest + highest rated"
  - Agent Trace Panel (collapsible):
    Full step by step log
  - Confirmation receipt UI

□ Screen 4 — Retry / Fallback Screen
  - Shows when provider doesn't respond
  - "Ali AC unavailable — trying next..."
  - Progress indicator across providers
  - Auto advances to next attempt

□ Screen 5 — Provider App (Minimal)
  - Simple screen showing incoming booking
  - Accept / Decline buttons
  - This simulates the provider side
  - Critical for demo flow

□ Screen 6 — My Bookings
  - List of all bookings
  - Status badges (pending/confirmed/completed)
  - Tap to see full details + agent log
```

**Flutter Technical:**
```
□ HTTP calls to FastAPI using Dio package
□ Real time updates using Supabase
  realtime subscriptions
□ Firebase push notifications setup
□ Clean UI — use Material 3
□ Support RTL for Urdu text display
```

---

## PHASE 4 — Integration & Testing
### Day 4 — Full Day (5-6 hours)

```
Goal: Everything talks to everything
      End to end flow works without breaking
```

```
□ Flutter → FastAPI connection tested
□ FastAPI → Gemini API tested
□ FastAPI → Supabase read/write tested
□ FastAPI → Firebase notifications tested
□ Full happy path tested:
  User types → agent processes →
  booking created → confirmed →
  reminder scheduled

□ Fallback path tested:
  Provider 1 times out →
  Provider 2 times out →
  Provider 3 accepts

□ Edge cases tested:
  Roman Urdu input works
  Urdu input works
  Unknown service type handled
  No providers available handled

□ Agent logs visible in app
□ Booking receipt generates correctly
```

---

## PHASE 5 — Demo Preparation
### Day 5 — Full Day (4-5 hours)

```
Goal: Win-ready demo
      Clean video
      Strong documentation
```

**Documentation:**
```
□ README.md with:
  - System architecture diagram
  - How Antigravity was used (with screenshots)
  - All APIs/tools used
  - Setup instructions
  - Assumptions and limitations

□ Agent trace screenshots
□ Supabase schema screenshot
□ Antigravity Manager View screenshots
```


2. Fallback retry logic working live
   (shows real agentic behavior)

3. Real time status updates during booking
   (impressive UX moment)

4. Antigravity screenshots in docs
   (satisfies the 25% scoring criteria)

5. Roman Urdu / Urdu input working
   (judges will test this for sure)
```

---
