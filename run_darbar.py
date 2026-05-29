#!/usr/bin/env python3
import subprocess
import time
import re
import sys
import os
import signal
import threading

# Harmonious colors for terminal output
def print_success(msg):
    print(f"\033[92m[✓] {msg}\033[0m")

def print_info(msg):
    print(f"\033[94m[*] {msg}\033[0m")

def print_warning(msg):
    print(f"\033[93m[!] {msg}\033[0m")

def print_error(msg):
    print(f"\033[91m[✗] {msg}\033[0m")

processes = []
backend_url = None
client_url = None

def cleanup(sig=None, frame=None):
    print_warning("\nShutting down all processes gracefully...")
    for p in processes:
        try:
            p.terminate()
            p.wait(timeout=2)
        except Exception:
            try:
                p.kill()
            except Exception:
                pass
    print_success("All servers and tunnels stopped. Goodbye!")
    sys.exit(0)

# Register signals for clean exit
signal.signal(signal.SIGINT, cleanup)
signal.signal(signal.SIGTERM, cleanup)

def read_backend_output(proc):
    global backend_url
    for line in iter(proc.stdout.readline, ''):
        if not line:
            break
        match = re.search(r'https://[a-zA-Z0-9-]+\.lhr\.life', line)
        if match:
            backend_url = match.group(0)
            break

def read_client_output(proc):
    global client_url
    for line in iter(proc.stdout.readline, ''):
        if not line:
            break
        match = re.search(r'https://[a-zA-Z0-9-]+\.lhr\.life', line)
        if match:
            client_url = match.group(0)
            break

def main():
    os.system('clear')
    print("\033[1;95m")
    print(" 🏛️  D A R B A R   O R C H E S T R A T O R")
    print("=========================================\033[0m")
    print_info("Starting Darbar services & worldwide access tunnels...")

    # 1. Start Django Backend
    print_info("Launching Django Backend on port 8000...")
    backend_cwd = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'backend')
    backend_proc = subprocess.Popen(
        ['.venv/bin/python', 'manage.py', 'runserver', '0.0.0.0:8000'],
        cwd=backend_cwd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    processes.append(backend_proc)
    time.sleep(2) # Give it a moment to boot
    
    if backend_proc.poll() is not None:
        print_error("Failed to start Django Backend! Please check if port 8000 is occupied.")
        cleanup()

    # 2. Build & Serve Flutter Web Client
    flutter_cwd = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'flutter_app')
    web_build_dir = os.path.join(flutter_cwd, 'build', 'web')

    # Check if a web build already exists, if not build it
    if not os.path.isfile(os.path.join(web_build_dir, 'flutter_bootstrap.js')):
        print_info("Building Flutter Web Client (first time may take ~60s)...")
        build_result = subprocess.run(
            ['flutter', 'build', 'web'],
            cwd=flutter_cwd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True
        )
        if build_result.returncode != 0:
            print_error(f"Flutter web build failed! {build_result.stderr}")
            cleanup()
        print_success("Flutter web build complete.")
    else:
        print_success("Using existing Flutter web build.")

    print_info("Serving Flutter Web Client on port 8081...")
    flutter_proc = subprocess.Popen(
        ['python3', '-m', 'http.server', '8081', '--bind', '0.0.0.0'],
        cwd=web_build_dir,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    processes.append(flutter_proc)
    time.sleep(1) # Give it a moment to boot

    if flutter_proc.poll() is not None:
        print_error("Failed to start Flutter Web Client! Please check if port 8081 is occupied.")
        cleanup()

    # 3. Open Backend Tunnel
    print_info("Opening worldwide access tunnel for Django Backend...")
    backend_tunnel_proc = subprocess.Popen(
        ['ssh', '-o', 'StrictHostKeyChecking=no', '-R', '80:localhost:8000', 'nokey@localhost.run'],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )
    processes.append(backend_tunnel_proc)

    # 4. Open Client Tunnel
    print_info("Opening worldwide access tunnel for Flutter Web Client...")
    client_tunnel_proc = subprocess.Popen(
        ['ssh', '-o', 'StrictHostKeyChecking=no', '-R', '80:localhost:8081', 'nokey@localhost.run'],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )
    processes.append(client_tunnel_proc)

    print_info("Resolving public HTTPS tunnel URLs (this might take up to 10 seconds)...")
    
    # Start threads to parse outputs
    t1 = threading.Thread(target=read_backend_output, args=(backend_tunnel_proc,))
    t2 = threading.Thread(target=read_client_output, args=(client_tunnel_proc,))
    t1.daemon = True
    t2.daemon = True
    t1.start()
    t2.start()

    # Wait for resolution
    start_time = time.time()
    while time.time() - start_time < 15:
        if backend_url and client_url:
            break
        time.sleep(0.5)

    if not backend_url or not client_url:
        print_error("Failed to resolve public URLs from localhost.run!")
        print_info("Let's attempt a fallback or review processes...")
        cleanup()

    # Beautiful Dashboard
    print("\n\033[1;92m=================================================================")
    print(" 🎉  D A R B A R   S E R V E R S   A R E   L I V E !")
    print("=================================================================\033[0m")
    print(f" 🔌  \033[1mLocal Backend:\033[0m          http://localhost:8000")
    print(f" 📱  \033[1mLocal Web Client:\033[0m      http://localhost:8081")
    print("-----------------------------------------------------------------")
    print(f" 🌐  \033[1;94mPublic Backend URL:\033[0m     {backend_url}")
    print(f" 🌐  \033[1;94mPublic Client URL:\033[0m      {client_url}")
    print("-----------------------------------------------------------------")
    print(" 🚀  \033[1;93mULTIMATELY SHARE THIS LINK WITH ANYONE WORLDWIDE:\033[0m")
    print(f"     👉  \033[4;92m{client_url}/?api={backend_url}\033[0m")
    print("=================================================================")
    print_info("Press Ctrl+C to terminate both servers and close the tunnels.\n")

    # Keep alive
    while True:
        time.sleep(1)

if __name__ == '__main__':
    main()
