import os
import logging
from dotenv import load_dotenv
import resend

# Load environment variables from .env
load_dotenv()

logger = logging.getLogger(__name__)

def send_transaction_email(payload: str, latitude: float, longitude: float, timestamp_iso: str) -> bool:
    """
    Sends a transaction report email using Resend with transaction data and location.
    """
    api_key = os.getenv("RESEND_API_KEY")
    sender_email = os.getenv("RESEND_SENDER_EMAIL")
    recipient_email = os.getenv("REPORT_RECIPIENT_EMAIL")

    if not api_key:
        logger.error("RESEND_API_KEY environment variable is not set.")
        raise ValueError("Resend API Key is missing on the server configuration.")
    if not sender_email:
        logger.error("RESEND_SENDER_EMAIL environment variable is not set.")
        raise ValueError("Resend Sender Email is missing on the server configuration.")
    if not recipient_email:
        logger.error("REPORT_RECIPIENT_EMAIL environment variable is not set.")
        raise ValueError("Report Recipient Email is missing on the server configuration.")

    # Initialize Resend Key
    resend.api_key = api_key

    # Google Maps URL
    maps_url = f"https://www.google.com/maps?q={latitude},{longitude}"

    # Build the HTML content using an elegant monospaced technical table (Editorial Design)
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>HCE Transaction Report</title>
        <style>
            body {{
                font-family: monospace;
                background-color: #ffffff;
                color: #1a1a1a;
                margin: 0;
                padding: 40px 20px;
            }}
            .container {{
                max-width: 600px;
                margin: 0 auto;
                border: 2px solid #1a1a1a;
                padding: 24px;
            }}
            .header {{
                font-size: 16px;
                font-weight: bold;
                border-bottom: 2px solid #1a1a1a;
                padding-bottom: 12px;
                margin-bottom: 24px;
                letter-spacing: 1px;
            }}
            .label {{
                font-size: 11px;
                color: #888888;
                font-weight: bold;
                text-transform: uppercase;
                margin-bottom: 4px;
            }}
            .value {{
                font-size: 14px;
                font-weight: bold;
                margin-bottom: 20px;
                word-break: break-all;
            }}
            .link-button {{
                display: inline-block;
                border: 2px solid #1a1a1a;
                color: #ffffff;
                background-color: #1a1a1a;
                padding: 10px 18px;
                text-decoration: none;
                font-weight: bold;
                font-size: 12px;
                margin-top: 10px;
            }}
            .link-button:hover {{
                background-color: #ffffff;
                color: #1a1a1a;
            }}
            .footer {{
                margin-top: 32px;
                border-top: 1px solid #e0e0e0;
                padding-top: 12px;
                font-size: 10px;
                color: #888888;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                HCE PHONE-TO-PHONE VALIDATOR REPORT
            </div>
            
            <div class="label">Transaction Payload</div>
            <div class="value">"{payload}"</div>
            
            <div class="label">Timestamp (UTC)</div>
            <div class="value">{timestamp_iso}</div>
            
            <div class="label">Location Coordinates</div>
            <div class="value">Latitude: {latitude}<br>Longitude: {longitude}</div>
            
            <div class="label">Google Maps Link</div>
            <div>
                <a href="{maps_url}" class="link-button" target="_blank">VIEW ON GOOGLE MAPS</a>
            </div>
            
            <div class="footer">
                TRANSACTION REPORT GENERATED AUTOMATICALLY BY HCE VALIDATOR SPIKE ITERATION 2.<br>
                CONFIDENTIAL • INTERNAL USE ONLY
            </div>
        </div>
    </body>
    </html>
    """

    # Build the plain text fallback
    text_content = (
        f"HCE PHONE-TO-PHONE VALIDATOR REPORT\n"
        f"===================================\n\n"
        f"Transaction Payload: \"{payload}\"\n"
        f"Timestamp (UTC): {timestamp_iso}\n"
        f"Location Coordinates: Latitude {latitude}, Longitude {longitude}\n\n"
        f"Google Maps Link: {maps_url}\n\n"
        f"Confidential • Internal Use Only\n"
    )

    try:
        # Build envelope parameters for Resend API call
        # Resend from email address format is standard
        # resend.Emails.send requires list for 'to' parameter
        params: resend.Emails.SendParams = {
            "from": f"HCE Validator Service <{sender_email}>",
            "to": [recipient_email],
            "subject": f"HCE Validator Alert: Payload {payload}",
            "html": html_content,
            "text": text_content,
        }

        # Send
        response = resend.Emails.send(params)
        logger.info(f"Email sent successfully. Resend Response: {response}")
        return True
    except Exception as e:
        logger.error(f"Resend exception encountered: {e}")
        raise RuntimeError(f"Resend API call failed: {str(e)}")
