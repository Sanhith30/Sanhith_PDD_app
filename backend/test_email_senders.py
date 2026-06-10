import os
import requests
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import time

# Load env manually
env_file = ".env"
if os.path.exists(env_file):
    with open(env_file) as f:
        for line in f:
            if line.strip() and not line.startswith("#"):
                try:
                    key, val = line.strip().split("=", 1)
                    os.environ[key.strip()] = val.strip().strip('"').strip("'")
                except ValueError:
                    pass

receiver = "sanhithreddy5131@gmail.com"
code = "123456"

print("--- Testing Google Apps Script ---")
script_url = os.environ.get("GMAIL_SCRIPT_URL")
if script_url:
    start = time.time()
    try:
        payload = {
            "secret": os.environ.get("GMAIL_SCRIPT_SECRET", "SaveethaOralSentrySecret123!"),
            "to": receiver,
            "subject": "Saveetha Oral Sentry - Test Code",
            "html": f"<p>Test code: {code}</p>"
        }
        r = requests.post(script_url, json=payload, timeout=10)
        print(f"Google Apps Script Status: {r.status_code}, Response: {r.text}, Time: {time.time() - start:.2f}s")
    except Exception as e:
        print(f"Google Apps Script Failed: {e}, Time: {time.time() - start:.2f}s")
else:
    print("Google Apps Script URL not set.")

print("\n--- Testing Brevo API ---")
brevo_key = os.environ.get("BREVO_API_KEY")
if brevo_key:
    start = time.time()
    try:
        url = "https://api.brevo.com/v3/smtp/email"
        headers = {
            "accept": "application/json",
            "api-key": brevo_key,
            "content-type": "application/json"
        }
        sender_email = os.environ.get("SENDER_EMAIL", "sanhithreddy5131@gmail.com")
        payload = {
            "sender": {"name": "Saveetha Oral Sentry", "email": sender_email},
            "to": [{"email": receiver}],
            "subject": "Saveetha Oral Sentry - Test Code",
            "htmlContent": f"<p>Test code: {code}</p>"
        }
        r = requests.post(url, json=payload, headers=headers, timeout=10)
        print(f"Brevo Status: {r.status_code}, Response: {r.text}, Time: {time.time() - start:.2f}s")
    except Exception as e:
        print(f"Brevo Failed: {e}, Time: {time.time() - start:.2f}s")
else:
    print("Brevo API key not set.")

print("\n--- Testing Resend API ---")
resend_key = os.environ.get("RESEND_API_KEY")
if resend_key:
    start = time.time()
    try:
        url = "https://api.resend.com/emails"
        headers = {
            "Authorization": f"Bearer {resend_key}",
            "Content-Type": "application/json"
        }
        sender_email = os.environ.get("SENDER_EMAIL", "onboarding@resend.dev")
        payload = {
            "from": f"Saveetha Oral Sentry <{sender_email}>",
            "to": [receiver],
            "subject": "Saveetha Oral Sentry - Test Code",
            "html": f"<p>Test code: {code}</p>"
        }
        r = requests.post(url, json=payload, headers=headers, timeout=10)
        print(f"Resend Status: {r.status_code}, Response: {r.text}, Time: {time.time() - start:.2f}s")
    except Exception as e:
        print(f"Resend Failed: {e}, Time: {time.time() - start:.2f}s")
else:
    print("Resend API key not set.")

print("\n--- Testing SMTP Fallback ---")
smtp_host = os.environ.get("SMTP_HOST")
smtp_user = os.environ.get("SMTP_USER")
smtp_pass = os.environ.get("SMTP_PASS")
smtp_port = int(os.environ.get("SMTP_PORT", 587))
if smtp_user and smtp_pass:
    start = time.time()
    try:
        msg = MIMEMultipart()
        msg['From'] = smtp_user
        msg['To'] = receiver
        msg['Subject'] = "Saveetha Oral Sentry - Test Code"
        msg.attach(MIMEText(f"Test code: {code}", 'plain'))

        server = smtplib.SMTP(smtp_host, smtp_port, timeout=10)
        server.starttls()
        server.login(smtp_user, smtp_pass)
        server.send_message(msg)
        server.quit()
        print(f"SMTP Success, Time: {time.time() - start:.2f}s")
    except Exception as e:
        print(f"SMTP Failed: {e}, Time: {time.time() - start:.2f}s")
else:
    print("SMTP credentials not set.")
