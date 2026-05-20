import os
# pyrefly: ignore [missing-import]
import django
import json
import random
import glob

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from api.models import User, Provider, Booking, BookingAttempt, AgentLog, Notification

def clean_phone(phone_raw):
    if not phone_raw:
        return f"03{random.randint(10,99)}{random.randint(1000000,9999999)}"
    phone = str(phone_raw).strip()
    # Normalize Pakistani numbers
    if phone.startswith('+92'):
        phone = '0' + phone[3:]
    phone = phone.replace(' ', '').replace('-', '')
    if len(phone) < 10:
        return f"03{random.randint(10,99)}{random.randint(1000000,9999999)}"
    return phone

def run():
    print("Clearing old database records (Bookings, Attempts, Logs, Notifications, Providers)...")
    AgentLog.objects.all().delete()
    BookingAttempt.objects.all().delete()
    Booking.objects.all().delete()
    Notification.objects.all().delete()
    Provider.objects.all().delete()
    
    # We keep users, but make sure a default test user exists
    if not User.objects.filter(phone="03001234567").exists():
        User.objects.create(
            name="Ali Khan", 
            email="ali@example.com",
            phone="03001234567", 
            location="G-13, Islamabad"
        )
        print("Created default test customer: Ali Khan (03001234567)")

    data_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data')
    json_files = glob.glob(os.path.join(data_dir, '*.json'))
    
    if not json_files:
        print("No JSON dataset files found in backend/data/!")
        return

    print(f"Found {len(json_files)} dataset file(s). Processing...")

    islamabad_areas = ['G-13', 'E-11', 'F-6', 'I-8', 'G-11', 'F-10', 'H-13']
    created_count = 0

    for file_path in json_files:
        print(f"Reading {os.path.basename(file_path)}...")
        with open(file_path, 'r', encoding='utf-8') as f:
            try:
                items = json.load(f)
            except Exception as e:
                print(f"❌ Failed to parse JSON in {file_path}: {e}")
                continue

            for idx, item in enumerate(items):
                title = item.get('title')
                if not title:
                    continue

                category_name = item.get('categoryName', '').lower()
                
                # Standardize category name
                if 'plumb' in category_name:
                    category = 'Plumber'
                elif any(x in category_name for x in ['hvac', 'air cond', 'cooling', 'fridge']):
                    category = 'AC Technician'
                elif 'carpent' in category_name:
                    category = 'Carpenter'
                elif 'electr' in category_name:
                    category = 'Electrician'
                else:
                    # Default matching
                    category = 'General Services'

                # Clean phone number
                phone_raw = item.get('phoneUnformatted') or item.get('phone')
                phone = clean_phone(phone_raw)

                # Ensure phone is unique to avoid integrity errors
                if Provider.objects.filter(phone=phone).exists():
                    phone = f"03{random.randint(10,99)}{random.randint(1000000,9999999)}"

                rating = item.get('totalScore') or round(random.uniform(4.0, 5.0), 1)
                reviews = item.get('reviewsCount') or random.randint(5, 50)
                
                # We distribute providers between Karachi and Islamabad to verify matching in both cities
                if idx % 2 == 0:
                    city = "Islamabad"
                    area = random.choice(islamabad_areas)
                    # Coordinates around Islamabad
                    lat = round(random.uniform(33.64, 33.72), 6)
                    lng = round(random.uniform(72.96, 73.08), 6)
                else:
                    city = "Karachi"
                    area = item.get('neighborhood') or "Clifton"
                    # Coordinates around Karachi
                    lat = round(random.uniform(24.82, 24.94), 6)
                    lng = round(random.uniform(66.98, 67.12), 6)

                Provider.objects.create(
                    business_name=title,
                    phone=phone,
                    rating=float(rating),
                    review_count=int(reviews),
                    category=category,
                    price_indicator=random.choice(['$', '$$', '$$$']),
                    city=city,
                    area=area,
                    lat=lat,
                    lng=lng,
                    is_available=True
                )
                created_count += 1

    print(f"Successfully imported {created_count} service providers to Database!")
    print(f"Database contains {Provider.objects.count()} active providers.")

if __name__ == '__main__':
    run()
