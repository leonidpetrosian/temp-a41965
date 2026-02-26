# VPN Provider MVP Architecture & Design

## 1. VPN Protocol Selection
**Recommendation:** **WireGuard**
*Why WireGuard?* It is the modern standard for VPNs. It has a tiny codebase (~4,000 lines compared to OpenVPN's ~600,000), making it incredibly fast, easy to audit for security, and less battery-intensive. It uses state-of-the-art cryptography (Curve25519, ChaCha20, Poly1305) and operates statelessly like UDP, which makes it seamless when roaming between Wi-Fi and Cellular networks.

## 2. High-Level Architecture (Client-Server)
A modern VPN provider is split into three main components:

1. **Control Plane (Backend API & Web Panel)**
   - Manages Users, Subscriptions, Servers (Nodes), and internal IP Allocation.
   - Provides an API for the Client App to authenticate and request VPN server credentials.
2. **Data Plane (VPN Entry/Exit Nodes)**
   - The actual geographic servers routing user traffic.
   - Runs a lightweight "Node Agent" that communicates with the Control Plane.
   - Applies NAT (Network Address Translation) and firewall routing using `iptables` or `nftables`.
3. **Client Application**
   - The user-facing software (Windows, macOS, iOS, Android).
   - Authenticates with the Control Plane, generates cryptographic keys, and sets up the local network interface.

## 3. AAA (Authentication, Authorization, Accounting)
- **Authentication:** 
  - *Web/App:* Standard email/password (JWT), OAuth, or Magic Links.
  - *VPN Tunnel:* WireGuard relies entirely on Cryptographic Key Routing (exchanging Public Keys). No traditional username/password is passed during the VPN connection handshake.
- **Authorization:**
  - The Control Plane checks if a user has an active subscription/trial before pushing their Public Key to the requested VPN Node.
  - If a user's subscription expires, the Control Plane instructs the Node Agent to remove the user's Public Key, instantly terminating access.
- **Accounting:**
  - To track data usage (for limits or abuse metrics) and concurrent connections, the Node Agent periodically reads WireGuard interface statistics (e.g., `wg show all transfer`) and pushes the data to the Control Plane.

## 4. Dynamic Configuration Provisioning
Instead of static files, modern VPNs dynamically provision connections:
1. Client logs into the app and selects a geographical region (e.g., "US East").
2. Client generates a Private/Public keypair locally (Private key *never* leaves the device).
3. Client sends its Public Key to the Backend API requesting a connection.
4. Backend finds an available Node in "US East" and allocates an internal private IP (e.g., `10.8.0.57`) uniquely for this session.
5. Backend securely pushes a message to that Node's Agent: *"Add peer with this Public Key and this internal IP"*.
6. Backend returns the Node's external IP, Node's Public Key, and the assigned internal IP to the Client.
7. Client configures its local network routing and connects instantly.

## 5. Encryption & Security
- **Tunnel Encryption:** Secure by default with WireGuard (no weak cipher downgrade attacks possible).
- **DNS Privacy (No Leaks):** The VPN node should run a local, caching DNS resolver (like CoreDNS or Unbound) bound to the internal IP range (`10.8.0.1`), ensuring all user DNS queries are routed inside the encrypted tunnel and not tracked by their local ISP.
- **Microservice Security:** Mutual TLS (mTLS) or secure Message Queues (like RabbitMQ/Redis PubSub) should be used between the Control Plane and Node Agents to prevent malicious provisioning.

## 7. Technical Stack
- **Languages:** Go (Golang) for high-performance networking and concurrency.
- **VPN Protocol:** WireGuard.
- **Libraries:**
  - `golang.zx2c4.com/wireguard/wgctrl` (Control WireGuard interfaces).
  - `netlink` (Linux networking configuration).
  - `gin` or `echo` (Backend API framework).
  - `gorm` or `sqlx` (Database interaction).

## 8. Project Structure
```text
vpn/
├── cmd/
│   ├── server/      # Backend API (Control Plane)
│   └── agent/       # Node Agent (Data Plane)
├── internal/
│   ├── auth/        # JWT & User Auth
│   ├── db/          # Database migrations & queries
│   ├── models/      # Shared data structures
│   └── wg/          # WireGuard configuration helpers
├── pkg/
│   └── config/      # Shared configuration loading
└── go.mod
```
