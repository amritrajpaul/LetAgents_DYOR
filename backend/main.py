from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# Allow all origins for development; restrict in production
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def read_root():
    """Health check route."""
    return {"message": "Backend up"}

# To run locally:
# uvicorn backend.main:app --host 0.0.0.0 --port 8000
