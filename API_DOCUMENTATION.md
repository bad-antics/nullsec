# NULLSEC WEB API Documentation

## Base URL
http://localhost:5000/api

## Authentication
Currently no authentication required (add for production use)

## Endpoints

### Targets
- GET /targets - List all targets
- POST /targets - Add new target
- GET /targets/<ip> - Get target details
- PUT /targets/<ip> - Update target
- DELETE /targets/<ip> - Delete target
- POST /targets/<ip>/scan - Initiate scan

### Attacks
- GET /attacks - List attacks
- POST /attacks - Launch attack
- GET /attacks/<id> - Get attack details
- POST /attacks/<id>/stop - Stop attack

### Sessions
- GET /sessions - List active sessions
- POST /sessions - Create session
- GET /sessions/<id> - Get session details
- DELETE /sessions/<id> - Close session

### Vulnerabilities
- GET /vulnerabilities - List vulnerabilities
- POST /vulnerabilities - Add vulnerability

### Workspaces
- GET /workspaces - List workspaces
- POST /workspaces - Create workspace

### Reports
- GET /reports - List reports
- POST /reports - Generate report
- GET /reports/<id> - Get report details

### System
- GET /stats - Get system statistics
- POST /ai/query - Query NULLSEC AI
- GET /modules - List attack modules

## WebSocket Events
- connect - Client connection
- notification - Real-time updates
- join_workspace - Join workspace room
- subscribe_target - Subscribe to target
- subscribe_attack - Subscribe to attack

See ENHANCEMENTS_v2.md for full documentation.
