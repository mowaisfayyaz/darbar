import os
import json
import base64
from email.mime.text import MIMEText
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow
from googleapiclient.discovery import build
from google.auth.transport.requests import Request

TOKEN_FILE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'google_tokens.json')

SCOPES = [
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/userinfo.email',
    'openid'
]

def get_google_flow():
    """
    Initializes and returns the Google OAuth Flow using env credentials.
    """
    client_id = os.getenv('GOOGLE_CLIENT_ID')
    client_secret = os.getenv('GOOGLE_CLIENT_SECRET')
    redirect_uri = os.getenv('GOOGLE_REDIRECT_URI', 'http://127.0.0.1:8000/api/auth/google/callback/')

    if not client_id or not client_secret:
        raise ValueError("GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be defined in the .env file.")

    client_config = {
        "web": {
            "client_id": client_id,
            "client_secret": client_secret,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/oauth2/token",
            "redirect_uris": [redirect_uri]
        }
    }

    return Flow.from_client_config(
        client_config,
        scopes=SCOPES,
        redirect_uri=redirect_uri
    )

def get_authorization_url():
    """
    Generates the authorization URL for the user to login with Google.
    Enforces offline access type to ensure we receive a refresh_token.
    """
    flow = get_google_flow()
    auth_url, _ = flow.authorization_url(
        access_type='offline',
        prompt='consent',
        include_granted_scopes='true'
    )
    return auth_url

def exchange_code_for_tokens(code):
    """
    Exchanges the authorization code for access and refresh tokens.
    Saves the credentials to google_tokens.json.
    """
    flow = get_google_flow()
    flow.fetch_token(code=code)
    credentials = flow.credentials

    # Read user email to associate
    user_info_service = build('oauth2', 'v2', credentials=credentials)
    user_info = user_info_service.userinfo().get().execute()
    email = user_info.get('email', 'Unknown')

    token_data = {
        'token': credentials.token,
        'refresh_token': credentials.refresh_token,
        'token_uri': credentials.token_uri,
        'client_id': credentials.client_id,
        'client_secret': credentials.client_secret,
        'scopes': credentials.scopes,
        'email': email
    }

    with open(TOKEN_FILE_PATH, 'w') as f:
        json.dump(token_data, f)

    return email

def get_credentials():
    """
    Loads saved credentials from google_tokens.json.
    If the access token is expired, automatically refreshes it and saves the updated tokens.
    """
    if not os.path.exists(TOKEN_FILE_PATH):
        return None

    try:
        with open(TOKEN_FILE_PATH, 'r') as f:
            token_data = json.load(f)

        credentials = Credentials(
            token=token_data.get('token'),
            refresh_token=token_data.get('refresh_token'),
            token_uri=token_data.get('token_uri'),
            client_id=token_data.get('client_id'),
            client_secret=token_data.get('client_secret'),
            scopes=token_data.get('scopes')
        )

        # Refresh the credentials if they are expired
        if credentials.expired and credentials.refresh_token:
            credentials.refresh(Request())
            # Save refreshed credentials
            token_data['token'] = credentials.token
            with open(TOKEN_FILE_PATH, 'w') as f:
                json.dump(token_data, f)

        return credentials
    except Exception:
        # Remove corrupted token file
        if os.path.exists(TOKEN_FILE_PATH):
            os.remove(TOKEN_FILE_PATH)
        return None

def is_google_linked():
    """
    Checks if Google account is currently authorized and linked.
    """
    credentials = get_credentials()
    if not credentials:
        return False, None

    try:
        with open(TOKEN_FILE_PATH, 'r') as f:
            token_data = json.load(f)
        return True, token_data.get('email')
    except Exception:
        return False, None

def disconnect_google():
    """
    Deletes the token file to disconnect the Google account.
    """
    if os.path.exists(TOKEN_FILE_PATH):
        os.remove(TOKEN_FILE_PATH)
        return True
    return False

def send_gmail_message(to_email, subject, html_body):
    """
    Sends an email using the Google Gmail API.
    Refreshes the OAuth credentials automatically.
    """
    credentials = get_credentials()
    if not credentials:
        raise ValueError("Google account not linked or credentials expired.")

    service = build('gmail', 'v1', credentials=credentials)
    
    # Build MIME email message
    message = MIMEText(html_body, 'html')
    message['to'] = to_email
    message['subject'] = subject
    
    # Base64 encode the email content
    raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode('utf-8')
    body = {'raw': raw_message}
    
    # Send the email via Gmail API
    service.users().messages().send(userId='me', body=body).execute()
