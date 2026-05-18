from apscheduler.schedulers.background import BackgroundScheduler
from datetime import timedelta
from api.models import Reminder, AgentLog

# Initialize scheduler
scheduler = BackgroundScheduler()
scheduler.start()

def schedule_reminders(booking_obj):
    """
    Schedules reminder 1hr before booking.
    Schedules rating request after job time passes.
    """
    agent_name = "Follow-Up Agent"
    
    if not booking_obj.scheduled_time:
        return
        
    # Example: 1 hour before
    remind_time = booking_obj.scheduled_time - timedelta(hours=1)
    
    Reminder.objects.create(
        booking=booking_obj,
        remind_at=remind_time,
        type="1hr_arrival"
    )
    
    # In a real setup, we would add the job to APScheduler here
    # scheduler.add_job(send_reminder_push, 'date', run_date=remind_time, args=[booking_obj.id])
    
    AgentLog.objects.create(
        booking=booking_obj,
        agent_name=agent_name,
        action_taken="Scheduled 1hr arrival reminder",
        reasoning="To ensure user and provider are synced before the job."
    )
    
def send_reminder_push(booking_id):
    # Logic to send FCM push
    pass
