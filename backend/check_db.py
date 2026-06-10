from sqlalchemy import text
from database import engine

def check_columns():
    with engine.connect() as conn:
        result = conn.execute(text("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'cases'
        """))
        columns = [row[0] for row in result]
        print(f"Current columns in 'cases' table: {columns}")

if __name__ == "__main__":
    check_columns()
