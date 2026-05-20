# Darbar → Production-Grade Implementation Plan

**Goal:** Transform Darbar from a hackathon prototype into a flagship, production-grade Agentic AI demo that wins Challenge 2 of the Google AI Seekho Antigravity Hackathon.

**Scoring Criteria Alignment:**
| Criteria | Weight | Our Focus |
|---|---|---|
| Technical Merit & Agentic AI Depth | High | Multi-agent pipeline with visible traces, retry/fallback |
| Innovation & Feasibility | High | Informal economy service finder, multi-language |
| User Experience (UX) | High | Premium UI, animations, dark mode, live agent tracking |
| Impact | Medium | Real problem for Pakistan's informal sector |
| Antigravity Usage | 25% | Document all Antigravity sessions |

---

## Full Project Audit — Issues Found

I've analyzed every single file in the project. Here's a comprehensive breakdown:

### 🔴 Critical Bugs (15 found)

| # | File | Bug | Impact |
|---|---|---|---|
| 1 | `discovery_agent.py` | `AgentLog.objects.create()` missing `booking` FK — logs float orphaned | Agent traces broken for judges |
| 2 | `ranking_agent.py` | Same — no `booking` FK on log creation | " |
| 3 | `decision_agent.py` | Same — no `booking` FK on log creation | " |
| 4 | `views.py:process_request` | Creates a `Booking` record even for greeting/clarification queries | Database polluted with junk bookings |
| 5 | `home_screen.dart` | Hardcoded fallback UUID `147bbe81-...` — if `userId` is null, requests go to wrong user | Auth bypass |
| 6 | `home_screen.dart` | Skips `ProcessingScreen` entirely — navigates straight to `BookingConfirmedScreen` | Most impressive demo screen unused |
| 7 | `booking_confirmed_screen.dart` | Hardcodes `"4.8 (120 reviews)"` instead of using `bookingData['provider_rating']` | Shows fake data |
| 8 | `booking_confirmed_screen.dart` | Missing booking ID, service type, location display | Incomplete information |
| 9 | `provider_dashboard.dart` | Entirely mock data — no API calls to backend | Provider side non-functional |
| 10 | `processing_screen.dart` | Imports `lottie` but uses plain `CircularProgressIndicator` | Looks amateurish |
| 11 | `api_service.dart` | Uses `10.0.2.2:8000` (Android emulator) while all screens use `127.0.0.1:8000` | Service is broken & unused |
| 12 | `auth_service.dart` | Complete auth service exists but nothing uses it | Session persistence broken |
| 13 | `login_screen.dart` | No dark mode support — always white background | Visual bug in dark mode |
| 14 | `register_screen.dart` | No dark mode support — always white background | Visual bug in dark mode |
| 15 | `followup_agent.py` | `BackgroundScheduler()` starts on import at module level | Could crash Django on startup |

### 🟡 Missing Features (from your own plan.md)

| Feature | Plan Reference | Current Status |
|---|---|---|
| Processing Screen with live agent pipeline steps | Screen 2 — "most impressive for demo" | Exists but UNUSED, plain design |
| Agent Trace Panel (collapsible) | Screen 3 — "judges love this" | Not implemented |
| Retry / Fallback when provider doesn't respond | Screen 4 | Not implemented |
| Provider Dashboard connected to real API | Screen 5 — "Critical for demo flow" | Mock data only |
| Multi-turn conversation context | Chat Agent | Each message is independent |
| Real-time Supabase subscriptions | Flutter Technical | Not implemented |
| Session persistence across app restarts | Auth flow | AuthService exists but unused |
| Booking details display (ID, service, location, distance) | Screen 3 & 6 | Partially implemented |

### 🟠 Architecture Issues

| Issue | Details |
|---|---|
| Hardcoded URLs everywhere | `http://127.0.0.1:8000` scattered across 6+ files |
| `ApiService` class unused | Every screen creates its own `Dio()` instance |
| `AuthService` class unused | Complete service exists but nothing wires into it |
| No centralized error handling | Each screen has its own try/catch patterns |
| `lottie` package imported but never used | Dead dependency unless we use it |

---

## Proposed Changes

Changes are organized into 5 phases, ordered by impact and dependency.

---

### Phase 1: Fix Critical Backend Bugs

> [!IMPORTANT]
> These bugs mean agent traces (the #1 feature judges will inspect) are broken. Must fix first.

#### [MODIFY] [discovery_agent.py](file:///d:/DarBar/darbar/backend/agents/discovery_agent.py)
- Add `booking` FK to `AgentLog.objects.create()` call (currently creates orphaned logs)
- Pass the actual `booking_id` as `booking_id` parameter to link the log

#### [MODIFY] [ranking_agent.py](file:///d:/DarBar/darbar/backend/agents/ranking_agent.py)
- Same fix — add `booking` FK to the `AgentLog` creation
- Improve scoring formula to include mock distance component (currently 0% of the 40% weight)

#### [MODIFY] [decision_agent.py](file:///d:/DarBar/darbar/backend/agents/decision_agent.py)
- Same fix — add `booking` FK to the `AgentLog` creation
- Enhance reasoning text with distance + review count details

#### [MODIFY] [followup_agent.py](file:///d:/DarBar/darbar/backend/agents/followup_agent.py)
- Move `BackgroundScheduler()` initialization inside the function (avoid module-level side effect)
- Add `booking` FK to `AgentLog` creation

#### [MODIFY] [views.py](file:///d:/DarBar/darbar/backend/api/views.py)
- **Don't create a Booking for clarification queries** — only create when intent is fully resolved
- Add `provider_phone`, `provider_area`, `service_type`, `booking_id_human` to the processing response
- Add a new endpoint `GET /api/provider/bookings/<provider_id>/` for provider dashboard
- Add a new endpoint `POST /api/provider/respond/` for provider accept/decline with real backend logic
- Create in-app `Notification` records when bookings are created/confirmed

#### [MODIFY] [urls.py](file:///d:/DarBar/darbar/backend/api/urls.py)
- Add new provider endpoint routes

---

### Phase 2: Centralize Flutter Architecture

> [!IMPORTANT]
> This phase eliminates hardcoded URLs and wires up the existing but unused services.

#### [MODIFY] [api_service.dart](file:///d:/DarBar/darbar/flutter_app/lib/services/api_service.dart)
Complete rewrite to become the single source of truth for all API calls:
- Centralized `baseUrl` configurable for web/emulator/device
- Methods: `submitRequest()`, `getBookings()`, `getAgentLogs()`, `getNotifications()`, `confirmBooking()`, `getProviderBookings()`, `respondToBooking()`
- Shared `Dio` instance with interceptors for error handling and logging
- Timeout configuration

#### [MODIFY] [auth_service.dart](file:///d:/DarBar/darbar/flutter_app/lib/services/auth_service.dart)
- Fix the `login()` method (currently missing `password` and `identifier` params)
- Wire up `SharedPreferences` session persistence properly
- Add `email` to saved session data

#### [MODIFY] [main.dart](file:///d:/DarBar/darbar/flutter_app/lib/main.dart)
- Add `AuthService` as a second `ChangeNotifierProvider`
- Add session auto-restore on startup (check `SharedPreferences` → skip login if session exists)
- Add a premium splash screen widget during session loading

#### [MODIFY] [theme_provider.dart](file:///d:/DarBar/darbar/flutter_app/lib/services/theme_provider.dart)
- Persist dark mode preference to `SharedPreferences`
- Auto-restore theme on app startup

---

### Phase 3: Implement Missing Core Features

> [!IMPORTANT]
> These are the features that will differentiate your submission from other teams.

#### [MODIFY] [home_screen.dart](file:///d:/DarBar/darbar/flutter_app/lib/screens/home_screen.dart)
- **Multi-turn conversation context**: Track accumulated intent (service_type, location, time) across messages so the agent can ask for missing pieces one at a time
- Remove hardcoded fallback UUID
- Navigate to `ProcessingScreen` (with real data) instead of directly to `BookingConfirmedScreen`
- Use centralized `ApiService` instead of inline `Dio()` calls
- Add subtle typing animation (animated dots) instead of plain text
- Add message timestamps

#### [MODIFY] [processing_screen.dart](file:///d:/DarBar/darbar/flutter_app/lib/screens/processing_screen.dart)
Complete redesign — this is the "most impressive screen for demo":
- **Dark gradient background** with animated particles/glow
- **Animated stepper** showing each agent's name and status (✓ completed, ⟳ running, ○ pending)
- **Live status text** with smooth `AnimatedSwitcher` transitions
- **Pulsing icon** for the active agent step
- Pass real `bookingId` and poll `GET /api/bookings/<id>/` for real-time status updates
- Dark mode support
- Navigate to `BookingConfirmedScreen` when booking is confirmed

#### [MODIFY] [booking_confirmed_screen.dart](file:///d:/DarBar/darbar/flutter_app/lib/screens/booking_confirmed_screen.dart)
Major enhancement:
- Display all booking details: `booking_id`, `service_type`, `location`, real `provider_rating`, `provider_phone`
- **Add collapsible Agent Trace Panel** — fetch from `GET /api/logs/<booking_id>/` and display a beautiful timeline of each agent's reasoning
- Add "Call Provider" button with `url_launcher`
- Premium success animation at the top
- Dark mode fixes

#### [MODIFY] [provider_dashboard.dart](file:///d:/DarBar/darbar/flutter_app/lib/screens/provider_dashboard.dart)
Connect to real backend:
- Fetch pending bookings from `GET /api/provider/bookings/<provider_id>/`
- Accept/Decline sends `POST /api/provider/respond/`
- Auto-refresh with pull-to-refresh
- Show customer details, service requested, location
- Add provider stats header (total jobs, rating, active status)

#### [MODIFY] [bookings_screen.dart](file:///d:/DarBar/darbar/flutter_app/lib/screens/bookings_screen.dart)
- Use centralized `ApiService`
- Add animated status badge colors
- Add tap → navigate to enhanced `BookingConfirmedScreen` with agent trace panel

---

### Phase 4: Premium UI Polish

> [!CAUTION]
> The hackathon judges evaluate UX heavily. A "basic-looking" app will not advance to Stage 3.

#### [MODIFY] [login_screen.dart](file:///d:/DarBar/darbar/flutter_app/lib/screens/login_screen.dart)
- Full dark mode support (currently hardcoded white)
- Add gradient header/hero section with app logo and tagline
- Add subtle entrance animations (fade + slide)
- Premium input field styling with custom focus colors

#### [MODIFY] [register_screen.dart](file:///d:/DarBar/darbar/flutter_app/lib/screens/register_screen.dart)
- Full dark mode support
- Consistent styling with login screen
- Animated role toggle cards

#### [MODIFY] [main_shell.dart](file:///d:/DarBar/darbar/flutter_app/lib/screens/main_shell.dart)
- Add smooth page transitions when switching tabs
- Add notification badge on Alerts tab

#### [MODIFY] [main.dart](file:///d:/DarBar/darbar/flutter_app/lib/main.dart)
- Refine color scheme for both light/dark modes
- Add page transition animations globally
- Splash screen with Darbar branding during auth check

#### [MODIFY] [settings_screen.dart](file:///d:/DarBar/darbar/flutter_app/lib/screens/settings_screen.dart)
- Add app version section with "Built with Google Antigravity" branding
- Minor polish and spacing fixes

#### [MODIFY] [notifications_screen.dart](file:///d:/DarBar/darbar/flutter_app/lib/screens/notifications_screen.dart)
- Add dismissible (swipe to delete) notifications
- Add unread count badge
- Improve empty state with more personality

---

### Phase 5: Documentation & Demo Prep

#### [MODIFY] [readme.md](file:///d:/DarBar/darbar/readme.md)
- Add Mermaid architecture diagram
- Add screenshot gallery
- Add "How Antigravity Was Used" section with traces
- Add "APIs & Tools Used" comprehensive table
- Add setup instructions reference

#### [MODIFY] [antigravity_traces.md](file:///d:/DarBar/darbar/antigravity_traces.md)
- Add Phase 3 (Flutter) and Phase 4 (Integration) traces
- Document all Antigravity sessions with timestamps

#### [MODIFY] [changes.md](file:///d:/DarBar/darbar/changes.md)
- Document all new features and fixes

---

## Open Questions

> [!IMPORTANT]
> **Q1: Backend URL Configuration**
> Your Flutter app currently uses `http://127.0.0.1:8000`. Are you planning to:
> - (a) Demo on web browser only (localhost is fine)?
> - (b) Demo on a physical Android/iOS device (need your machine's LAN IP like `192.168.x.x`)?
> - (c) Deploy the backend somewhere (Render, Railway, etc.)?
> 
> This affects how I configure the API base URL.

> [!IMPORTANT]
> **Q2: Do you have working API keys?**
> Which of these are currently active and working?
> - [ ] Minimax (opencode.ai/zen)
> - [ ] Gemini API key
> - [ ] Groq API key
> - [ ] Google OAuth credentials (Client ID + Secret)
> - [ ] Supabase (URL + Key + Database URL)
> 
> This determines whether we rely on the local fallback or can test live LLM responses.

> [!IMPORTANT]
> **Q3: Lottie Animations**
> You have the `lottie` package installed but unused. Should I:
> - (a) Use Lottie JSON animations for the processing screen and success states (requires downloading/creating `.json` animation files)?
> - (b) Use pure Flutter custom animations (no external files needed, still looks premium)?

> [!IMPORTANT]
> **Q4: The Google Doc you linked is the FAQ, not the Challenge document**
> The link you provided (`1f8BdT9oiMN8...`) is titled "FAQs | Google Antigravity Hackathon" — not the actual Challenge 2 document. Could you share the correct challenge requirements document? Or is there a specific problem statement you chose from the hackathon tracks?

---

## Verification Plan

### Automated Tests
```bash
# Backend: Run Django test suite
cd backend && python manage.py test

# Backend: Verify all endpoints respond
curl http://127.0.0.1:8000/api/providers/
curl -X POST http://127.0.0.1:8000/api/auth/login/ -d '{"identifier":"test","password":"test","role":"customer"}'

# Flutter: Analyze for errors
cd flutter_app && flutter analyze
```

### Manual Verification (End-to-End Demo Flow)
1. **Launch app** → Splash screen → Login screen (dark mode toggle works)
2. **Register** as customer → Auto-login → Home chat screen
3. **Type "Hi"** → Agent responds with greeting (clarification, no junk booking created)
4. **Type "AC technician G-13 abhi"** → Agent recognizes full intent
5. **Processing screen** → Animated agent pipeline (5 steps with live updates)
6. **Booking confirmed** → Provider card, AI reasoning, collapsible agent trace panel
7. **My Bookings tab** → Shows the booking with status badge
8. **Switch to Provider account** → Dashboard shows incoming booking request
9. **Provider accepts** → Customer booking status updates to "Confirmed"
10. **Settings** → Dark mode toggle, Google OAuth link, avatar customization

### Browser Recording
- Record a complete demo flow video using the browser tool for documentation

---

## Estimated Effort

| Phase | Scope | Estimated Time |
|---|---|---|
| Phase 1 | Backend bug fixes | ~1 hour |
| Phase 2 | Architecture centralization | ~1.5 hours |
| Phase 3 | Missing core features | ~3 hours |
| Phase 4 | UI polish | ~2 hours |
| Phase 5 | Documentation | ~30 min |
| **Total** | | **~8 hours** |


OAuth :

# Updated Implementation Plan: Multi-User Google Authentication

Based on your excellent feedback, we are adapting the plan to align perfectly with your design requirements and to upgrade your friend's existing code to support **individual multi-user sign-ins**.

---

## Technical Insights & Answers to your Questions

### 1. Codebase Audit: Is Google OAuth already there?
**Yes, it is!** 
* **Backend (`google_oauth.py`)**: Contains the Google Flow, token exchange, and Gmail API dispatch handler.
* **Frontend (`settings_screen.dart`)**: Contains a "Connect Google Account" button that triggers the OAuth browser link.
* **Current Limitation**: Currently, this is configured for a *single global demo account* (it saves all tokens to a single local file `google_tokens.json`). We will upgrade this so that **each individual user and provider** has their own Google connection stored directly in the database.

### 2. How do we know if a Google sign-in is a Provider or a Customer?
Your design idea is spot on! Since the **Login Screen** already has a `"Login as Service Provider"` checkbox, we will keep that toggle!
* Before clicking the "Sign In with Google" button, the user will check or uncheck that box.
* The Flutter app will send the verified Google email + the selected role (Customer or Provider) to the backend.
* The backend will search the appropriate database table (`User` or `Provider`) to find a match.

### 3. Login Credentials Flow (How do they log back in?)
When they log out, they have two seamless choices to log back in:
1. **Password Login**: They can enter their email/phone and their original password (which they created during registration).
2. **Google Single-Tap Login**: Since their Google account was linked in their profile, they can simply tap the "Sign in with Google" button on the login screen. It will look up their linked email and log them in instantly—**no password typing required!**

---

## Proposed Architectural Upgrades

### Step 1: Upgrade the Database Models
We will add `google_email` and `is_google_linked` fields to the `User` and `Provider` models so each account tracks its own Google authorization state.

#### [MODIFY] [models.py](file:///e:/flutter/flutter-projects/darbar-Hassan/backend/api/models.py)
```python
# Add to User model
google_email = models.EmailField(blank=True, null=True, unique=True)
is_google_linked = models.BooleanField(default=False)

# Add to Provider model
google_email = models.EmailField(blank=True, null=True, unique=True)
is_google_linked = models.BooleanField(default=False)
```

### Step 2: Use OAuth `state` for Secure Account Linking
When a logged-in user taps **"Connect Google Account"** in their profile, we will pass their specific `user_id` and `role` inside the OAuth `state` parameter.
When Google redirects back to our backend callback, the backend reads the `state` and links the Google email to that specific user in the database.

#### [MODIFY] [views.py](file:///e:/flutter/flutter-projects/darbar-Hassan/backend/api/views.py)
We will add the backend endpoints for:
1. **State-aware Google Auth URL Generation**: Encodes the active `user_id` and `role` into the state.
2. **Multi-User Google Callback**: Decodes the state and saves the user's specific access/refresh tokens in their database record instead of a global file.
3. **Google Sign-In Verification**: Verifies Google ID tokens sent from the Flutter login page and logs them in.

---

## Step-by-Step Implementation Steps

### Phase 1: Backend Database & Route Upgrades
1. Apply migrations to add `google_email` and `is_google_linked` fields.
2. Update `/api/auth/google/url/` to accept `user_id` and `role` query parameters.
3. Update `/api/auth/google/callback/` to decode the state and save tokens to the user/provider record in the database.
4. Implement `/api/auth/google-login/` to verify Google ID tokens for single-tap login.

### Phase 2: Flutter Settings Screen Upgrade
1. Update the **Connect Google Account** call in `settings_screen.dart` to pass the logged-in user's ID and role:
   `http://127.0.0.1:8000/api/auth/google/url/?user_id=$userId&role=$role`
2. Update the status card to show their linked personal Gmail.

### Phase 3: Flutter Login Screen Upgrade
1. Add a sleek, modern **"Sign In with Google"** button below the standard login button.
2. Wire it up to trigger the native `google_sign_in` sheet, fetch the token, and send it to the backend along with the selected role checkbox state.
