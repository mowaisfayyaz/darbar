# Developer Setup Guide - Darbar

This document outlines the step-by-step developer environment setup for both the unified Django backend orchestrator and the cross-platform Flutter client.

---

## 1. Django Backend Setup

### Prerequisites
* Python 3.10 or higher
* Pip Package Manager

### Step-by-Step Backend Configuration
1. **Navigate to the Backend Folder**:
   Change your working directory to the backend workspace.
   ```bash
   cd backend
   ```

2. **Initialize a Virtual Environment**:
   Initialize and activate a virtual environment to manage dependencies locally.
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   ```

3. **Install Core Dependencies**:
   Install all mandatory packages, including Django, Django REST Framework, cryptography, and Google API client libraries.
   ```bash
   pip install -r requirements.txt
   ```

4. **Database Migrations**:
   Run Django database migrations to set up relational tables in your Postgres database.
   ```bash
   python manage.py migrate
   ```

5. **Start Django Dev Server**:
   Start the local development server on port 8000.
   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```

---

## 2. Flutter Client Setup

### Prerequisites
* Flutter SDK (Stable Channel)
* Chrome (for Web testing) or Mobile Emulator

### Step-by-Step Client Configuration
1. **Navigate to the Flutter Folder**:
   ```bash
   cd flutter_app
   ```

2. **Install Flutter Packages**:
   Fetch and resolve all direct and transitive pub dependencies.
   ```bash
   flutter pub get
   ```

3. **Launch the Client**:
   Run the web build bound to local port 8081.
   ```bash
   flutter run -d web-server --web-port 8081 --web-hostname 0.0.0.0
   ```

---

## 3. Environment Variable Configuration

Copy `backend/.env.example` to `backend/.env` and fill in the required keys.

### Core Environment Variables

```ini
# Supabase Configuration
SUPABASE_URL="your_supabase_url"
SUPABASE_KEY="your_supabase_anon_key"

# Cascading AI Models (Minimax / OpenCode, Gemini, Groq)
MINIMAX_API_KEY="your_opencode_zen_key"
MINIMAX_MODEL_NAME="minimax-m2.5-free"
GEMINI_API_KEY="your_gemini_key"
GEMINI_MODEL_NAME="gemini-1.5-flash"
GROQ_API_KEY="your_groq_key"
GROQ_MODEL_NAME="llama3-70b-8192"

# Google OAuth 2.0 Credentials
GOOGLE_CLIENT_ID="your_client_id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="your_client_secret"
GOOGLE_REDIRECT_URI="http://127.0.0.1:8000/api/auth/google/callback/"
```

### Setting Up Google OAuth 2.0
1. Go to the **Google Cloud Console**.
2. Create a new project and navigate to **APIs & Services** > **Credentials**.
3. Configure your **OAuth Consent Screen** (add scope `https://www.googleapis.com/auth/gmail.send`).
4. Create an **OAuth 2.0 Client ID** choosing Application Type: **Web Application**.
5. Add the Authorized Redirect URI matching your backend endpoint:
   `http://127.0.0.1:8000/api/auth/google/callback/`
6. Copy the generated **Client ID** and **Client Secret** into your `backend/.env` file.
7. Open Darbar, go to the Settings interface, click **Connect Google Account**, authorize the scopes, and you are set.
