@echo off
echo Starting the Backend...
start "Backend" cmd /k "npm run dev"

echo Starting the Frontend...
cd frontend
start "Frontend" cmd /k "flutter run -d chrome --web-port=5500"

echo Both processes have been started in new windows.
