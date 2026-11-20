# Video Conference

An experiment in building video conferencing **without WebRTC**, using:

- [WebCodecs](https://developer.mozilla.org/en-US/docs/Web/API/WebCodecs_API) — low-level access to individual video frames and audio chunks, giving full control over how media is processed.
- [WebTransport](https://developer.mozilla.org/en-US/docs/Web/API/WebTransport_API) — a modern alternative to WebSockets, transmitting data between client and server over HTTP/3.

This is a **monorepo** containing all the apps that make up the stack. Each app has its own `README.md` with setup and run instructions.

## Apps

| App | Path | Description | Docs |
|-----|------|-------------|------|
| Frontend | [`frontend/`](frontend/) | Video conferencing PWA — Vite + vanilla JS, WebCodecs encode/decode, Tailwind + DaisyUI | [frontend/README.md](frontend/README.md) |
| Backend | [`backend/`](backend/) | Phoenix 1.8 API + Channels — phone auth, phone book, shared links, call signalling, admin portals. SQLite via `ecto_sqlite3` | [backend/README.md](backend/README.md) |
| Stream server | [`stream_server/`](stream_server/) | Elixir HTTP/3 (WebTransport) media relay built on `wtransport` — authenticated rooms that fan out audio/video packets | [stream_server/README.md](stream_server/README.md) |
| Docker | [`docker/`](docker/) | Docker Compose stack that runs all three apps together behind nginx (local dev all-in-one setup) | [docker/README.md](docker/README.md) |

## How it works

```
Browser (frontend)
  │  HTTPS — SPA + REST API + Phoenix Channels (signalling)
  ▼
backend (Phoenix) ── signs stream-server JWTs (RSA private key)
  ▲
  │  WebTransport (HTTP/3) — audio/video media streams
  │  stream_server verifies the JWT (RSA public key)
  ▼
stream_server (media relay)
```

- **Signalling** (who is calling whom, shared-link management, auth) runs over Phoenix Channels and REST APIs on the backend.
- **Media** (video/audio) flows directly between the browser and the stream server over WebTransport, so it isn't blocked by the WebSocket channel.
- The backend signs JWTs (RS256) that the stream server verifies to authenticate participants and place them in rooms.

## Running

- **Everything at once (local dev):** use the Docker Compose stack — see [docker/README.md](docker/README.md).
- **Individual apps:** each app's README covers prerequisites, environment variables, and run/test commands:
  - [frontend/README.md](frontend/README.md) — `npm install`, `npm run dev`, Vitest
  - [backend/README.md](backend/README.md) — `dotenv -e .env iex -S mix phx.server`, `dotenv -e .env.test mix test`
  - [stream_server/README.md](stream_server/README.md) — `dotenv -e .env iex -S mix` (requires a Rust toolchain for the `wtransport` NIF)
