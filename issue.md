# Troubleshooting Guide: Blank Screen / 404 on Port 8081

This document explains the "blank screen" issue on the frontend server (port 8081), why it occurs, and how to diagnose and resolve it.

---

## 1. Symptoms
- The web app page loads as a blank screen.
- Chrome Developer Tools (Network Tab) shows requests returning `HTTP 404 Not Found`.
- Log files or curls return headers containing `x-powered-by: Dart with package:shelf`.

---

## 2. Root Cause
The Flutter frontend was started using the development/debug command:
```bash
flutter run -d web-server --web-port 8081 --web-hostname 0.0.0.0
```
While this command works locally, running it on a remote server causes issues:
1. It starts a debug compiler (Dart Dev Compiler) and the Dart Web Debug Service (DWDS).
2. It expects active WebSocket debugger connections from the browser.
3. When accessed over a remote/public IP, these WebSocket connections fail or timeout, preventing the compiler from serving the required script files (hence the `404 Not Found` response).

---

## 3. Diagnostic Commands

To verify if the debug server is running instead of the production server, run the following secure commands:

### A. Check Port Owner
```bash
ss -tulpn | grep 8081
```
*If the output shows a `dart` process, it is running the debug server.*

### B. Check HTTP Response Headers
```bash
curl -I http://127.0.0.1:8081/
```
*If the response contains `x-powered-by: Dart with package:shelf` and `404 Not Found`, it is running the debug server.*

---

## 4. Resolution Steps

Follow these steps to restore the working production frontend:

### Step 1: Terminate the Stale Server
Kill the process currently holding port 8081:
```bash
fuser -k 8081/tcp
```

### Step 2: (Optional) Rebuild the Frontend
If you have made code changes that need to be deployed:
```bash
cd /home/mannan/darbar/flutter_app
flutter build web
```

### Step 3: Serve the Production Build
Serve the compiled files statically using Python's HTTP server in the background:
```bash
cd /home/mannan/darbar/flutter_app/build/web
python3 -m http.server 8081 --bind 0.0.0.0 > /home/mannan/darbar/scratch/flutter_run.log 2>&1 &
```

### Step 4: Verification
Confirm it is serving files successfully:
```bash
curl -I http://127.0.0.1:8081/
```
*Expected Output:* `HTTP/1.0 200 OK` (Served by `SimpleHTTP` / Python).
