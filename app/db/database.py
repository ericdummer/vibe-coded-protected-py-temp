import psycopg2
import boto3
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from app.core.config import get_settings

settings = get_settings()


def _make_iam_connection():
    client = boto3.client("rds", region_name=settings.aws_region)
    token = client.generate_db_auth_token(
        DBHostname=settings.db_host,
        Port=settings.db_port,
        DBUser=settings.db_user,
        Region=settings.aws_region,
    )
    return psycopg2.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=settings.db_user,
        password=token,
        sslmode="require",
    )


if settings.db_iam_auth and settings.db_host:
    engine = create_engine(
        "postgresql+psycopg2://",
        creator=_make_iam_connection,
        pool_recycle=600,
        pool_pre_ping=True,
    )
else:
    engine = create_engine(
        settings.database_url,
        pool_pre_ping=True,
    )

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for ORM models
Base = declarative_base()


def get_db():
    """
    Dependency function to get database session.
    Use this in FastAPI route dependencies.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
