# VPN Provider POC

This Proof of Concept (POC) implements a WireGuard-based VPN provider architecture using Go.

## Components

### 1. Control Plane (Backend)
Located in `cmd/server/`.
- **Feature:** User registration and login (JWT).
- **Feature:** Node registration and heartbeat tracking.
- **Feature:** Dynamic peer provisioning (Automatic IP allocation).
- **Feature:** WireGuard configuration generation.

**Run:**
```bash
go run cmd/server/*.go
```

### 2. Data Plane (Node Agent)
Located in `cmd/agent/`.
- **Feature:** Automatic registration with the backend.
- **Feature:** Periodic heartbeat to signal availability.
- **Feature:** Peer synchronization: Periodically fetches the peer list and updates the local `wg0` interface.

**Run:**
```bash
# Note: Requires 'wg0' interface to exist on the machine
sudo go run cmd/agent/*.go
```

## Testing Workflow

1. **Start Server**: Run the backend. It will initialize an SQLite database (configured in code for ease of POC).
2. **Start Agent**: Run the agent on a Linux machine with WireGuard installed.
3. **Register User**:
   ```bash
   curl -X POST http://localhost:8080/auth/register -d '{"email":"test@example.com", "password":"password123"}'
   ```
4. **Login**:
   ```bash
   curl -X POST http://localhost:8080/auth/login -d '{"email":"test@example.com", "password":"password123"}'
   # Copy the token
   ```
5. **Connect (Provision)**:
   ```bash
   curl -X POST http://localhost:8080/user/connect \
     -H "Authorization: Bearer <TOKEN>" \
     -d '{"public_key":"<YOUR_DEVICE_PUBLIC_KEY>"}'
   ```
6. **Download Config**:
   ```bash
   curl -H "Authorization: Bearer <TOKEN>" http://localhost:8080/user/config/1 > vpn.conf
   ```
