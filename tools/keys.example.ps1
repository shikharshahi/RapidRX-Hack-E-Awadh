# Copy this file to tools/keys.local.ps1 (gitignored) and fill it in.
#
#   Copy-Item tools/keys.example.ps1 tools/keys.local.ps1
#
# Every key is optional. Without them the app still runs end to end on the
# device: the handwriting card stays hidden, and sharing opens WhatsApp for a
# person to press send instead of sending by itself.

# Reads handwriting on the prescription photo, only after the user consents.
$env:GEMINI_API_KEY = ""

# WhatsApp for the medicine demo is sent by tools/bay.js, which reads
# tools/keys.local.sh. Leave these empty here so the token is not baked
# into a shared APK.
$env:TWILIO_ACCOUNT_SID = ""
$env:TWILIO_AUTH_TOKEN = ""
$env:TWILIO_WHATSAPP_FROM = ""   # e.g. +14155238886 (the Twilio sandbox)

# Phone → laptop bay. Same Wi-Fi. Example: http://192.168.1.20:8090/api/demo-alert
$env:BAY_URL = ""
