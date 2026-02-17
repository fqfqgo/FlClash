import os
import json
import requests
from requests.exceptions import RequestException

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
TAG = os.getenv("TAG", "")
RUN_ID = os.getenv("RUN_ID", "")

IS_STABLE = "-" not in TAG

CHAT_ID = "@FlClash"
LOCAL_API_URL = f"http://localhost:8081/bot{TELEGRAM_BOT_TOKEN}/sendMediaGroup"
PUBLIC_API_URL = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMediaGroup"

DIST_DIR = os.path.join(os.getcwd(), "dist")
release = os.path.join(os.getcwd(), "release.md")

text = ""

media = []
files = {}

i = 1

releaseKeywords = [
    "windows-amd64-setup",
    "android-arm64",
    "macos-arm64",
    "macos-amd64"
]

for file in os.listdir(DIST_DIR):
    file_path = os.path.join(DIST_DIR, file)
    if os.path.isfile(file_path):
        file_lower = file.lower()
        if any(kw in file_lower for kw in releaseKeywords):
            file_key = f"file{i}"
            media.append({
                "type": "document",
                "media": f"attach://{file_key}"
            })
            files[file_key] = open(file_path, 'rb')
            i += 1

if TAG:
    text += f"\n**{TAG}**\n"

if IS_STABLE:
    text += f"\nhttps://github.com/chen08209/FlClash/releases/tag/{TAG}\n"
else:
    text += f"\nhttps://github.com/chen08209/FlClash/actions/runs/{RUN_ID}\n"

if os.path.exists(release):
    text += "\n"
    with open(release, 'r') as f:
        text += f.read()
    text += "\n"

if media:
    media[-1]["caption"] = text
    media[-1]["parse_mode"] = "Markdown"

if not TELEGRAM_BOT_TOKEN:
    print("TELEGRAM_BOT_TOKEN is missing, skip telegram push.")
    raise SystemExit(0)

response = None
errors = []
for api_url in [LOCAL_API_URL, PUBLIC_API_URL]:
    try:
        response = requests.post(
            api_url,
            data={
                "chat_id": CHAT_ID,
                "media": json.dumps(media)
            },
            files=files,
            timeout=30
        )
        response.raise_for_status()
        print(f"Telegram push succeeded via: {api_url}")
        print("Response JSON:", response.json())
        break
    except RequestException as e:
        errors.append(f"{api_url} -> {e}")
        print(f"Telegram push failed via: {api_url}, error: {e}")

for f in files.values():
    try:
        f.close()
    except Exception:
        pass

if response is None:
    print("Telegram push failed on all endpoints:")
    for err in errors:
        print(err)
    # Do not block release flow on telegram transient failure.
    raise SystemExit(0)
