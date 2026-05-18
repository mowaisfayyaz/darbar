import os
import django
import random
import uuid

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from api.models import User, Provider, Booking

def run():
    print("Clearing old data...")
    User.objects.all().delete()
    Provider.objects.all().delete()
    Booking.objects.all().delete()

    print("Creating mock users...")
    u1 = User.objects.create(name="Ali Khan", phone="03001234567", location="G-13, Islamabad")
    u2 = User.objects.create(name="Sara Ahmed", phone="03331234567", location="F-14, Islamabad")

    print("Creating mock providers...")
    categories = ['AC Technician', 'Plumber', 'Electrician', 'Tutor', 'Beautician']
    areas = ['G-13', 'F-14', 'I-14', 'E-11']
    
    first_names = ["Muhammad", "Tariq", "Zeeshan", "Waqas", "Usman", "Faisal"]
    
    for i in range(20):
        category = random.choice(categories)
        area = random.choice(areas)
        name = f"{random.choice(first_names)} {category.split()[0]} Services"
        
        Provider.objects.create(
            business_name=name,
            phone=f"03{random.randint(10,99)}{random.randint(1000000,9999999)}",
            rating=round(random.uniform(3.5, 5.0), 1),
            review_count=random.randint(5, 200),
            category=category,
            price_indicator="$" * random.randint(1, 3),
            city="Islamabad",
            area=area,
            is_available=True
        )
    
    print(f"Successfully inserted {User.objects.count()} users and {Provider.objects.count()} providers.")

if __name__ == '__main__':
    run()
