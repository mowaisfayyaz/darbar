# 🚀 Easy Setup Guide

Welcome! Since the original `setup.md` guide is quite long and complex, here is the absolutely simplest way to run your project on this server.

You have two easy options to start both the Frontend and the Backend.

---

## Option 1: The One-Command Automated Way (Easiest!)
This method uses a pre-written script that automatically starts everything for you.

1. Open your terminal in the main project folder (`/home/mannan/darbar`).
2. Run this single command:
   ```bash
   python3 run_darbar.py
   ```
3. **That's it!** Wait about 10 seconds, and a colorful dashboard will appear in your terminal. It will automatically give you secure, shareable public links that you can open in any browser (even on your phone!).

---

## Option 2: The Direct Public IP Way
If you prefer to start them yourself and access them directly via your server's public IP address (`185.2.100.202`), just run these simple commands:

### Step 1: Clean up old servers
Stop any old or crashed servers that might be stuck:
```bash
fuser -k 8000/tcp 8081/tcp
```

### Step 2: Start the Backend Server
Start the Django backend in the background:
```bash
cd /home/mannan/darbar/backend
nohup .venv/bin/python manage.py runserver 0.0.0.0:8000 &
```
*(Your backend is now live at: `http://185.2.100.202:8000`)*

### Step 3: Start the Frontend App
Compile the web app and serve it statically:
```bash
cd /home/mannan/darbar/flutter_app
flutter build web
cd build/web
nohup python3 -m http.server 8081 --bind 0.0.0.0 &
```
*(Your frontend is now live at: `http://185.2.100.202:8081`)*

---
🎉 **You're done!** Open your browser and navigate to `http://185.2.100.202:8081` to test your application.
