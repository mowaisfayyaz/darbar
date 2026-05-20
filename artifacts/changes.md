# Technical Changes Log - Darbar

## 1. Dynamic Environment-Configurable Model Chain
* **Decoupled Model Name Literals**: Moved model name literals for all LLM tiers directly into `backend/.env`.
* **Flexible Environment Overrides**: Added `MINIMAX_MODEL_NAME`, `GEMINI_MODEL_NAME`, and `GROQ_MODEL_NAME` slots with sensical system fallbacks in `intent_agent.py`.
* **Skipping Invalid Keys**: Programmed automatic safety triggers that skip fallback tiers if keys are left at defaults or missing.

## 2. Google OAuth 2.0 Client Flow Integration
* **Dynamic Flow Handler (`google_oauth.py`)**: Built a fully compliant, secure authentication exchange helper encapsulating:
  * Redirect and Callback State generation
  * Authorization exchange converting tokens to refresh/access tokens
  * Thread-safe, atomic local file token caching (`google_tokens.json`)
  * Access Token automated expiry detection and background Refresh-Token cycling.
* **Backend Django REST Enabler (`views.py` / `urls.py`)**: Added callback handlers generating fully custom, beautifully engineered HTML confirmation screens that gracefully communicate status and auto-close callback windows.
* **Booking Agent Integration (`booking_agent.py`)**: Seamlessly integrated the live **Gmail API (`users().messages().send()`)** into the `Booking Agent`'s dispatch pipe. When an account is successfully linked, a premium blue-gradient HTML receipt summarizing Reference, Location, and Provider details is dispatched instantly to the customer.

## 3. Premium Customer Interface Connect UI (`settings_screen.dart`)
* **Live OAuth Status Sync**: Configured local state loading matching backend `/api/auth/google/status/` status.
* **Premium OAuth Link Block**: Integrated a gorgeous Glassmorphic card displaying:
  * Status badges indicating email connection
  * Primary colored dispatch connect button trigger
  * Automated `url_launcher` redirect trigger in secondary tabs
  * Live status refresh control hooks letting users verify links instantly without app reload triggers.
