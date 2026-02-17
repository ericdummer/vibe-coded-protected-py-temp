from fastapi import FastAPI
from app.core.config import get_settings
from app.api.routes import router

settings = get_settings()

# Create FastAPI application instance
app = FastAPI(
    title=settings.app_name,
    debug=settings.debug,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Include routers
app.include_router(router, tags=["general"])


@app.on_event("startup")
async def startup_event():
    """
    Run on application startup.
    Initialize database connections, etc.
    """
    pass


@app.on_event("shutdown")
async def shutdown_event():
    """
    Run on application shutdown.
    Close database connections, cleanup resources, etc.
    """
    pass


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )
