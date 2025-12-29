# NullSec Network Manager (WarGames Edition)

Local web app to view network devices, connections, and processes.

Run locally:
- python3 app.py
- Open http://127.0.0.1:5000

API endpoints:
- GET /api/devices
- GET /api/connections
- GET /api/processes

Deploy to GitHub:
1) Create a new GitHub repo (empty). Copy its HTTPS URL.
2) In this directory:
   - git remote add origin <YOUR_REPO_URL>
   - git branch -M main
   - git push -u origin main
