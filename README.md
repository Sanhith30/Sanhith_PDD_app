# <p align="center">Saveetha Oral Sentry (Oral Ulcer AI)</p>

<p align="center">
  <strong>A Hybrid Clinical-Grade Decision Support System for Oral Lesion Screening and Risk Stratification</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI">
  <img src="https://img.shields.io/badge/TensorFlow-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white" alt="TensorFlow">
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL">
  <img src="https://img.shields.io/badge/OpenCV-5C3EE8?style=for-the-badge&logo=opencv&logoColor=white" alt="OpenCV">
  <img src="https://img.shields.io/badge/IBM_SPSS-00599C?style=for-the-badge&logo=ibm&logoColor=white" alt="IBM SPSS">
</p>

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#app-interface-and-demo">App Demo</a> •
  <a href="#system-architecture">System Architecture</a> •
  <a href="#hybrid-ai-inference-engine">Hybrid AI Deep Dive</a> •
  <a href="#spss-statistical-results">SPSS Results</a> •
  <a href="#installation-and-setup">Setup Guide</a>
</p>

---

## Project Overview

Saveetha Oral Sentry is an advanced mobile-web clinical decision support application designed to assist dental professionals and clinicians in the early screening, risk stratification, and monitoring of oral ulcers and potentially malignant oral disorders (OPMDs).

Rather than relying on a simple "black-box" visual model, this system employs a hybrid assessment pipeline that cross-evaluates a patient's tabular clinical features, medical history, and OpenCV image heuristics alongside a deep learning convolutional neural network (CNN) image model. By providing explainable risk scores and actionable biopsy recommendations, it helps clinicians speed up critical patient referrals, prevent unnecessary biopsies, and optimize diagnostic workflows.

---

## Key Features

* **Clinician Onboarding and Security**: Secure token-based session management (PyJWT) with password reset capabilities utilizing an OTP system sent via Gmail SMTP.
* **Premium "Surgical Luxury" UI**: Built with a dark maroon and gold aesthetic specifically designed for clinical and hospital environments.
* **Patient Case Management**: Complete profile management with secure login sessions, allowing doctors to review patient history and visit logs.
* **Explainable Hybrid AI**: Risk scores calculated dynamically by fusing visual predictions (Deep Learning) and patient diagnostic variables (Machine Learning) using red-flag rules.
* **Computer Vision Processing**: OpenCV heuristics run locally to isolate and check for lesion color intensity (Erythema), margins, and borders.
* **Visual Analytics**: Interactive fl_charts detailing patient risk distributions over time.
* **Automated Referral Reports**: Generates formal clinical PDF reports ready for printing or routing to referral centers.

---

## App Interface and Demo

> **Watch the Full Video Demo Here:** [YouTube Shorts Demo](https://youtube.com/shorts/pcS3mV_aGtM)

| Splash Screen | Dashboard | AI Result & Risk Analysis |
|:---:|:---:|:---:|
| <img src="docs/images/Screenshot_20260514-151801.png" width="230"> | <img src="docs/images/Screenshot_20260514-151709.png" width="230"> | <img src="docs/images/Screenshot_20260514-151745.png" width="230"> |

---

## Clinical Workflow & User Guide

Saveetha Oral Sentry facilitates a seamless, end-to-end diagnostic workflow designed specifically for hospital dental departments:

1. **Clinician Authentication**: Clinicians register with their name, email, and password. Access token security is enforced using PyJWT.
2. **Onboarding Visual Tour**: Newly registered clinicians are greeted with an interactive visual tour highlighting the app's features and core layout.
3. **Patient Search & Intake**: Input a unique Patient ID (e.g., `PT001`). If the patient exists in the central PostgreSQL database, the app automatically pulls and displays their historical records and clinical data. If the patient is new, the clinician registers them with basic demographics (name, age, sex, and profile photo).
4. **Clinical Examination & History Entry**:
   * **Step A (Demographics)**: Records smoking habits (status, duration, daily frequency), smokeless tobacco usage, alcohol habits, and general medical conditions (diabetes, chemotherapy, steroids).
   * **Step B (Lesion History)**: Records duration, onset type, recurrence pattern, healing progress, and pain intensity.
   * **Step C (Physical Examination)**: Records anatomical lesion site, dimensions (in mm), shape, margins, edge type, induration, and bleeding on touch.
   * **Step D (Associated Findings)**: Records lymph node palpation (tenderness, mobility), weight loss, fever, or paraesthesia.
5. **Ulcer Photography**: Using the device's native camera, the clinician takes a clear photo of the oral ulcer.
6. **Multi-Modal AI Risk Assessment**: Pressing "Process AI Analysis" securely uploads the raw clinical JSON and photograph to the FastAPI backend.
7. **Diagnostics Breakdown & Report Sharing**: The clinician receives an instant combined risk rating (Low, Intermediate, High) with recommendations and confidence intervals. They can generate and print a formal clinical PDF referral report with signature blocks for department head sign-off.

---

## System Architecture

The application is structured on a modern, decoupled client-server architecture built for enterprise stability and low latency:

```mermaid
graph TD
    subgraph Frontend [Mobile Client - Flutter]
        UI[Surgical Luxury UI]
    end
    
    subgraph Backend [FastAPI Server]
        API[REST Endpoints]
        Auth[PyJWT Auth]
        DB[(PostgreSQL Database)]
    end
    
    subgraph AIEngine [Hybrid AI Engine]
        ML[Scikit-Learn ML Model]
        DL[TensorFlow MobileNetV2]
        Heuristics[OpenCV Heuristics]
    end
    
    UI <-->|HTTP/REST| API
    API <--> Auth
    API <--> DB
    API --> AIEngine
    AIEngine -->|Risk Score| API
```

### 1. Mobile Frontend (Flutter and Dart)
A native-performance client implementing stateful flows, secure API integrations, native camera image capture, PDF rendering, and interactive graphing engines.

### 2. Backend API (Python and FastAPI)
A high-performance asynchronous web API that manages session state, JWT authentications, PostgreSQL transaction sessions, database updates, and delegates concurrent CPU/GPU workloads to the AI engine.

### 3. Database Layer (PostgreSQL)
A relational database storing clinician accounts, patient information profiles, and historical clinical cases. It automatically builds schema structures on backend startup via SQLAlchemy ORM.

---

## Database Schema & Relations

The PostgreSQL database contains tables managed dynamically via SQLAlchemy ORM on backend server startup. The tables are structured as follows:

```mermaid
erDiagram
    CLINICIANS {
        integer id PK
        string name
        string email UK
        string pass_hash
        string photo_path
    }
    PATIENTS {
        string patient_id PK
        string name
        integer age
        string sex
        string photo_path
        text clinical_json
        string doctor_id
        bigint last_updated
    }
    CASES {
        integer id PK
        string patient_id
        string patient_name
        string doctor_id
        bigint created_at
        string image_path
        text clinical_json
        float risk_score
        float clinical_score
        float visual_score
        string risk_category
        string biopsy_recommendation
        string confidence
        text risk_explanation_json
        text suggestions_json
        string status
    }
    APP_SETTINGS {
        string key PK
        string value
    }
    
    CLINICIANS ||--o{ PATIENTS : "registers"
    CLINICIANS ||--o{ CASES : "assesses"
    PATIENTS ||--o{ CASES : "has"
```

### Database Tables Breakdown
* **`clinicians` Table**: Stores the credential records of registered dental professionals. Hashed credentials (`pass_hash` using bcrypt SHA-256) are used for authentication.
* **`patients` Table**: Houses persistent profiles of clinical patients. `clinical_json` stores structured demographics and history states that auto-populate on lookup.
* **`cases` Table**: Captures individual diagnostic records. Each case stores the final fused AI scores, biopsy guidelines, confidence markers, risk explanation bullets (`risk_explanation_json`), and differential diagnosis suggestions (`suggestions_json`).
* **`app_settings` Table**: Stores internal application configurations and global metadata variables.

---

## Hybrid AI Inference Engine

The core clinical value of Saveetha Oral Sentry is its hybrid risk model. It integrates three separate analytical methods to compute a final risk percentage:

```mermaid
graph TD
    %% Inputs
    A[Lesion Image File] -->|Step 1: Upload| D[/predict_full endpoint/]
    B[Patient History & Exam Data] -->|Step 1: Upload| D
    
    %% Processing splits
    D -->|Extracts Tabular Data| E[clinical_model.pkl Scikit-Learn]
    D -->|Extracts Image| F[oral_risk_mobilenet.h5 TensorFlow]
    D -->|Runs OpenCV| G[Computer Vision Heuristics]
    
    %% Internal steps
    subgraph FastAPI Backend App
        E -->|Calculates| H[Clinical Risk Score 60%]
        F -->|Calculates| I[Visual Risk Score 40%]
        G -->|Detects| J[Erythema, Margins, Textures]
        
        H -->|Weighted Integration| K[Final Risk Score 0-100%]
        I -->|Weighted Integration| K
        
        K -->|Triggers| L[Risk Category & Recommendation]
    end
    
    %% Output to UI
    L -->|JSON Response| M[Flutter App UI Dashboard]
    J -->|JSON Response| M
```

### 1. Tabular Machine Learning (clinical_model.pkl) - 60% Weight
* Evaluates patient demographics (age, sex), habits (smoking status, duration, alcohol intake), clinical examination metrics (site, size, shape, margins), and red-flag symptoms (induration, node mobility, paraesthesia).
* Uses a Scikit-Learn Random Forest model to calculate a clinical risk probability.

### 2. Visual Deep Learning (oral_risk_mobilenet.h5) - 40% Weight
* Implements a Convolutional Neural Network (CNN) built on a pre-trained MobileNetV2 architecture, optimized for clinical mobile environments.
* Analyzes pixel variations, lesion shape, color, and cell-boundary irregularities.

### 3. OpenCV Color and Texture Heuristics
* Runs real-time image filter processes to compute structural redness indicators (Erythema intensity) and boundary definitions.
* Generates clear, human-readable visual flags (e.g., "Irregular borders detected", "High redness index").

### Hybrid Risk Score Integration
$$\text{Final Risk Score} = (\text{Clinical Score} \times 0.6) + (\text{Visual Score} \times 0.4)$$

The final score categorizes cases into risk profiles:
* **High Risk (>= 70%)**: Action: Urgent Biopsy Required.
* **Intermediate Risk (35% - 69%)**: Action: Close Monitoring / Incisional Biopsy.
* **Low Risk (< 35%)**: Action: Topical Management / Review in 2 weeks.

---

## SPSS Statistical Results

To validate the application's real-world usability and efficiency, we conducted a rigorous comparative usability study between the Android Native Client and Web Client versions across 50 simulated clinical test cases. The data was analyzed using IBM SPSS Statistics (Independent Samples T-Test).

### Platform Performance Summary Table

| Evaluation Criteria | Android (Mean) | Web (Mean) | P-Value (Sig. 2-tailed) | Statistical Significance |
| :--- | :---: | :---: | :---: | :---: |
| **Speed (Execution)** | 120.0 ms | 257.0 ms | **0.001** | Highly Significant (p < 0.05) |
| **Response Time** | 1.24 s | 2.66 s | **0.002** | Highly Significant (p < 0.05) |
| **User Satisfaction** | 4.60 / 5 | 3.60 / 5 | **0.012** | Significant (p < 0.05) |
| **Ease of Use (SUS)** | 4.42 / 5 | 3.68 / 5 | **0.008** | Significant (p < 0.05) |
| **Efficiency (Task Time)** | 45.8 s | 68.4 s | **0.003** | Significant (p < 0.05) |
| **Error Rate (Avg)** | 0.20 | 1.40 | **0.004** | Significant (p < 0.05) |
| **Data Consumption** | 30.15 ms | 28.00 ms | **0.209** | Not Significant (p > 0.05) |

*Note: The Android application demonstrated significantly faster performance, higher usability scores (SUS), and lower error rates due to native hardware acceleration and custom mobile optimizations.*

### SPSS Output Screenshots and Bar Graphs

#### 1. SPSS Output Viewer T-Test Results
<p align="center">
  <img src="docs/images/spss_output.png" width="600" alt="SPSS Output Viewer T-Test">
</p>

#### 2. Key Performance Metrics Comparison (95% Confidence Interval)
| Mean Execution Speed (ms) | Mean Usability Rating (1-5) | Mean Data Consumption |
| :---: | :---: | :---: |
| <img src="docs/images/spss_speed_bar.png" width="250"> | <img src="docs/images/spss_usability_bar.png" width="250"> | <img src="docs/images/spss_dataconsumption_bar.png" width="250"> |

---

## Installation and Setup

### Prerequisites

* **Flutter SDK**: v3.16.x or newer
* **Python**: v3.10.x or newer
* **PostgreSQL**: v14.x or newer
* **Dart**: v3.x

### Backend Setup (FastAPI)

1. Navigate to the backend directory:
   ```bash
   cd ML_backend
   ```
2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Set your environment variables (create a `.env` file or export them):
   ```env
   DATABASE_URL=postgresql://username:password@localhost:5432/oral_ulcer_ai
   ```
4. Place your model files (`clinical_model.pkl` and `oral_risk_mobilenet.h5`) into the root of the `ML_backend` folder.
5. Run the FastAPI development server:
   ```bash
   uvicorn app:app --host 0.0.0.0 --port 8000 --reload
   ```

### Frontend Setup (Flutter)

1. Navigate to the frontend directory:
   ```bash
   cd flutter_application_1
   ```
2. Fetch Dart dependencies:
   ```bash
   flutter pub get
   ```
3. Build the application:
   * **Android APK release**:
     ```bash
     flutter build apk --release
     ```
   * **Web Client compilation**:
     ```bash
     flutter build web --release
     ```
4. Run the application locally in development mode:
   ```bash
   flutter run
   ```

---

## API Reference

### POST /auth/signup (Clinician Registration)

* **Payload**:
  ```json
  {
    "name": "Dr. Sanhith",
    "email": "doctor@hospital.org",
    "password": "SecurePassword123"
  }
  ```
* **Response (Success)**:
  ```json
  {
    "success": true,
    "access_token": "eyJhbGciOi...",
    "user": {
      "id": 1,
      "name": "Dr. Sanhith",
      "email": "doctor@hospital.org",
      "photo_path": ""
    }
  }
  ```

### POST /predict_full (Hybrid AI Scoring Endpoint)

* **Type**: `Multipart Form-Data`
* **Parameters**:
  * `case_id`: `123` (Integer)
  * `clinical_json`: Stringified diagnostic variables JSON.
  * `image`: Lesion image file (File upload).
* **Response**:
  ```json
  {
    "success": true,
    "finalRiskScore": 76.5,
    "clinicalRiskScore": 82.0,
    "visualRiskScore": 68.2,
    "riskCategory": "High Risk",
    "biopsyRecommendation": "Urgent Biopsy Required",
    "confidence": "85%",
    "riskExplanation": [
      "Duration > 3 weeks",
      "Induration present on palpation",
      "Irregular lesion margins detected"
    ],
    "clinicalSuggestions": [
      "Oral Squamous Cell Carcinoma",
      "Potentially malignant disorder"
    ]
  }
  ```

---

## Future Roadmap

- [ ] **Real-Time Cloud Synchronization**: Implement Firebase / Supabase synchronizations to enable multi-device medical workflows.
- [ ] **Retraining & Expansion**: Re-train the CNN model with 10,000+ clinical images across diverse demographic profiles.
- [ ] **Cross-Platform Release**: Deploy to Apple App Store for native iOS device support.

---

## Contributors

* **Thikkavarapu Sanhith** - Lead Developer & AI Researcher
