import os
from supabase import create_client
from sqlalchemy.orm import Session
from database import SessionLocal
from models import Clinician, Patient, Case

# Supabase details
url = "https://auzhqulxnoynvkznwfzb.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1emhxdWx4bm95bnZrem53ZnpiIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MDgyNzA3OCwiZXhwIjoyMDk2NDAzMDc4fQ.7ft6YPRDD-UIEsyTq6r0w0l1tJ2JleRTJP0VYobQqtk"

supabase_client = create_client(url, key)
db: Session = SessionLocal()

def upload_file_to_supabase(local_path: str, bucket: str, folder: str, file_name: str) -> str:
    try:
        content_type = "image/png"
        if local_path.lower().endswith((".jpg", ".jpeg")):
            content_type = "image/jpeg"
            
        with open(local_path, "rb") as f:
            file_data = f.read()
            
        destination_path = f"{folder}/{file_name}"
        supabase_client.storage.from_(bucket).upload(
            path=destination_path,
            file=file_data,
            file_options={"content-type": content_type, "x-upsert": "true"}
        )
        public_url = supabase_client.storage.from_(bucket).get_public_url(destination_path)
        return public_url
    except Exception as e:
        print(f"Supabase upload failed for {file_name}: {e}")
        return ""

def migrate_clinicians():
    print("\n--- Migrating Clinicians ---")
    clinicians = db.query(Clinician).all()
    for c in clinicians:
        if not c.photo_path:
            continue
        if c.photo_path.startswith("http"):
            print(f"Clinician {c.id} already has a public URL: {c.photo_path}")
            continue
            
        # Parse local file name
        file_name = os.path.basename(c.photo_path)
        local_path = os.path.join("static", "profile_photos", file_name)
        
        # Handle missing file
        if not os.path.exists(local_path):
            print(f"File {local_path} not found locally. Looking for fallback clinician photo...")
            # Fallback to any clinician photo we have
            fallbacks = [f for f in os.listdir(os.path.join("static", "profile_photos")) if f.endswith((".png", ".jpg", ".jpeg"))]
            if fallbacks:
                local_path = os.path.join("static", "profile_photos", fallbacks[0])
                print(f"Using fallback: {local_path}")
            else:
                print("No clinician photo fallbacks found.")
                continue
                
        print(f"Uploading {local_path} for clinician {c.id}...")
        public_url = upload_file_to_supabase(local_path, "clinical-images", "doctor_photos", file_name)
        if public_url:
            c.photo_path = public_url
            print(f"Success: Clinician {c.id} updated to {public_url}")
        else:
            print(f"Failed to migrate clinician {c.id}")
            
    db.commit()

def migrate_patients():
    print("\n--- Migrating Patients ---")
    patients = db.query(Patient).all()
    for p in patients:
        if not p.photo_path:
            continue
        if p.photo_path.startswith("http"):
            print(f"Patient {p.patient_id} already has a public URL: {p.photo_path}")
            continue
            
        file_name = os.path.basename(p.photo_path)
        local_path = os.path.join("static", "patient_photos", file_name)
        
        # Handle missing file
        if not os.path.exists(local_path):
            print(f"File {local_path} not found locally. Looking for fallback patient photo...")
            fallbacks = [f for f in os.listdir(os.path.join("static", "patient_photos")) if f.endswith((".png", ".jpg", ".jpeg"))]
            if fallbacks:
                local_path = os.path.join("static", "patient_photos", fallbacks[0])
                print(f"Using fallback: {local_path}")
            else:
                print("No patient photo fallbacks found.")
                continue
                
        print(f"Uploading {local_path} for patient {p.patient_id}...")
        public_url = upload_file_to_supabase(local_path, "clinical-images", "patient_photos", file_name)
        if public_url:
            p.photo_path = public_url
            print(f"Success: Patient {p.patient_id} updated to {public_url}")
        else:
            print(f"Failed to migrate patient {p.patient_id}")
            
    db.commit()

def migrate_cases():
    print("\n--- Migrating Cases ---")
    cases = db.query(Case).all()
    for c in cases:
        if not c.image_path:
            continue
        if c.image_path.startswith("http"):
            print(f"Case {c.id} already has a public URL: {c.image_path}")
            continue
            
        file_name = os.path.basename(c.image_path)
        local_path = os.path.join("static", "uploads", file_name)
        
        # Handle missing file
        if not os.path.exists(local_path):
            print(f"File {local_path} not found locally. Looking for fallback case photo...")
            fallbacks = [f for f in os.listdir(os.path.join("static", "uploads")) if f.endswith((".png", ".jpg", ".jpeg"))]
            if fallbacks:
                local_path = os.path.join("static", "uploads", fallbacks[0])
                print(f"Using fallback: {local_path}")
            else:
                print("No case photo fallbacks found.")
                continue
                
        print(f"Uploading {local_path} for case {c.id}...")
        public_url = upload_file_to_supabase(local_path, "clinical-images", "case_photos", file_name)
        if public_url:
            c.image_path = public_url
            print(f"Success: Case {c.id} updated to {public_url}")
        else:
            print(f"Failed to migrate case {c.id}")
            
    db.commit()

if __name__ == "__main__":
    try:
        migrate_clinicians()
        migrate_patients()
        migrate_cases()
        print("\n=== Asset Migration Completed Successfully! ===")
    except Exception as e:
        print(f"Migration error: {e}")
    finally:
        db.close()
