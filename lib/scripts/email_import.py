import imaplib
import email
import requests
from email.utils import parsedate_to_datetime
from bs4 import BeautifulSoup
from email.header import decode_header
from datetime import datetime

# =========================
# CONFIG
# =========================

IMAP_HOST = "mail.amity.pet"
EMAIL_USER = "crm@amity.pet"
EMAIL_PASS = "Coco2027$&"

SUPABASE_URL = "https://phkwizyrpfzoecugpshb.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBoa3dpenlycGZ6b2VjdWdwc2hiIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2OTM2NjI4MiwiZXhwIjoyMDg0OTQyMjgyfQ.XF9Mi_Pzp-F2AQflrFEbuftf1rqavZWsLUwRoS6XpHA"
print("Starting email import...")

# =========================
# HELPERS
# =========================

def html_to_text(html):
    soup = BeautifulSoup(html, "html.parser")

    for tag in soup(["style", "script", "head"]):
        tag.decompose()

    text = soup.get_text(separator="\n")
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return "\n".join(lines)

# =========================
# CONNECT EMAIL
# =========================

mail = imaplib.IMAP4_SSL(IMAP_HOST)
mail.login(EMAIL_USER, EMAIL_PASS)
mail.select("INBOX")

print("Connected to email server")

# =========================
# FETCH EMAILS
# =========================

status, messages = mail.search(None, "UNSEEN")
email_ids = messages[0].split()

print(f"Found {len(email_ids)} emails")

for i, num in enumerate(email_ids, start=1):
    print(f"\nProcessing email {i} of {len(email_ids)}")

    status, msg_data = mail.fetch(num, "(RFC822)")
    raw_email = msg_data[0][1]

    msg = email.message_from_bytes(raw_email)

    message_id = msg.get("Message-ID")
    from_email = msg.get("From")
    subject = msg.get("Subject")

    if subject:
        subject, encoding = decode_header(subject)[0]
        if isinstance(subject, bytes):
            subject = subject.decode(encoding or "utf-8")
    else:
        subject = "No subject"

    if from_email:
        from_email = email.utils.parseaddr(from_email)[1]

    print(f"   From: {from_email}")
    print(f"   Subject: {subject}")

    body = ""
    html_body = ""

    if msg.is_multipart():
        for part in msg.walk():
            content_type = part.get_content_type()
            part_payload = part.get_payload(decode=True)

            if not part_payload:
                continue

            decoded = part_payload.decode(errors="ignore")

            if content_type == "text/plain" and not body:
                body = decoded

            if content_type == "text/html" and not html_body:
                html_body = decoded
    else:
        part_payload = msg.get_payload(decode=True)
        if part_payload:
            body = part_payload.decode(errors="ignore")

    if html_body:
        body = html_to_text(html_body)
    elif body.strip().lower().startswith("<!doctype html") or body.strip().lower().startswith("<html"):
        body = html_to_text(body)

    received_at = (
        parsedate_to_datetime(msg.get("Date")).isoformat()
        if msg.get("Date")
        else datetime.now().isoformat()
    )

    url = f"{SUPABASE_URL}/rest/v1/crm_email_import_log"

    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }

    payload = {
        "message_id": message_id,
        "from_email": from_email,
        "subject": subject,
        "received_at": received_at,
        "raw_body": body,
        "import_status": "pending"
    }

    response = requests.post(url, headers=headers, json=payload)

    if response.status_code not in (200, 201, 204):
        print("Insert failed:", response.status_code, response.text)
    else:
        print("Inserted:", subject)

# =========================
# CLEANUP
# =========================

mail.logout()
print("\nEmail import run complete")
