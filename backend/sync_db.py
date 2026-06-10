from sqlalchemy import text
from database import engine

def sync_database():
    print("Individual Transaction Syncing...")
    
    cols = [
        ("clinical_score", "FLOAT DEFAULT 0.0"),
        ("visual_score", "FLOAT DEFAULT 0.0"),
        ("status", "VARCHAR DEFAULT 'Pending'")
    ]
    
    for col, dtype in cols:
        with engine.connect() as conn:
            try:
                conn.execute(text(f"ALTER TABLE cases ADD COLUMN {col} {dtype}"))
                conn.commit()
                print(f"Successfully added {col}")
            except Exception as e:
                if "already exists" in str(e):
                    print(f"Column {col} already exists.")
                else:
                    print(f"Error on {col}: {e}")

    print("Database sync complete.")

if __name__ == "__main__":
    sync_database()
