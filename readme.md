# Darbar - Premium Service Finder for the Informal Economy

Darbar is an industry-grade, multi-agent AI service finder application designed to connect customers with informal economy service providers (such as Plumbers, Electricians, and AC Technicians) instantly. By wrapping complex cascading LLM reasoning and real-time candidate rank matching into a streamlined, high-performance Flutter interface, Darbar removes the friction of booking local experts.

---

## Technical Architecture Overview

Darbar is engineered using a robust separation of concerns, separating client UI logic from a highly decoupled multi-agent backend orchestrator.

### 1. Unified Django API Backend
* **Multi-Agent Intent Extraction**: Features a highly resilient three-tier LLM intent classifier (Minimax m2.5-free, Google Gemini 1.5 Flash, and Groq LLaMA3) with a seamless, zero-latency local fallback layer to guarantee 100% service availability under high rate-limits.
* **Provider Discovery & Rank Matching**: Queries candidate providers from a Postgres database (backed by Supabase) and applies geographic coordinate calculation and rating metrics to extract, rank, and match the absolute best provider for the job.
* **Autonomous Booking Agent**: Dispatches requests to provider terminals, handles accept/decline responses, and triggers scheduled reminders.
* **Google OAuth 2.0 Client Flow**: Encapsulates dynamic authorization code exchange and token caching. It connects seamlessly to the live Google Gmail API to send formatted dispatch invoices to clients.

### 2. High-Performance Flutter Client
* **Modern Interface**: Designed using customized Material design principles with vibrant color systems, sleek typography, dynamic hover effects, and full support for Dark Mode.
* **Custom Device Image Upload**: Streams raw native photos directly into the application state using device gallery image pickers, ensuring latency-free profile customization.
* **Live Server Integration**: Operates synchronous Dio REST piping straight to Django orchestrator endpoints, providing real-time backend agent tracking feedback in the client UI.

---

## File System Structure

```
darbar/
├── backend/                  # Django Orchestrator Backend
│   ├── agents/               # Autonomous AI Decision Agents
│   │   ├── intent_agent.py   # Intent Classifier (Tiered Cascades)
│   │   ├── discovery_agent.py# Provider Search Agent
│   │   ├── ranking_agent.py  # Candidate Selection Agent
│   │   └── booking_agent.py  # Notification and Gmail Dispatch Agent
│   ├── api/                  # REST Controllers & Models
│   │   └── google_oauth.py   # Google OAuth Token Manager
│   └── manage.py             # Django Administration CLI
├── flutter_app/              # Cross-Platform Flutter Client
│   ├── lib/                  # Application Code
│   │   ├── screens/          # Main UI Interfaces
│   │   └── services/         # State Management & Services
│   └── pubspec.yaml          # Flutter Configuration & Packages
└── changes.md                # Engineering Change Records
```
