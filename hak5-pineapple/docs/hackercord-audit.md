# HackerCord Architecture & Security Audit
> Scanned: 24 February 2026 | Target: hackercord.com | Auditor: NullSec

---

## System Architecture Flowchart

```mermaid
flowchart TB
    subgraph INTERNET["☁️ INTERNET"]
        USER["👤 User / Browser"]
        FLIP["📱 Desktop Client<br/>(Electron .exe/.AppImage)"]
        ANON["👻 Anonymous Guest"]
    end

    subgraph CF["🟧 CLOUDFLARE"]
        CDN["CDN / DDoS Protection"]
        TLS["TLS 1.3 Termination<br/>AES-256-GCM-SHA384<br/>Let's Encrypt E7"]
        NEL["NEL / Error Reporting"]
    end

    subgraph ORIGIN["🖥️ ORIGIN SERVER  (69.169.106.2)"]
        direction TB
        subgraph WEB["Web Server"]
            HTML["SSR Landing Page<br/>/ /streams /hackerbook /panel"]
            SPA["SPA Shell (/app)<br/>873-line HTML + ES Modules"]
            STATIC["Static Assets<br/>style.css (178KB)<br/>app.js (49KB)<br/>35 modules (1.4MB)"]
        end

        subgraph API["REST API  (/api/*)"]
            AUTH_EP["🔐 Auth Endpoints<br/>POST /register<br/>POST /login<br/>POST /anonymous"]
            DATA_EP["📊 Data Endpoints<br/>GET /me<br/>GET /servers ⚠️<br/>GET /public-servers<br/>GET /live-streams<br/>GET /projects<br/>GET /friends"]
            ACTION_EP["⚡ Action Endpoints<br/>POST /upload/attachment<br/>POST /bots/create<br/>POST /download-track<br/>GET /stream-key<br/>GET /download-count"]
            PROXY_EP["🌐 Web Proxy ⚠️<br/>GET /web-proxy?url="]
        end

        subgraph WS["WebSocket  (/ws)"]
            WS_AUTH["Login + Token Auth"]
            WS_ROUTE["Message Router<br/>(type-based dispatch)"]
            WS_PING["Keepalive Ping/Pong"]
        end

        subgraph JWT_SYS["🎫 Auth System"]
            JWT["JWT (EdDSA / Ed25519)<br/>30-day expiry<br/>Stored in localStorage ⚠️"]
        end

        subgraph DB["💾 Database"]
            USERS["Users Table<br/>(id, username, password_hash,<br/>display_name, avatar, role)"]
            SERVERS["Servers Table<br/>(channels, categories,<br/>permissions, settings)"]
            MSGS["Messages<br/>(ephemeral + persistent)"]
        end
    end

    subgraph CLIENT_MODULES["📦 Client JS Modules (35 total)"]
        direction TB
        subgraph CORE_MOD["Core"]
            CORE["core.js — WS connection"]
            STATE["state.js — shared state"]
            UI_MOD["ui.js (141KB) — UI framework"]
            MOBILE["mobile.js — responsive"]
        end
        subgraph COMM_MOD["Communication"]
            CHAT["chat.js — text messaging"]
            DM["dm.js — direct messages"]
            VOICE["voice.js (147KB) — WebRTC"]
            CRYPTO["voiceCrypto.js — E2EE<br/>ECDH P-256 → AES-GCM"]
            CHANNELS["channels.js (94KB)"]
            INBOX["inbox.js — notifications"]
        end
        subgraph SOCIAL_MOD["Social"]
            AVATAR["avatar.js (51KB)"]
            SOCIAL["social_club.js"]
            LEADER["leaderboard.js"]
        end
        subgraph GAME_MOD["Games (12 modules)"]
            GAMES["chess | battleship | fighter<br/>pong | tetris | tictactoe<br/>connect4 | checkers | gomoku<br/>mancala | dotsboxes | shooter<br/>space_invaders | pictionary<br/>drawmything"]
        end
        subgraph ADVANCED_MOD["Advanced"]
            VM["vm.js — x86 VM (PCjs)"]
            EMU["emulator.js (162KB)<br/>NES/SNES/GB/GBA/Genesis"]
            BROWSER["sharedbrowser.js<br/>Collaborative browsing"]
            PLUGINS["plugins.js ⚠️<br/>Client-side plugin system"]
        end
    end

    USER --> CDN
    FLIP --> CDN
    ANON --> CDN
    CDN --> TLS
    TLS --> NEL
    NEL --> HTML
    NEL --> SPA
    NEL --> API
    NEL --> WS

    SPA --> STATIC
    STATIC --> CLIENT_MODULES

    AUTH_EP --> JWT_SYS
    JWT_SYS --> DB
    DATA_EP --> DB
    ACTION_EP --> DB
    WS_AUTH --> JWT_SYS
    WS_ROUTE --> WS_PING

    VOICE -.->|"P2P WebRTC<br/>STUN: stun.l.google.com"| USER
    CRYPTO -.->|"ECDH key exchange<br/>via signaling server"| WS_ROUTE
    PROXY_EP -.->|"Server-side fetch<br/>⚠️ SSRF risk"| INTERNET
```

---

## Request Flow

```mermaid
sequenceDiagram
    participant U as 👤 User
    participant CF as 🟧 Cloudflare
    participant S as 🖥️ Server
    participant DB as 💾 Database
    participant P as 👥 Peer (Voice)

    Note over U,S: Registration / Login
    U->>CF: POST /api/register {username, password}
    CF->>S: Forward (no rate limit ⚠️)
    S->>DB: INSERT user (password salted+hashed)
    DB-->>S: user object + sequential ID ⚠️
    S-->>CF: {ok, user, token (EdDSA JWT 30d)}
    CF-->>U: Response
    U->>U: localStorage.setItem('hackercord_token') ⚠️

    Note over U,S: WebSocket Connection
    U->>CF: WSS /ws
    CF->>S: Upgrade
    S-->>U: Connected
    U->>S: {type:'login', username, token}
    S->>S: Verify EdDSA JWT
    S-->>U: {type:'login_success'}

    Note over U,P: Voice Call (E2EE)
    U->>S: {type:'voice_join'}
    S-->>U: {type:'voice_joined', peers:[]}
    U->>U: Generate ECDH P-256 keypair
    U->>S: {type:'voice_signal', pubkey}
    S->>P: Relay pubkey
    P->>P: ECDH derive AES-GCM key (128-bit ⚠️)
    P-->>S: Signal answer + pubkey
    S-->>U: Relay
    U->>P: WebRTC P2P (encrypted audio frames)
```

---

## Security Findings Flowchart

```mermaid
flowchart LR
    subgraph CRITICAL["🔴 CRITICAL"]
        C1["No Security Headers<br/>─────────────<br/>No HSTS / CSP / X-Frame<br/>No X-Content-Type<br/>No Referrer-Policy<br/>No Permissions-Policy"]
        C2["No Rate Limiting<br/>─────────────<br/>Registration: 10/10 = 200 ✓<br/>Login: 20/20 = 401 ✓<br/>No lockout / CAPTCHA"]
        C3["JWT in localStorage<br/>─────────────<br/>30-day EdDSA token<br/>XSS → full takeover<br/>No HttpOnly cookie"]
        C4["/api/servers Leaks All<br/>─────────────<br/>Unauthenticated access<br/>Hidden channels exposed<br/>Channel settings visible"]
        C5["Open SSRF Proxy<br/>─────────────<br/>/api/web-proxy?url=<br/>Exposes real IP<br/>69.169.106.2<br/>Bypasses Cloudflare"]
        C6["Unsafe Plugin System<br/>─────────────<br/>Runs in main JS context<br/>Full DOM access<br/>Can steal tokens<br/>fetch() with credentials"]
    end

    subgraph HIGH["🟡 HIGH"]
        H1["Weak Password Policy<br/>4 chars minimum<br/>No complexity rules"]
        H2["E2EE Mismatch<br/>Claims AES-256-GCM<br/>Actually AES-128-GCM"]
        H3["No TURN Server<br/>Only Google STUN<br/>~15% users can't call"]
        H4["innerHTML + User Data<br/>8+ locations in chat.js<br/>Relies on esc() everywhere"]
        H5["No JWT Revocation<br/>30 days, no rotation<br/>No server-side blacklist"]
    end

    subgraph MEDIUM["🟢 MEDIUM"]
        M1["Server Header Leak<br/>'server: cloudflare'"]
        M2["User Enum via Reg<br/>Different response for<br/>existing usernames"]
        M3["ID Leaks User Count<br/>Sequential integer IDs<br/>in registration response"]
        M4["Ancient Polyfills<br/>html5shiv + respond.js<br/>(2013, unmaintained)"]
        M5["No sitemap.xml<br/>Returns 404"]
    end

    C1 -->|fix| F1["Add headers via<br/>Cloudflare Transform Rules<br/>or server middleware"]
    C2 -->|fix| F2["Redis-based rate limiter<br/>5/min register<br/>10/min login per IP"]
    C3 -->|fix| F3["HttpOnly Secure SameSite<br/>cookie + CSRF token"]
    C4 -->|fix| F4["Require auth<br/>Filter by membership"]
    C5 -->|fix| F5["URL allowlist<br/>Block RFC1918/metadata<br/>Separate proxy origin"]
    C6 -->|fix| F6["iframe sandbox<br/>or Web Worker<br/>+ postMessage API"]
```

---

## Technology Stack

```mermaid
mindmap
  root((HackerCord))
    Infrastructure
      Cloudflare CDN
      TLS 1.3 / Let's Encrypt
      Origin: 69.169.106.2
      NEL Error Reporting
    Backend
      Custom Server
      REST API (11 endpoints)
      WebSocket /ws
      JWT EdDSA Auth
      Server-side Web Proxy
    Frontend
      Vanilla JS (ES Modules)
      No Framework
      35 Modules / 1.4MB
      PWA (manifest.json)
      Single CSS (178KB)
    Communication
      WebSocket JSON Protocol
      WebRTC P2P Voice
      ECDH P-256 Key Exchange
      AES-GCM Encryption
      Google STUN Servers
    Features
      Text Chat (persistent + ephemeral)
      E2EE Voice Calls
      Direct Messages
      Live Streaming
      HackerBook Social Feed
      Project Showcase
      12 Built-in Games
      x86 VM Sharing
      Retro Emulator
      Shared Browser
      Plugin System
      Bot SDK
      Avatar Customizer
      Collaborative Whiteboard
    Security ✅
      EdDSA JWT Signing
      ECDH + AES-GCM Voice E2EE
      XSS esc() Sanitization
      SSRF Partial Blocking
      Generic Login Errors
      Salted Password Hashing
    Security ⚠️
      No HTTP Security Headers
      No Rate Limiting
      JWT in localStorage
      Open Web Proxy SSRF
      Unsafe Plugin Sandbox
      Weak Password Policy
      AES-128 not AES-256
      No TURN Server
```

---

## Priority Fix Matrix

```
┌──────────┬─────────────────────────────────────────────────┬──────────┐
│ Priority │ Fix                                             │ Effort   │
├──────────┼─────────────────────────────────────────────────┼──────────┤
│ 🔴 P0    │ Add HSTS + CSP + X-Frame + X-Content-Type +    │ 1 hour   │
│          │ Referrer-Policy + Permissions-Policy headers    │          │
├──────────┼─────────────────────────────────────────────────┼──────────┤
│ 🔴 P0    │ Rate-limit /api/register and /api/login         │ 2 hours  │
│          │ (5/min per IP)                                  │          │
├──────────┼─────────────────────────────────────────────────┼──────────┤
│ 🔴 P0    │ Move JWT to HttpOnly Secure SameSite cookie     │ 4 hours  │
│          │ + add CSRF token                                │          │
├──────────┼─────────────────────────────────────────────────┼──────────┤
│ 🔴 P0    │ Fix /api/servers: require auth, filter by       │ 1 hour   │
│          │ membership, hide hidden channels                │          │
├──────────┼─────────────────────────────────────────────────┼──────────┤
│ 🔴 P0    │ Harden web-proxy: domain allowlist, block       │ 4 hours  │
│          │ RFC1918/link-local/metadata, separate origin    │          │
├──────────┼─────────────────────────────────────────────────┼──────────┤
│ 🟡 P1    │ Sandbox plugins in iframe/Worker + postMessage  │ 1-2 days  │
├──────────┼─────────────────────────────────────────────────┼──────────┤
│ 🟡 P1    │ Enforce 8+ char passwords with complexity       │ 30 min    │
├──────────┼─────────────────────────────────────────────────┼──────────┤
│ 🟡 P1    │ Fix E2EE: AES-256-GCM (pass {length:256})      │ 30 min     │
│          │ or update marketing to say 128-bit              │          │
├──────────┼─────────────────────────────────────────────────┼──────────┤
│ 🟡 P1    │ Add TURN server for voice reliability           │ 2 hours   │
├──────────┼─────────────────────────────────────────────────┼──────────┤
│ 🟡 P1    │ JWT refresh rotation + server-side revocation   │ 1 day    ─┤
│ 🟢 P2    │ Remove html5shiv/respond.js polyfills           │ 5 min     │
├──────────┼─────────────────────────────────────────────────┼──────────┤
│ 🟢 P2    │ Audit all innerHTML for missing esc() calls     │ 2 hours   │
├──────────┼─────────────────────────────────────────────────┼──────────┤
│ 🟢 P2    │ Add sitemap.xml                                 │ 15 min    │
└──────────┴─────────────────────────────────────────────────┴──────────┘
```

---

## Key Stats

| Metric | Value |
|--------|-------|
| Total JS Modules | 35 |
| Total Client JS | 1,412,686 bytes (1.4MB) |
| API Endpoints | 11 discovered |
| Registered Users | ~51 (sequential IDs) |
| Downloads | 27 |
| Public Servers | 1 (HackerCord official) |
| Built-in Games | 12+ |
| JWT Algorithm | EdDSA (Ed25519) |
| JWT Expiry | 30 days |
| Voice Encryption | ECDH P-256 → AES-GCM 128-bit |
| TLS Version | 1.3 |
| Certificate | Let's Encrypt E7 |
| Origin IP | 69.169.106.2 (exposed via web-proxy) |
| Password Minimum | 4 characters |
| Critical Findings | 6 |
| High Findings | 5 |
| Medium Findings | 5 |
