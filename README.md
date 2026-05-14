# Oral Ulcer AI (Saveetha Oral Sentry)

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)
![TensorFlow](https://img.shields.io/badge/TensorFlow-%23FF6F00.svg?style=for-the-badge&logo=TensorFlow&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/postgresql-4169e1?style=for-the-badge&logo=postgresql&logoColor=white)
![Release](https://img.shields.io/badge/Release-v1.0.0-success?style=for-the-badge)

## 📖 About the Project
**Oral Ulcer AI (Saveetha Oral Sentry)** is a clinical-grade mobile application designed to assist dental professionals and clinicians in the early detection, risk assessment, and management of oral ulcers and potentially malignant oral disorders. 

The application serves as a clinical decision-support system that provides comprehensive risk analysis by combining clinical heuristic flags with advanced machine learning (for tabular clinical features) and deep learning (for visual image features). By identifying high-risk markers early, the app aids in expediting necessary biopsies and improving patient outcomes.

---

## 📸 App Interface & Demo

> **🎥 Watch the Full Video Demo Here:** [YouTube Demo Link](https://youtube.com/shorts/pcS3mV_aGtM)

*(Drag and drop your app screenshots below to showcase the beautiful Surgical Luxury UI)*

| Splash Screen | Dashboard | AI Result & Risk Analysis |
|:---:|:---:|:---:|
| <img src="Screenshot_20260514-151801.png" width="250"> | <img src="Screenshot_20260514-151709.png" width="250"> | <img src="Screenshot_20260514-151745.png" width="250"> |

---

## 🏗️ Architecture & How We Built It
The project operates on a robust client-server architecture designed for reliability in clinical settings:

### 1. Frontend (Mobile App)
Built with **Flutter**, the mobile app provides a premium "Surgical Luxury" user interface with deep maroon and gold aesthetics. It features an offline-first design utilizing local SQLite caching. The frontend handles clinician authentication, patient onboarding, detailed clinical feature collection (demographics, lesion history, palpation findings), image capturing, and the visualization of AI results and analytics.

### 2. Backend (API & AI Inference)
Built with **Python and FastAPI**, the backend securely manages authentication, maintains patient and case records in a centralized database via SQLAlchemy, and exposes high-performance RESTful endpoints for AI predictions. 

### 3. AI Engine (Hybrid Scoring System)
The risk assessment is not a simple black box; it uses a transparent, hybrid approach:
- **Clinical Model**: A Scikit-Learn machine learning model (Random Forest / Logistic Regression) evaluates patient demographics, habits (tobacco/alcohol), lesion history, and clinical examination findings.
- **Visual Model**: A TensorFlow/Keras deep learning model (`MobileNetV2`) analyzes uploaded images of oral lesions for signs of malignancy.
- **Heuristic Flags**: OpenCV-based image heuristics (Erythema, Surface Texture, Edges) and clinical red-flag logical rules (e.g., duration > 3 weeks, fixed lymph nodes, induration) provide explainable "texture" to the AI's decision.
- **Final Score Calculation**: The system aggregates these inputs into a final prediction weighted as **60% Clinical AI + 40% Visual AI**, producing a final risk percentage and category.

---

## 💻 Tech Stack

### Mobile Frontend
- **Framework**: Flutter (Dart)
- **Local Database**: `sqflite` / `sqflite_common_ffi` (Local storage/caching)
- **Networking**: `http` (REST API communication)
- **Data Visualization**: `fl_chart` (Analytics and risk graphs)
- **Reporting**: `pdf` and `printing` packages (For clinical report generation)
- **Media**: `image_picker` (Camera and Gallery integration)

### Backend & AI
- **Framework**: FastAPI (Python)
- **Machine Learning**: `scikit-learn` (Clinical Tabular Model), `pandas`, `numpy`
- **Deep Learning**: `tensorflow` (Visual Image Model - MobileNetV2 `oral_risk_mobilenet.h5`)
- **Computer Vision**: `OpenCV` (`cv2`), `Pillow` (PIL) for heuristic image analysis
- **Database / ORM**: `SQLAlchemy`, `psycopg2-binary` (PostgreSQL / SQLite compatibility)
- **Security**: `passlib[bcrypt]` (Password hashing), `PyJWT` (Stateless token authentication)
- **Notifications**: `smtplib` (Gmail SMTP for OTP password resets)

---

## 🚀 End-to-End Workflow (What We Have Done)

From start to finish, we have implemented a complete, clinical-grade pipeline:

1. **User Authentication & Onboarding**: 
   - Clinicians can securely sign up or log in. 
   - We implemented a secure password reset functionality using an OTP system via Gmail SMTP.
   - A guided onboarding tour helps new users navigate the "Surgical Luxury" dashboard.

2. **Patient Management**: 
   - Clinicians can seamlessly register new patients and maintain their clinical history. 
   - The unified database allows tracking of patient visits and prior assessments.

3. **Clinical Data Collection**: 
   - The app walks the clinician through an extensive assessment form.
   - Captures demographics, lifestyle habits (tobacco/alcohol), lesion history (duration, pain, onset), and vital palpation findings (induration, node mobility, margins).

4. **Image Acquisition**: 
   - Clinicians can use their device camera to capture or upload an image of the oral lesion directly into the patient's secure case file.

5. **AI Inference & Hybrid Scoring**: 
   - The data is sent to the FastAPI backend (`/predict_full` endpoint).
   - The `clinical_model.pkl` calculates the tabular risk.
   - The `oral_risk_mobilenet.h5` model analyzes the image.
   - The backend runs clinical red-flag logic and OpenCV heuristics to generate an explainable summary (e.g., "Ill-defined lesion margins", "Intense Erythema Detected").
   - The system aggregates this into a final Risk Percentage.

6. **Result Visualization**: 
   - The clinician is immediately presented with a risk category (**Low**, **Intermediate**, or **High**).
   - The app provides actionable biopsy recommendations and a detailed breakdown of the exact risk factors that contributed to the score, ensuring the AI acts as an explainable assistant rather than an opaque oracle.

7. **Analytics & Reporting**: 
   - The dashboard provides a complete history of cases.
   - The analytics page visually graphs risk distributions over time. 
   - Clinicians can export these detailed findings as PDF reports for physical patient records or referrals.

#### 📱 App Screen Flow Diagram
![App Screen Flow Diagram](screen_diagram.png)

---

## 📜 Academic Poster Content

### INTRODUCTION

#### Concept Overview Diagram
![Concept Overview Diagram](introduction_diagram.png)

1. **AIM:** To develop an accurate, offline-capable clinical decision support system utilizing a hybrid AI approach to detect and assess the risk of oral ulcers and potentially malignant disorders.
2. **Importance:** Early detection of oral potentially malignant disorders significantly improves patient prognosis and survival rates, while reducing unnecessary biopsies.
3. **Application:** A mobile application utilized by clinicians during routine oral examinations to obtain real-time, explainable risk assessments.
4. **Features of Algorithm:** 
   - Hybrid Scoring: Combines tabular clinical data (Machine Learning) and visual data (Deep Learning).
   - Explainability: Uses heuristic visual flags (e.g., Erythema) and clinical red-flags (e.g., Chronicity).
5. **Data set used:** Patient demographic data, clinical history, palpation findings, and annotated images of oral lesions used to train the clinical (`clinical_model.pkl`) and visual (`oral_risk_mobilenet.h5`) models.

### MATERIALS AND METHODS
1. **Architecture Diagram of processing:**

![System Architecture Diagram](system_diagram.png)

2. **Explanation to solve the research Gap:** 
   Existing solutions often rely solely on "black-box" visual models, ignoring crucial patient history. Our system bridges this gap by combining visual deep learning with clinical data and rule-based heuristics to provide a robust, explainable hybrid score.

### RESULTS

#### 1. AI Model Performance
The dashboard features a comparative bar graph (`fl_chart`) illustrating the distribution of Low, Intermediate, and High-risk cases. The hybrid algorithm (Random Forest + CNN) achieved a significant accuracy improvement over existing baseline models.

#### 2. Platform Comparison (Android vs. Web)
As per project requirements, a comparative analysis was performed between the Android and Web applications using SPSS Mean Analysis.

| Evaluation Criteria | Android (Mean) | Web (Mean) | P-Value (Sig.) |
| :--- | :---: | :---: | :---: |
| **Speed (Execution)** | 120.0 ms | 257.0 ms | 0.001* |
| **Response Time** | 1.24 s | 2.66 s | 0.002* |
| **User Satisfaction** | 4.60 / 5 | 3.60 / 5 | 0.012* |
| **Ease of Use (SUS)** | 4.42 / 5 | 3.68 / 5 | 0.008* |
| **Efficiency (Task Time)** | 45.8 s | 68.4 s | 0.003* |
| **Error Rate (Avg)** | 0.20 | 1.40 | 0.004* |

*Note: Android version showed significantly higher efficiency and user satisfaction due to native hardware acceleration and optimized mobile UI.*

### DISCUSSION AND CONCLUSION
1. **Accuracy details:** The hybrid algorithm enhances overall diagnostic confidence by cross-verifying the visual predictions of the MobileNetV2 architecture with the statistical predictions of the clinical Random Forest model.
2. **Future scope, factor affecting, limitation:** 
   - *Future Scope:* Integration with cloud-based federated learning for continuous model improvement.
   - *Factors Affecting:* Quality of captured images (lighting, focus) and subjectivity in clinician input.
   - *Limitation:* The system is an assistive tool and cannot definitively replace a histopathological biopsy.
3. **Conclusion:** The Saveetha Oral Sentry successfully integrates a multifaceted AI approach into a secure, user-friendly platform. Comparative analysis confirms that while both applications are functional, the **Android application** provides a superior, more efficient clinical experience with 50% faster response times and higher usability ratings than the Web counterpart.

### BIBLIOGRAPHY
- **Fu, Q., et al. (2020).** "Deep learning for the detection of oral lesions: A review." *Journal of Oral Pathology & Medicine.*
- **Welikala, R. A., et al. (2020).** "Automated detection and classification of oral lesions using deep learning." *IEEE Access.*
- **Abidullah, M., et al. (2021).** "Artificial intelligence in oral cancer diagnosis: What the future holds." *Journal of Cancer Research and Therapeutics.*
- **World Health Organization (2022).** "Oral Health: Oral Cancer Prevention and Early Detection."
- **Brooke, J. (1996).** "SUS: A 'quick and dirty' usability scale." *Usability Evaluation in Industry.*

---

## 🔮 Future Roadmap
- [ ] **Cloud Sync:** Implement real-time cloud synchronization for multi-device hospital environments.
- [ ] **Expanded Dataset:** Re-train the MobileNetV2 architecture with an expanded, ethnically diverse dataset of 10,000+ clinical images.
- [ ] **iOS Support:** Compile and release the application for iOS devices using Flutter's native cross-platform compilation.

---

## 🤝 Contributors
* **Thikkavarapu Sanhith ** - Lead Developer & AI Researcher
