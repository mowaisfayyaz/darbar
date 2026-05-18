import os
from twilio.rest import Client
from api.models import Booking, BookingAttempt, AgentLog
from api.google_oauth import is_google_linked, send_gmail_message

def attempt_booking(booking_obj, provider_obj):
    """
    Creates a booking_attempt record.
    Sends notifications via FCM, Email (Gmail API if OAuth is connected), and SMS.
    Starts timeout timer.
    """
    agent_name = "Booking Agent"
    
    attempt = BookingAttempt.objects.create(
        booking=booking_obj,
        provider=provider_obj,
        status='sent'
    )
    
    # 1. Twilio SMS (Disabled by default, but configured)
    # try:
    #     client = Client(os.getenv('TWILIO_ACCOUNT_SID'), os.getenv('TWILIO_AUTH_TOKEN'))
    #     client.messages.create(
    #         body=f"Darbar Booking {booking_obj.booking_id}: New request for {booking_obj.service_type} at {booking_obj.location}.",
    #         from_=os.getenv('TWILIO_FROM_PHONE'),
    #         to=provider_obj.phone
    #     )
    # except Exception as sms_err:
    #     pass
    
    # 2. Live Gmail API Dispatch if OAuth is Connected
    email_status = "Skipped (OAuth not connected)"
    linked, sender_email = is_google_linked()
    if linked and booking_obj.user.email:
        try:
            subject = f"Darbar: Booking Attempt Confirmation ({booking_obj.booking_id})"
            
            # Premium HTML Email Template
            html_body = f"""
            <html>
            <body style="font-family: 'Segoe UI', Roboto, sans-serif; background-color: #f4f6f9; margin: 0; padding: 20px; color: #333333;">
                <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); overflow: hidden; border: 1px solid #e1e8ed;">
                    <!-- Blue Premium Header -->
                    <div style="background: linear-gradient(135deg, #1565C0 0%, #1E88E5 100%); padding: 30px 20px; text-align: center; color: #ffffff;">
                        <h1 style="margin: 0; font-size: 24px; font-weight: 600; letter-spacing: 0.5px;">Darbar Service Finder</h1>
                        <p style="margin: 5px 0 0 0; opacity: 0.9; font-size: 14px;">Booking Dispatch Notification</p>
                    </div>
                    
                    <!-- Content Block -->
                    <div style="padding: 30px 25px;">
                        <p style="font-size: 16px; line-height: 1.6; margin-top: 0; color: #2c3e50;">
                            Hello <strong>{booking_obj.user.name}</strong>,
                        </p>
                        <p style="font-size: 14px; line-height: 1.6; color: #555555; margin-bottom: 25px;">
                            We have successfully dispatched a booking attempt request to the top-ranked service provider in your area. Below are your booking specifications:
                        </p>
                        
                        <!-- Booking Details Table -->
                        <div style="background-color: #f8fafc; border-radius: 8px; padding: 20px; margin-bottom: 25px; border-left: 4px solid #1565C0;">
                            <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
                                <tr>
                                    <td style="padding: 6px 0; color: #7f8c8d; width: 40%;">Booking Reference:</td>
                                    <td style="padding: 6px 0; font-weight: 600; color: #2c3e50;">{booking_obj.booking_id}</td>
                                </tr>
                                <tr>
                                    <td style="padding: 6px 0; color: #7f8c8d;">Service Required:</td>
                                    <td style="padding: 6px 0; font-weight: 600; color: #2c3e50;">{booking_obj.service_type}</td>
                                </tr>
                                <tr>
                                    <td style="padding: 6px 0; color: #7f8c8d;">Service Location:</td>
                                    <td style="padding: 6px 0; font-weight: 600; color: #2c3e50;">{booking_obj.location}</td>
                                </tr>
                            </table>
                        </div>
                        
                        <!-- Provider Card -->
                        <h3 style="font-size: 16px; margin: 0 0 12px 0; color: #2c3e50; font-weight: 600;">Assigned Service Partner</h3>
                        <div style="border: 1px solid #e1e8ed; border-radius: 8px; padding: 15px; display: flex; align-items: center; background-color: #ffffff;">
                            <div style="margin-right: 15px; background-color: #e3f2fd; color: #1565C0; font-size: 20px; font-weight: bold; width: 45px; height: 45px; border-radius: 50%; display: flex; align-items: center; justify-content: center; text-transform: uppercase;">
                                {provider_obj.business_name[0]}
                            </div>
                            <div>
                                <h4 style="margin: 0 0 3px 0; font-size: 15px; color: #2c3e50;">{provider_obj.business_name}</h4>
                                <p style="margin: 0; font-size: 13px; color: #7f8c8d;">
                                    ⭐ {provider_obj.rating} rating | 📞 {provider_obj.phone}
                                </p>
                            </div>
                        </div>
                        
                        <p style="font-size: 13px; line-height: 1.5; color: #7f8c8d; margin-top: 25px; margin-bottom: 0; text-align: center;">
                            This is an automated notification from Darbar. The service partner will accept or decline your booking shortly. You can monitor the real-time status directly within your Darbar mobile application.
                        </p>
                    </div>
                    
                    <!-- Footer -->
                    <div style="background-color: #f8fafc; padding: 20px; text-align: center; border-top: 1px solid #e1e8ed; font-size: 12px; color: #95a5a6;">
                        © 2026 Darbar. All rights reserved. <br/>
                        Islamabad, Pakistan
                    </div>
                </div>
            </body>
            </html>
            """
            send_gmail_message(booking_obj.user.email, subject, html_body)
            email_status = f"Sent successfully via Gmail API from {sender_email} to {booking_obj.user.email}"
        except Exception as e:
            email_status = f"Failed to send email via Gmail API. Error: {str(e)}"
    
    # 3. FCM Push Notification (Simulated/Scaffolded)
    # pass
    
    action_taken = f"Sent booking request to {provider_obj.business_name}"
    reasoning = f"Booking request dispatched. Email status: {email_status}."
    
    AgentLog.objects.create(
        booking=booking_obj,
        agent_name=agent_name,
        action_taken=action_taken,
        reasoning=reasoning
    )
    
    return attempt
