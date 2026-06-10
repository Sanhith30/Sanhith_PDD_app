from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

import urllib.parse
import os

# Supabase Cloud Database is the default connection
DEFAULT_DB_URL = "postgresql://postgres.auzhqulxnoynvkznwfzb:k27%2FnUf%2Fy.%23Jh%2Ci@aws-1-ap-south-1.pooler.supabase.com:5432/postgres"

SQLALCHEMY_DATABASE_URL = os.environ.get("DATABASE_URL", DEFAULT_DB_URL)

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
