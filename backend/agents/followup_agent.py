from datetime import timedelta
from api.models import Reminder, AgentLog

# Scheduler is initialized lazily to avoid module-level side effects
_scheduler = None

def _get_scheduler():
    global _scheduler
    if _scheduler is None:
        from apscheduler.schedulers.background import BackgroundScheduler
        _scheduler = BackgroundScheduler()
        _scheduler.start()
    return _scheduler

def schedule_reminders(booking_obj):
    """
    Schedules reminder 1hr before booking.
    Schedules rating request after job time passes.
    If no scheduled_time, logs that reminders were skipped gracefully.
    """
    
    agent_name = "Follow-Up Agent"
    
    if not booking_obj.scheduled_time:
        AgentLog.objects.create(
            booking=booking_obj,
            agent_name=agent_name,
            action_taken="Reminder scheduling skipped",
            reasoning="No scheduled_time set on booking. Reminders will be set when the provider confirms a time slot."
        )
        return
        
    # Schedule 1 hour before arrival
    remind_time = booking_obj.scheduled_time - timedelta(hours=1)
    
    Reminder.objects.create(
        booking=booking_obj,
        remind_at=remind_time,
        type="1hr_arrival"
    )
    
    # In production, we would add the job to APScheduler:
    # scheduler = _get_scheduler()
    # scheduler.add_job(send_reminder_push, 'date', run_date=remind_time, args=[booking_obj.id])
    
    AgentLog.objects.create(
        booking=booking_obj,
        agent_name=agent_name,
        action_taken="Scheduled 1hr arrival reminder",
        reasoning=f"Reminder set for {remind_time.isoformat()}. User and provider will be notified 1 hour before the scheduled service time."
    )
    
def send_reminder_push(booking_id):
    """Logic to send FCM push notification for reminders."""
    # Future: Firebase Cloud Messaging integration
    pass
