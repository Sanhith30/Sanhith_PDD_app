import sys
from sqlalchemy.orm import Session
from database import SessionLocal
from models import Clinician, Patient, Case

def view_data():
    db: Session = SessionLocal()
    try:
        print("\n=================== SUPABASE DATABASE VIEW ===================")
        
        # 1. Clinicians
        print("\n👥 Table: CLINICIANS")
        clinicians = db.query(Clinician).all()
        if not clinicians:
            print("  (Empty)")
        for c in clinicians:
            print(f"  ID: {c.id} | Name: {c.name} | Email: {c.email} | Photo Path: {c.photo_path}")
            
        # 2. Patients
        print("\n🏥 Table: PATIENTS")
        patients = db.query(Patient).all()
        if not patients:
            print("  (Empty)")
        for p in patients:
            print(f"  Patient ID: {p.patient_id} | Name: {p.name} | Age: {p.age} | Sex: {p.sex} | Doctor: {p.doctor_id}")
            
        # 3. Cases
        print("\n📁 Table: CASES")
        cases = db.query(Case).all()
        if not cases:
            print("  (Empty)")
        for c in cases:
            print(f"  ID: {c.id} | Patient ID: {c.patient_id} | Name: {c.patient_name} | Doctor: {c.doctor_id} | Risk Category: {c.risk_category} | Score: {c.risk_score}% | Status: {c.status}")
            
        print("\n==============================================================")
    except Exception as e:
        print(f"Error querying database: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    view_data()
