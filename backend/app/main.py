from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI(
    title="Backend API For Test Automation",
    version="1.0.0"
)


@app.get("/health")
def health():
    return {
        "status": "ok"
    }


@app.get("/test")
def test():
    return {
        "message": "API is working"
    }


@app.get("/test-error")
def test_error():
    return JSONResponse(
        status_code=504,
        content={
            "error": "Gateway Timeout",
            "message": "This is an intentional test error"
        }
    )
