from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from datetime import datetime
from services.mailer import send_transaction_email
import logging

# Configure logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("hce_server")

app = FastAPI(
    title="HCE Validator Backend",
    description="Minimal REST API to process NFC transaction reports and dispatch alerts.",
    version="2.0.0",
)

# Permit all origins, credentials, headers, and methods for local testing and physical devices
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class TransactionReportRequest(BaseModel):
    payload: str = Field(..., description="Captured variable string payload via HCE")
    latitude: float = Field(..., description="GPS Latitude coordinate of Reader device")
    longitude: float = Field(..., description="GPS Longitude coordinate of Reader device")
    timestamp: str = Field(..., description="ISO 8601 formatted timestamp sent by the reader")

@app.get("/health", status_code=status.HTTP_200_OK)
async def health_check():
    """
    Simple health check endpoint to keep Render services active.
    """
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.post("/transaction-report", status_code=status.HTTP_201_CREATED)
async def transaction_report(report: TransactionReportRequest):
    """
    Receives incoming NFC Reader transaction logs, captures location data,
    and sends out a real-time email verification via MailerSend.
    """
    logger.info(
        f"Received transaction report: payload='{report.payload}', "
        f"location=({report.latitude}, {report.longitude}), timestamp={report.timestamp}"
    )

    # Prepare payload representation (allow empty payloads)
    email_payload = report.payload.strip() if report.payload.strip() else "[EMPTY PAYLOAD]"

    try:
        # Trigger Resend email dispatch
        success = send_transaction_email(
            payload=email_payload,
            latitude=report.latitude,
            longitude=report.longitude,
            timestamp_iso=report.timestamp,
        )
        if success:
            return {"status": "SUCCESS", "message": "Transaction reported and email dispatched."}
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send report email via MailerSend.",
            )
    except ValueError as val_err:
        logger.error(f"Configuration error: {val_err}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Server configuration error: {str(val_err)}",
        )
    except Exception as exc:
        logger.error(f"Internal server error: {exc}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to report transaction: {str(exc)}",
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
