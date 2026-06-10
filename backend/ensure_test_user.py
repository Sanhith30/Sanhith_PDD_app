
from sqlalchemy.orm import Session
from database import SessionLocal
import models
from auth import get_password_hash

def reset_test_user():
    db = SessionLocal()
    try:
        email = "san@gmail.com"
        password = "Saveetha@123"
        user = db.query(models.Clinician).filter(models.Clinician.email == email).first()
        if not user:
            user = models.Clinician(name="Test User", email=email, pass_hash=get_password_hash(password))
            db.add(user)
            print(f"Created new user: {email}")
        else:
            user.pass_hash = get_password_hash(password)
            print(f"Reset password for user: {email}")
        db.commit()
        print(f"Login with: {email} / {password}")
    finally:
        db.close()

if __name__ == "__main__":
    reset_test_user()
