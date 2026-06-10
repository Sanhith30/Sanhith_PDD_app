from database import engine
from sqlalchemy import text

def update_db():
    print("Updating database schema...")
    with engine.connect() as conn:
        try:
            # Add photo_path to clinicians
            print("Adding photo_path to clinicians table...")
            conn.execute(text("ALTER TABLE clinicians ADD COLUMN IF NOT EXISTS photo_path VARCHAR DEFAULT '';"))
            
            # Add photo_path to patients
            print("Adding photo_path to patients table...")
            conn.execute(text("ALTER TABLE patients ADD COLUMN IF NOT EXISTS photo_path VARCHAR DEFAULT '';"))
            
            conn.commit()
            print("Database updated successfully!")
        except Exception as e:
            print(f"Error updating database: {e}")

if __name__ == "__main__":
    update_db()
