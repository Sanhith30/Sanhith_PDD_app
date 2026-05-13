import base64
import zlib
import urllib.request
import os

def generate_kroki_url(text):
    compressed = zlib.compress(text.encode('utf-8'), 9)
    b64 = base64.urlsafe_b64encode(compressed).decode('ascii')
    return f"https://kroki.io/mermaid/png/{b64}"

diagrams = {
    "screen_diagram.png": """graph TD
    A[Splash Screen] --> B[Onboarding Tour]
    A --> C[Login / Sign Up]
    B --> C
    C --> D[Main Dashboard]
    D --> E[New Patient Case]
    D --> F[Patient History]
    D --> G[Analytics & Charts]
    D --> H[Settings & Profile]
    E --> I[Image Upload]
    I --> J((AI Result & Report))
    F --> K[Case Detail View]
    J --> D""",

    "introduction_diagram.png": """graph LR
    A[Patient with Oral Lesion] --> B(Clinical Examination)
    B --> C{Saveetha Oral Sentry App}
    C -->|Clinical Data| D[Tabular ML Model]
    C -->|Image Upload| E[Visual DL Model]
    D --> F((Hybrid AI Risk Assessment))
    E --> F""",

    "system_diagram.png": """graph TD
    subgraph Frontend [Mobile Client - Flutter]
        UI[Surgical Luxury UI]
        LocalDB[(SQLite Local Cache)]
    end
    
    subgraph Backend [FastAPI Server]
        API[REST Endpoints]
        Auth[PyJWT Auth]
        DB[(PostgreSQL / SQLite)]
    end
    
    subgraph AIEngine [Hybrid AI Engine]
        ML[Scikit-Learn ML Model]
        DL[TensorFlow MobileNetV2]
        Heuristics[OpenCV Heuristics]
    end
    
    UI <-->|HTTP/REST| API
    UI <-->|Offline Storage| LocalDB
    API <--> Auth
    API <--> DB
    API --> AIEngine
    AIEngine -->|Risk Score| API"""
}

os.chdir(r"c:\Users\SANHITH REDDY\Downloads\xyz\flutter_application_1")

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
for filename, mermaid_code in diagrams.items():
    print(f"Generating {filename}...")
    url = generate_kroki_url(mermaid_code)
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as response, open(filename, 'wb') as out_file:
            out_file.write(response.read())
        print(f"Successfully saved {filename}")
    except Exception as e:
        print(f"Failed to generate {filename}: {e}")
