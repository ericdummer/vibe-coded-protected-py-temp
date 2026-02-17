from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health_check():
    """
    Health check endpoint.
    Returns the status of the application.
    """
    return {"status": "healthy", "message": "Application is running"}


@router.get("/")
async def root():
    """
    Root endpoint.
    Returns a welcome message.
    """
    return {"message": "Welcome to Vibe Coded Protected API"}
