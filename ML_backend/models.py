from sqlalchemy import Column, Integer, String, Float, Text, BigInteger
from database import Base

class Clinician(Base):
    __tablename__ = "clinicians"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    pass_hash = Column(String, nullable=False)
    photo_path = Column(String, default="")

class Patient(Base):
    __tablename__ = "patients"
    patient_id = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False)
    age = Column(Integer, nullable=False)
    sex = Column(String, nullable=False)
    photo_path = Column(String, default="")
    clinical_json = Column(Text, default="{}")
    doctor_id = Column(String, index=True, nullable=False)
    last_updated = Column(BigInteger, nullable=False)

class Case(Base):
    __tablename__ = "cases"
    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String, index=True, nullable=False)
    patient_name = Column(String, nullable=False)
    doctor_id = Column(String, index=True, nullable=False)
    created_at = Column(BigInteger, nullable=False)
    image_path = Column(String, default="")
    clinical_json = Column(Text, default="{}")
    risk_score = Column(Float, default=0.0)
    clinical_score = Column(Float, default=0.0)
    visual_score = Column(Float, default=0.0)
    risk_category = Column(String, default="PENDING")
    biopsy_recommendation = Column(String, default="")
    confidence = Column(String, default="")
    risk_explanation_json = Column(Text, default="[]")
    suggestions_json = Column(Text, default="[]")
    status = Column(String, default="Pending")

class AppSetting(Base):
    __tablename__ = "app_settings"
    key = Column(String, primary_key=True, index=True)
    value = Column(String, nullable=False)
