# Video Conference — Docker Compose

Runs the three-app video conference stack in Docker:

| Service          | Image                          | What it is                                                        |
|------------------|--------------------------------|-------------------------------------------------------------------|
| `frontend`       | `videoconference/frontend`     | nginx serving the built `video_conference_vite` (Vite + native JS) SPA |
| `video_conference` | `videoconference/video_conference` | Elixir/Phoenix backend — API + websocket, signs JWTs          |
| `http3_server`   | `videoconference/http3_server` | Elixir/wtransport — WebTransport (HTTP/3) media server            |

The three app repos (`video_conference_vite`, `video_conference`, `http3_server`).

**!** This docker compose is developed to run the app on a local dev env.

## How it works

```
Browser
  │  https://localhost:8443   (SPA + API + websocket, one origin / one cert)
  ▼
nginx (frontend)
  │  serves the SPA, and reverse-proxies /phones /phone_book /shared_link
  │  /conference /socket /live  →  video_conference:80
  ▼
video_conference (backend)   ── signs JWTs (RSA private key)
  ▲
  │  https://localhost:4433  (WebTransport, cert pinned by SHA-256 hash)
  │  http3_server verifies the JWT (RSA public key)
  ▼
http3_server (media)
```

- The browser talks to a **single origin** (`localhost:8443`) for the SPA, API and
  websocket, so it only has to trust **one** self-signed cert.
- The media path (`http3_server`) uses a **separate** self-signed cert. Because it's
  self-signed, the browser pins it via `serverCertificateHashes` — which the W3C
  WebTransport spec only allows for certs valid **≤ 2 weeks**. That's why the media
  cert is generated for **12 days**.

## Prerequisites

- Docker + Docker Compose
- `openssl` (for cert generation)
- Two options:
  1. The three app repos cloned into this directory:

  ```bash
  git clone https://github.com/AlexeyAlexey/video_conference_vite.git
  git clone https://github.com/AlexeyAlexey/video_conference.git
  git clone https://github.com/AlexeyAlexey/http3_server.git
  ```

  (If already cloned, `git checkout main && git pull` to get the latest.)

  You should edit docker-compose.yml file. Look at commented "context" attribute.

  2. The three app repos cloned by docker. It is used by default

## 1. Generate certificates

All certs/keys are written to `certs/`. Run the all-in-one script:

```bash
cp .env.example .env

./scripts/gen_all_certs.sh localhost

# ./scripts/gen_all_certs.sh [HOST] (default: localhost)
```

This runs the three individual scripts:

| Script                          | Produces                                                        | Validity |
|---------------------------------|-----------------------------------------------------------------|----------|
| `scripts/gen_media_cert.sh`     | `certs/server.crt` + `server.key` (http3_server + backend HTTPS) **and** writes `HTTP3_SERVER_CERT_HASH` to `.env` | **12 days** (WebTransport pin limit) |
| `scripts/gen_frontend_cert.sh`  | `certs/frontend.crt` + `frontend.key` (nginx HTTPS)             | 365 days |
| `scripts/gen_jwt_keys.sh`       | `certs/telephone_switchboard_private_key.pem` (backend signs) + `certs/jwt_local_host_public_key.pem` (http3 verifies) | — |

You can also run any of them individually, e.g. to refresh just the expiring media
cert:

```bash
./scripts/gen_media_cert.sh        # default 12 days
./scripts/gen_media_cert.sh 10     # or a custom number of days (must be <= 12)
```

> **Note:** the media cert expires in 12 days. Re-run `./scripts/gen_media_cert.sh`
> (then `docker compose up -d --force-recreate`) before it lapses, or the browser
> will stop accepting the pinned cert.

## 2. Configure

Create `.env` from the template (the media-cert hash is filled in by
`gen_media_cert.sh`):

```bash
cp .env.example .env
```

`.env` holds `HTTP3_SERVER_CERT_HASH`, `JWT_SECRET`, and `SECRET_KEY_BASE`.

## 3. Build & run

```bash
docker compose build          # builds all three images (first time is slow)
docker compose up -d          # start the stack
docker compose logs -f        # follow logs
```

After (re)generating certs, force-recreate so the containers pick them up:

```bash
docker compose up -d --force-recreate
```

## 4. Use it

Open **https://localhost:8443** in your browser and accept the self-signed
certificate warning (once).

- Register a phone (the register form needs an `invitation_token`; the dev value is
  `1234321`), then log in.
- Add a contact and start a call — the media flows over WebTransport to
  `http3_server`.

### Ports

| Port | Service        | Purpose                                  |
|------|----------------|------------------------------------------|
| 8443 | frontend (nginx) | HTTPS SPA + API + websocket (main entry) |
| 443  | video_conference | HTTPS API + websocket (proxied by nginx)                   |
| 4433 | http3_server   | WebTransport media (TCP + UDP)           |

## Useful commands

```bash
docker compose ps                 # status
docker compose logs -f <service>  # logs for one service (frontend|video_conference|http3_server)
docker compose down               # stop (keeps images + data)
docker compose down -v            # stop and remove the data volume
docker compose build --no-cache   # rebuild from scratch
```

## Data & persistence

- The SQLite database lives in `./data/` (bind-mounted to `/app/data`).
- Certs/keys live in `./certs/` (mounted read-only into the containers).
- Both are git-ignored.

## Troubleshooting

- **`ERR_CERT_AUTHORITY_INVALID` on the frontend** — you regenerated the frontend
  cert; re-accept the new self-signed cert in the browser.
- **WebTransport fails with a certificate error** — the media cert is expired or the
  `HTTP3_SERVER_CERT_HASH` in `.env` doesn't match `certs/server.crt`. Re-run
  `./scripts/gen_media_cert.sh` and `docker compose up -d --force-recreate`.
- **Calls fail to authenticate** — the JWT keypair is out of sync. Re-run
  `./scripts/gen_jwt_keys.sh` and `docker compose up -d --force-recreate`.
- **`getUserMedia` / camera errors in the integrated browser** — that's a browser
  permission limitation, not a stack problem.

# Remote Server

You can run the app on a remote test server

```bash
git clone https://github.com/AlexeyAlexey/videoconference_docker_compose.git
```

If the app works on behalf of "nobody" (65534):

```bash

cd videoconference_docker_compose

mkdir ./data

chown -R 65534:65534 ./data
```

You can use the following command to know UID:

```bash
docker ps

docker exec -it <container_id> id
```

You should follow instructions: 

 -  [Generate certificates](1-generate-certificates)
  
 - [Configure](#2-configure)
  
 - [Build & run](#3-build--run)

# Info

[Secrets Management](https://distr.sh/docs/agents/secrets/)

[Docker Compose Secrets](https://distr.sh/docs/agents/docker-compose-secrets/)