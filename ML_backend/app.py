from fastapi import FastAPI, HTTPException
import json
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session
import joblib
import pandas as pd
import numpy as np
import models
from database import engine, get_db
from auth import verify_password, get_password_hash, create_access_token, get_current_clinician
from fastapi import Depends, UploadFile, File, Form
import logging
import os

# Ensure temp directory exists
os.makedirs("temp_uploads", exist_ok=True)
import shutil
import shutil
from visual_analysis import analyze_lesion_image
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import random
import time
import tensorflow as tf

# --- 0. CONFIGURE LOGGING ---
# Move log file to a sub-folder to avoid uvicorn reload loop
log_dir = os.path.join(os.path.dirname(__file__), "logs")
if not os.path.exists(log_dir):
    os.makedirs(log_dir)

log_file = os.path.join(log_dir, "backend_debug.log")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("backend")
logger.info("--- BACKEND STARTING UP ---")

# Create tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Oral Ulcer AI Clinical Risk API")

# --- 1. ENABLE CORS FOR FLUTTER CONNECTION ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins (update with specific IPs in production)
    allow_credentials=True,
    allow_methods=["*"],  # Allows all HTTP methods (POST, GET, etc.)
    allow_headers=["*"],  # Allows all headers
)

# --- 2. GMAIL CONFIGURATION ---
# IMPORTANT: Generate an "App Password" in your Google Account settings
# to use your Gmail address for sending automated emails.
GMAIL_USER = "oralverfication@gmail.com"
GMAIL_PASS = "idef grlc mgyv rcnt"

# In-memory store for OTPs: { email: {"code": "123456", "expiry": timestamp} }
otp_store = {}

def send_otp_email(receiver_email, otp_code):
    try:
        msg = MIMEMultipart()
        msg['From'] = GMAIL_USER
        msg['To'] = receiver_email
        msg['Subject'] = "Saveetha Oral Sentry - Verification Code"

        body = f"""
        Dear Clinician,

        Your verification code for password reset is: {otp_code}

        This code will expire in 10 minutes. If you did not request this reset, please ignore this email.

        Regards,
        Saveetha Oral Sentry Team
        """
        msg.attach(MIMEText(body, 'plain'))

        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(GMAIL_USER, GMAIL_PASS)
        server.send_message(msg)
        server.quit()
        return True
    except Exception as e:
        logger.error(f"EMAIL ERROR: {e}")
        return False

# --- 2. LOAD TRAINED MODELS ---
try:
    # 1. Clinical Risk Model (Random Forest / Logistic Regression)
    model = joblib.load("clinical_model.pkl") 
    print("Clinical model loaded successfully.")
except Exception as e:
    print(f"Error loading clinical model: {e}")
    model = None

try:
    # 2. Visual Risk Model (MobileNetV2 .h5)
    image_model = tf.keras.models.load_model("oral_risk_mobilenet.h5")
    print("Image analysis model loaded successfully.")
except Exception as e:
    print(f"Error loading image model: {e}. Ensure 'oral_risk_mobilenet.h5' is in the same directory.")
    image_model = None

# -----------------------------
# Input Schema (All Features)
# -----------------------------
class ClinicalInput(BaseModel):
    # Demographics
    age: int
    sex: str
    smoking_status: str
    smoking_duration: int
    smoking_frequency: str
    smokeless_tobacco: int
    alcohol: str
    diabetes: int
    immunocompromised: int
    autoimmune: int
    steroids: int
    chemotherapy: int
    immunosuppressants: int

    # Lesion History
    duration: str
    onset: str
    recurrence: str
    pain: str
    healing_pattern: str

    # Clinical Examination
    site: str
    size_mm: int
    shape: str
    margins: str
    edge: str
    induration: int
    bleeding: int

    # Associated Findings
    lymph_palpable: int
    tender: int
    node_mobility: str
    paraesthesia: int
    weight_loss: int
    fever: int

# -----------------------------
# Granular Risk Calculation
# -----------------------------
def calculate_clinical_red_flag_score(data):
    """
    Calculates a risk percentage (0-100) based on standard clinical red flags.
    This provides 'texture' to the risk score even if the ML model is binary.
    """
    score = 0
    
    # 1. Chronicity (Duration > 3 weeks is a major indicator)
    if data.get("duration") in ["> 3 weeks", ">3 weeks"]:
        score += 15
        
    # 2. Tobacco Use
    if data.get("smoking_status") in ["Current", "Past"]:
        score += 10
    if data.get("smokeless_tobacco") == 1:
        score += 10
        
    # 3. High-Risk Anatomical Site
    site = data.get("site", "")
    if any(keyword in site for keyword in ["Lateral", "Ventral", "Floor", "Tongue"]):
        score += 15
        
    # 4. Palpation Findings (Induration is high risk)
    if data.get("induration") == 1:
        score += 15
        
    # 5. Lymph Node Involvement (Fixed nodes are very high risk)
    if data.get("node_mobility") == "Fixed":
        score += 20
        
    # 6. Edge/Margin Characteristics
    if "Everted" in data.get("edge", ""):
        score += 10
    if data.get("margins") == "Ill-defined":
        score += 10
        
    # 7. Pain (Painless ulcers are often more suspicious)
    if data.get("pain") == "Painless":
        score += 10

    # 8. Associated Symptoms
    if data.get("paraesthesia") == 1:
        score += 10
    if data.get("weight_loss") == 1:
        score += 10

    return min(score, 100)


# -----------------------------
# Risk Classification Logic
# -----------------------------
def classify_risk(score):
    if score >= 75: # Aligned with typical clinical high-risk thresholds
        return "High", "Biopsy strongly indicated"
    elif score >= 40:
        return "Intermediate", "Close follow-up / biopsy if persists"
    else:
        return "Low", "Conservative management"


# -----------------------------
# Enhanced Explanation Generator
# -----------------------------
def generate_explanation(data):
    explanation = []
    
    # Matches features defined in Feature Requirements.docx
    if data.get("duration") in ["> 3 weeks", ">3 weeks"]:
        explanation.append("Duration > 3 weeks")
    if data.get("induration") == 1:
        explanation.append("Induration present on palpation")
    if data.get("margins") == "Ill-defined":
        explanation.append("Ill-defined lesion margins")
    if data.get("node_mobility") == "Fixed":
        explanation.append("Fixed lymph node mobility")
    if data.get("weight_loss") == 1:
        explanation.append("Unexplained weight loss")
    if data.get("smoking_status") in ["Current", "Past"]:
        explanation.append("History of tobacco use")
    if data.get("pain") == "Painless":
        explanation.append("Painless ulcer presentation")
    if "Everted" in data.get("edge", ""):
        explanation.append("Everted lesion edge")
    if data.get("bleeding") == 1:
        explanation.append("Bleeding on touch")
    if data.get("paraesthesia") == 1:
        explanation.append("Paraesthesia or anaesthesia present")
        
    # Check for High-Risk Sites
    site = data.get("site", "")
    if "Lateral" in site or "Ventral" in site or "Floor" in site:
        explanation.append(f"High-risk anatomical site ({site.replace(' ⚠️', '')})")

    if not explanation:
        explanation.append("No immediate high-risk clinical flags identified.")

    return explanation


# -----------------------------
# Clinical Suggestions
# -----------------------------
def generate_suggestions(category):
    if category == "High":
        return [
            "Oral Squamous Cell Carcinoma",
            "Potentially malignant disorder",
            "Severe epithelial dysplasia"
        ]
    elif category == "Intermediate":
        return [
            "Leukoplakia",
            "Chronic traumatic ulcer",
            "Lichen planus"
        ]
    else:
        return [
            "Aphthous ulcer",
            "Minor traumatic ulcer",
            "Benign mucosal lesion"
        ]


# -----------------------------
# Prediction Endpoint
# -----------------------------
@app.post("/predict")
def predict_clinical_risk(input_data: ClinicalInput):
    logger.info(f"PREDICT: Received request for age {input_data.age}")
    if model is None:
        logger.error("PREDICT: Model is not loaded!")
        raise HTTPException(status_code=500, detail="ML Model is not loaded on the server.")

    # 1. Convert input to dict safely
    input_dict = input_data.model_dump() if hasattr(input_data, 'model_dump') else input_data.dict()
    
    # Generate explanations BEFORE translating the text, so the doctor gets the readable version
    explanation = generate_explanation(input_dict)

    # =========================================================
    # 🔥 THE FIX: TRANSLATE FLUTTER TEXT TO STRICT AI MODEL TEXT
    # =========================================================
    # Fix Duration
    if input_dict.get('duration') == "< 2 weeks": input_dict['duration'] = "<2 weeks"
    elif input_dict.get('duration') == "> 3 weeks": input_dict['duration'] = ">3 weeks"

    # Fix Recurrence
    if input_dict.get('recurrence') == "First episode": input_dict['recurrence'] = "First"
    elif input_dict.get('recurrence') == "Recurrent (same site)": input_dict['recurrence'] = "Same site"
    elif input_dict.get('recurrence') == "Recurrent (different sites)": input_dict['recurrence'] = "Different site"

    # Fix Site
    if input_dict.get('site') == "Tongue (Lateral)": input_dict['site'] = "Lateral tongue"
    elif input_dict.get('site') == "Tongue (Ventral)": input_dict['site'] = "Ventral tongue"
    elif input_dict.get('site') == "Buccal Mucosa": input_dict['site'] = "Buccal mucosa"
    elif input_dict.get('site') == "Floor of Mouth": input_dict['site'] = "Floor of mouth"

    # Fix Shape
    if input_dict.get('shape') == "Round/Ovoid": input_dict['shape'] = "Round"

    # Fix Edge
    if input_dict.get('edge') == "Punched out": input_dict['edge'] = "Punched"
    # =========================================================

    # 2. Convert to DataFrame
    input_df = pd.DataFrame([input_dict])
    
    # DEBUG: Print features to terminal for verification
    print("\n--- AI INPUT FEATURES ---")
    print(input_df.to_dict(orient='records')[0])
    print("-------------------------\n")

    try:
        # 3. Get probability of Malignancy (Class 1)
        prob = float(model.predict_proba(input_df)[0][1])
    except Exception as e:
        logger.error(f"PREDICT: Feature mismatch or model error: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Prediction error. Feature mismatch: {str(e)}")

    # 4. Process Results
    # =========================================================
    # 🔥 HYBRID SCORING: Combine ML Model (40%) + Clinical Flags (60%)
    # =========================================================
    ml_score = prob * 100
    clinical_flag_score = calculate_clinical_red_flag_score(input_dict)
    
    # Final risk score is a weighted average
    risk_score = round((ml_score * 0.4) + (clinical_flag_score * 0.6), 1)
    
    logger.info(f"PREDICT: ML={ml_score:.1f}, Flags={clinical_flag_score}, Final={risk_score}")
    
    category, recommendation = classify_risk(risk_score)
    suggestions = generate_suggestions(category)
    
    # Calculate confidence based on how much the ML and Flags agree
    agreement = 100 - abs(ml_score - clinical_flag_score)
    confidence = round(max(agreement, 50.0), 1) 

    return {
        "success": True,
        "clinicalRiskScore": risk_score,
        "clinicalRiskCategory": category,
        "biopsyRecommendation": recommendation,
        "confidence": f"{confidence}%",
        "riskExplanation": explanation,
        "clinicalSuggestions": suggestions
    }

@app.post("/predict_full")
async def predict_full_risk(
    case_id: int = Form(...),
    clinical_json: str = Form(...),
    image: UploadFile = File(...)
):
    """
    Combined Clinical + Visual AI Prediction
    """
    # 1. Save uploaded image temporarily
    temp_dir = "temp_uploads"
    if not os.path.exists(temp_dir):
        os.makedirs(temp_dir)
    
    file_path = os.path.join(temp_dir, f"case_{case_id}_{image.filename}")
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

    try:
        # 2. Run Clinical Analysis
        clinical_data = json.loads(clinical_json)
        clinical_res = predict_clinical_risk(ClinicalInput(**clinical_data))
        
        # Safety: Handle clinical analysis failure
        clinical_score = clinical_res.get("clinicalRiskScore", 0.0)
        clinical_conf = clinical_res.get("confidence", "N/A")
        clinical_explanations = clinical_res.get("riskExplanation", ["Clinical data analysis pending."])
        clinical_suggestions = clinical_res.get("clinicalSuggestions", ["Follow standard clinical guidelines."])

        # 3. Run Visual Analysis (Passing the loaded deep learning model)
        visual_score, visual_flags = analyze_lesion_image(file_path, model=image_model)

        # 4. Combine Scores (Weighted: 60% Clinical, 40% Visual)
        final_score = (clinical_score * 0.6) + (visual_score * 0.4)

        # 5. Determine category based on combined score
        if final_score >= 70:
            category = "High Risk"
            recommendation = "Urgent Biopsy Required"
        elif final_score >= 35:
            category = "Intermediate Risk"
            recommendation = "Close Clinical Monitoring / Incisional Biopsy"
        else:
            category = "Low Risk"
            recommendation = "Topical Management / Review in 2 weeks"

        all_explanations = clinical_explanations + visual_flags

        return {
            "success": True,
            "finalRiskScore": round(final_score, 2),
            "clinicalRiskScore": clinical_score,
            "visualRiskScore": visual_score,
            "riskCategory": category,
            "biopsyRecommendation": recommendation,
            "confidence": clinical_conf,
            "riskExplanation": all_explanations,
            "clinicalSuggestions": clinical_suggestions
        }
    except Exception as e:
        logger.error(f"PREDICT_FULL: Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Cleanup temp file
        if os.path.exists(file_path):
            os.remove(file_path)

# =========================================================
# DATABASE & AUTHENTICATION ROUTES
# =========================================================

class ClinicianCreate(BaseModel):
    name: str
    email: str
    password: str

class ClinicianLogin(BaseModel):
    email: str
    password: str

@app.post("/auth/signup")
def signup(clinician: ClinicianCreate, db: Session = Depends(get_db)):
    import time
    start_time = time.time()
    print(f"DEBUG: Signup request received for {clinician.email}")
    
    db_user = db.query(models.Clinician).filter(models.Clinician.email == clinician.email.lower()).first()
    if db_user:
        print(f"DEBUG: Signup failed - Email {clinician.email} already exists")
        raise HTTPException(status_code=400, detail="Email already registered")
    
    print(f"DEBUG: Hashing password for {clinician.email}...")
    hashed_password = get_password_hash(clinician.password)
    
    print(f"DEBUG: Saving user {clinician.email} to database...")
    new_clinician = models.Clinician(name=clinician.name, email=clinician.email.lower(), pass_hash=hashed_password)
    db.add(new_clinician)
    db.commit()
    db.refresh(new_clinician)
    
    access_token = create_access_token(data={"sub": new_clinician.email})
    
    duration = time.time() - start_time
    print(f"DEBUG: Signup successful for {clinician.email} in {duration:.2f}s")
    return {
        "success": True,
        "access_token": access_token,
        "user": {"id": new_clinician.id, "name": new_clinician.name, "email": new_clinician.email, "photo_path": new_clinician.photo_path}
    }

@app.post("/auth/login")
def login(clinician: ClinicianLogin, db: Session = Depends(get_db)):
    logger.info(f"AUTH: Login attempt for {clinician.email}")
    db_user = db.query(models.Clinician).filter(models.Clinician.email == clinician.email.lower()).first()
    
    if not db_user:
        print(f"DEBUG: Login failed - User {clinician.email} not found in database")
        raise HTTPException(status_code=401, detail="Incorrect email or password")
    
    print(f"DEBUG: User found. Verifying password...")
    is_valid = verify_password(clinician.password, db_user.pass_hash)
    
    if not is_valid:
        print(f"DEBUG: Login failed - Password mismatch for {clinician.email}")
        # Log lengths for debugging
        print(f"DEBUG: Input pass length: {len(clinician.password)}, DB hash length: {len(db_user.pass_hash)}")
        raise HTTPException(status_code=401, detail="Incorrect email or password")
    
    logger.info(f"AUTH: Login successful for {clinician.email}")
    access_token = create_access_token(data={"sub": db_user.email})
    return {
        "access_token": access_token, 
        "user": {"id": db_user.id, "name": db_user.name, "email": db_user.email, "photo_path": db_user.photo_path}
    }

class ResetPasswordRequest(BaseModel):
    email: str

@app.post("/auth/reset_password")
def reset_password(req: ResetPasswordRequest, db: Session = Depends(get_db)):
    """
    Step 1: Request OTP. Generates a 6-digit code and sends to Gmail.
    """
    db_user = db.query(models.Clinician).filter(models.Clinician.email == req.email.lower()).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="Email not found")
    
    otp_code = str(random.randint(100000, 999999))
    expiry = time.time() + 600 # 10 minutes
    
    otp_store[req.email.lower()] = {"code": otp_code, "expiry": expiry}
    
    success = send_otp_email(req.email.lower(), otp_code)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to send email. Check SMTP settings.")
        
    return {"success": True, "message": "Verification code sent to Gmail"}

class ConfirmResetRequest(BaseModel):
    email: str
    otp: str
    new_password: str

@app.post("/auth/confirm_password_reset")
def confirm_password_reset(req: ConfirmResetRequest, db: Session = Depends(get_db)):
    """
    Step 2: Verify OTP and update password.
    """
    email = req.email.lower()
    if email not in otp_store:
        raise HTTPException(status_code=400, detail="No reset request found for this email")
    
    stored = otp_store[email]
    if time.time() > stored["expiry"]:
        del otp_store[email]
        raise HTTPException(status_code=400, detail="Verification code expired")
    
    if stored["code"] != req.otp:
        raise HTTPException(status_code=400, detail="Invalid verification code")
    
    db_user = db.query(models.Clinician).filter(models.Clinician.email == email).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="Clinician not found")
    
    db_user.pass_hash = get_password_hash(req.new_password)
    db.commit()
    
    # Clear OTP after success
    del otp_store[email]
    
    return {"success": True, "message": "Password updated successfully"}

class ChangePasswordRequest(BaseModel):
    email: str
    old_password: str
    new_password: str

@app.post("/auth/change_password")
def change_password(req: ChangePasswordRequest, db: Session = Depends(get_db)):
    db_user = db.query(models.Clinician).filter(models.Clinician.email == req.email.lower()).first()
    if not db_user or not verify_password(req.old_password, db_user.pass_hash):
        raise HTTPException(status_code=401, detail="Incorrect current password")
    db_user.pass_hash = get_password_hash(req.new_password)
    db.commit()
    return {"success": True}

class ProfilePhotoUpdate(BaseModel):
    photo_path: str

@app.post("/clinicians/profile_photo")
def update_profile_photo(update: ProfilePhotoUpdate, db: Session = Depends(get_db), current_user: models.Clinician = Depends(get_current_clinician)):
    db_user = db.query(models.Clinician).filter(models.Clinician.id == current_user.id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="Clinician not found")
    db_user.photo_path = update.photo_path
    db.commit()
    return {"success": True}

class PatientCreate(BaseModel):
    patient_id: str
    name: str
    age: int
    sex: str
    photo_path: str = ""
    clinical_json: str = "{}"
    doctor_id: str
    last_updated: int

@app.post("/patients")
def create_patient(patient: PatientCreate, db: Session = Depends(get_db), current_user: models.Clinician = Depends(get_current_clinician)):
    db_patient = db.query(models.Patient).filter(
        models.Patient.patient_id == patient.patient_id
    ).first()
    
    if db_patient:
        db_patient.name = patient.name
        db_patient.age = patient.age
        db_patient.sex = patient.sex
        db_patient.photo_path = patient.photo_path
        db_patient.clinical_json = patient.clinical_json
        db_patient.last_updated = patient.last_updated
        db_patient.doctor_id = patient.doctor_id # Update doctor association if needed
    else:
        new_patient = models.Patient(**patient.model_dump())
        db.add(new_patient)
    db.commit()
    return {"success": True}

@app.get("/patients/{patient_id}")
def get_patient(patient_id: str, db: Session = Depends(get_db), current_user: models.Clinician = Depends(get_current_clinician)):
    # SHARED DATA: Remove doctor_id filter so any clinician can see any patient
    return db.query(models.Patient).filter(
        models.Patient.patient_id == patient_id
    ).first()

class CaseCreate(BaseModel):
    patient_id: str
    patient_name: str
    doctor_id: str
    created_at: int
    clinical_json: str = "{}"

class CaseUpdate(BaseModel):
    image_path: str
    risk_score: float
    clinical_score: float = 0.0
    visual_score: float = 0.0
    risk_category: str
    biopsy_recommendation: str
    confidence: str
    risk_explanation_json: str
    suggestions_json: str

@app.post("/cases")
def create_case(case: CaseCreate, db: Session = Depends(get_db), current_user: models.Clinician = Depends(get_current_clinician)):
    new_case = models.Case(**case.model_dump())
    new_case.status = "Pending Image Analysis"
    db.add(new_case)
    db.commit()
    db.refresh(new_case)
    return {"id": new_case.id}

@app.put("/cases/{case_id}/complete")
def complete_case(case_id: int, case_update: CaseUpdate, db: Session = Depends(get_db), current_user: models.Clinician = Depends(get_current_clinician)):
    db_case = db.query(models.Case).filter(models.Case.id == case_id).first()
    if not db_case:
        raise HTTPException(status_code=404, detail="Case not found")
    for k, v in case_update.model_dump().items():
        setattr(db_case, k, v)
    db_case.status = "Completed"
    db.commit()
    return {"success": True}

@app.get("/cases/{case_id}")
def get_case(case_id: int, db: Session = Depends(get_db), current_user: models.Clinician = Depends(get_current_clinician)):
    from sqlalchemy import cast, String
    result = db.query(models.Case, models.Clinician.name, models.Patient.photo_path).outerjoin(
        models.Clinician, models.Case.doctor_id == cast(models.Clinician.id, String)
    ).outerjoin(
        models.Patient, models.Case.patient_id == models.Patient.patient_id
    ).filter(models.Case.id == case_id).first()
    
    if not result:
        return None
    
    case_data = result[0].__dict__.copy()
    case_data.pop('_sa_instance_state', None)
    case_data['doctor_name'] = result[1]
    case_data['patient_photo'] = result[2]
    return case_data

@app.get("/cases")
def get_cases(db: Session = Depends(get_db), current_user: models.Clinician = Depends(get_current_clinician)):
    # SHARED DATA: Get the LATEST case for each unique patient across ALL doctors
    from sqlalchemy import func
    
    subq = db.query(
        models.Case.patient_id, 
        func.max(models.Case.id).label('max_id')
    ).group_by(models.Case.patient_id).subquery()
    
    from sqlalchemy import cast, String
    results = db.query(models.Case, models.Clinician.name, models.Patient.photo_path).join(
        subq, models.Case.id == subq.c.max_id
    ).outerjoin(
        models.Clinician, models.Case.doctor_id == cast(models.Clinician.id, String)
    ).outerjoin(
        models.Patient, models.Case.patient_id == models.Patient.patient_id
    ).order_by(models.Case.created_at.desc()).all()

    final_list = []
    for r in results:
        c_dict = r[0].__dict__.copy()
        c_dict.pop('_sa_instance_state', None)
        c_dict['doctor_name'] = r[1]
        c_dict['patient_photo'] = r[2]
        final_list.append(c_dict)
    return final_list

@app.get("/patients/{patient_id}/history")
def get_patient_history(patient_id: str, db: Session = Depends(get_db), current_user: models.Clinician = Depends(get_current_clinician)):
    """
    Returns ALL cases for a specific patient across all doctors.
    Includes the doctor's name and patient's photo for each assessment.
    """
    from sqlalchemy import cast, String
    results = db.query(models.Case, models.Clinician.name, models.Patient.photo_path).outerjoin(
        models.Clinician, models.Case.doctor_id == cast(models.Clinician.id, String)
    ).outerjoin(
        models.Patient, models.Case.patient_id == models.Patient.patient_id
    ).filter(
        models.Case.patient_id == patient_id
    ).order_by(models.Case.created_at.asc()).all()

    final_list = []
    for r in results:
        c_dict = r[0].__dict__.copy()
        c_dict.pop('_sa_instance_state', None)
        c_dict['doctor_name'] = r[1]
        c_dict['patient_photo'] = r[2]
        final_list.append(c_dict)
    return final_list

# Entry point for local testing
if __name__ == '__main__':
    import uvicorn
    # Use reload=False for development to pick up changes automatically
    uvicorn.run("app:app", host='0.0.0.0', port=5000, reload=False)
