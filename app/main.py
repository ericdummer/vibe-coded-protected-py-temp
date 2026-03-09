from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.core.config import get_settings
from app.api.routes import router
from app.api.mcp import router as mcp_router

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan event handler for application startup and shutdown.
    """
    # Startup: Initialize database connections, etc.
    yield
    # Shutdown: Close database connections, cleanup resources, etc.


# Create FastAPI application instance
app = FastAPI(
    title=settings.app_name,
    debug=settings.debug,
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# Include routers
app.include_router(router, tags=["general"])
app.include_router(mcp_router, prefix="/mcp", tags=["mcp"])


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )
