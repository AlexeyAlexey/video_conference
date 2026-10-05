# VideoConference

An experiment in building video conferencing **without WebRTC**, using:

- [WebCodecs](https://developer.mozilla.org/en-US/docs/Web/API/WebCodecs_API) — low-level access to individual video frames and audio chunks, giving full control over how media is processed (e.g. editors, video conferencing).
- [WebTransport](https://developer.mozilla.org/en-US/docs/Web/API/WebTransport_API) — a modern alternative to WebSockets, transmitting data between client and server over HTTP/3.

## Architecture

| Component | Repository / Role |
|-----------|-------------------|
| Backend (this repo) | Phoenix 1.8 API + Channels (phone auth, phone book, shared links, call signaling). SQLite via `ecto_sqlite3`, Bandit HTTP server |
| Stream server | [http3_server](https://github.com/AlexeyAlexey/http3_server) — HTTP/3 (WebTransport) media relay |
| Frontend | [video_conference_vite](https://github.com/AlexeyAlexey/video_conference_vite) — Vite + vanilla JS app using WebCodecs/WebTransport |
| All-in-one setup | [videoconference_docker_compose](https://github.com/AlexeyAlexey/videoconference_docker_compose) — runs all three apps together |

## HTTP/3

HTTP/3 uses the QUIC protocol over UDP to eliminate head-of-line blocking, providing better performance on unstable networks and reducing latency.

It enables reliable transport via streams and unreliable transport via UDP-like datagrams.

The app currently uses streams, but datagrams could be used for video while a stream is better suited for audio. The way data packets are managed needs to be revised to support datagrams.

When a stream is opened and chunks of video are sent through it, the receiving side gets a continuous stream of bytes, so a way to determine where each chunk begins and ends is needed. Look at [video_conference_vite](https://github.com/AlexeyAlexey/video_conference_vite) for an example implementation.

### Datagrams

If we use datagrams, we need to account for ordering and size limitations — each packet cannot exceed a certain maximum size. To work within these constraints, each chunk would be split into smaller parts and reassembled on the receiving side.

## Development setup

### Prerequisites

```bash
sudo apt update
sudo apt install dotenv-cli
```

### Environment variables

Copy `.env.example` to `.env` and `.env.test.example` to `.env.test`, then adjust the values.

| Variable | Description |
|----------|-------------|
| `MIX_ENV` | Mix environment (`dev`/`test`) |
| `PHX_HOST` | Hostname used for URL generation |
| `PHX_SERVER` | Set to `true` to start the server in releases |
| `PORT` | HTTP port (default `4000`) |
| `DATABASE_PATH` | Path to the SQLite database file |
| `SECRET_KEY_BASE` | Phoenix secret (64+ chars, generate with `mix phx.gen.secret`) |
| `JWT_SECRET` | Secret used by Joken for auth tokens |
| `TELEPHONE_SWITCHBOARD_PRIVET_KEY` | RSA private key (PEM) used to sign stream-server auth tokens |
| `HTTP3_SERVER_HOST` | Stream server host |
| `HTTP3_SERVER_PORT` | Stream server port (default `4433`) |
| `HTTP3_SERVER_CERT_HASH` | SHA-256 hash of the stream server certificate — required when it uses a self-signed cert |
| `SSL_KEY_PATH` / `SSL_CERT_PATH` | TLS key/cert paths |

### Running

```bash
dotenv -e .env iex -S mix phx.server
```

### Tests

```bash
dotenv -e .env.test mix test
```

### Other useful commands

```bash
mix setup        # install deps, create DB, run migrations, seed, build assets
mix ecto.reset   # drop DB and run ecto.setup
mix precommit    # compile (warnings as errors), format, run tests
```

## Docker

### Build

```bash
docker build -t video_conference .
```

### Run in detached mode

```bash
docker run -d \
  --name video_conference \
  -p 4000:4000 -p 4040:4040 \
  -v "/path/to/certs/folder/on/host/machine/certs:/app/certs:ro" \
  -e PHX_SERVER=true \
  -e PHX_HOST=localhost \
  -e PORT=4040 \
  -e JWT_SECRET="xxxxxxxxxxxxxxxxx" \
  -e SECRET_KEY_BASE="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -e SSL_KEY_PATH=/app/certs/server.key \
  -e SSL_CERT_PATH=/app/certs/server.crt \
  video_conference
```

### Run in foreground

```bash
docker run --name video_conference \
  -p 4000:4000 -p 4040:4040 \
  -v "/path/to/certs/folder/on/host/machine/certs:/app/certs:ro" \
  -e PHX_SERVER=true \
  -e PHX_HOST=localhost \
  -e PORT=4040 \
  -e JWT_SECRET="xxxxxxxxxxxxxxxxx" \
  -e SECRET_KEY_BASE="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -e HTTP3_SERVER_HOST=localhost \
  -e HTTP3_SERVER_PORT=4433 \
  -e SSL_KEY_PATH=/app/certs/server.key \
  -e SSL_CERT_PATH=/app/certs/server.crt \
  -e HTTP3_SERVER_CERT_HASH=380f661e9e24c0b9bcb2d760302e8290417fafa3227cb967f41ddd5a7a9ac5bb \
  video_conference
```

Notes:

- `SECRET_KEY_BASE` must be 64 characters long (`mix phx.gen.secret`)
- `HTTP3_SERVER_CERT_HASH` is required if a self-signed certificate is used

### Moving an image to another machine

Archive the image:

```bash
docker save -o video_conference.tar video_conference:latest
```

Load and run it on the target machine:

```bash
docker load -i video_conference.tar

docker run -d -p 4000:4000 -p 4040:4040 video_conference
```

See [release requirements](https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-requirements) for the target architecture/vendor/ABI compatibility notes.

## Deployment

### Copying a release out of a container

`docker create` creates a container from an image without starting it:

```bash
docker create --name temp-video_conference video_conference

docker cp temp-video_conference:/app /path/to/release/folder

docker rm temp-video_conference
```

Archive the release:

```bash
cd /path/to/release/folder

tar -czvf video_conference.tar.gz ./app
```

### Deploying to a remote server

A quick example — read up on which directory, system users, and file permissions are appropriate before using this in production.

Copy the archive to the remote server:

```bash
scp ./video_conference.tar.gz root@remote_ip:/path/to/destination/
```

```bash
ssh user@remote_host "mkdir -p /path/to/directory"
```

Decompress on the remote server:

```bash
tar -xvf video_conference.tar.gz
```

### systemd service

```bash
cd /etc/systemd/system/
nano video_conference.service
```

```ini
[Unit]
Description=Video conference app

[Service]
Type=simple
User=root
WorkingDirectory=/home/video_conference/app
ExecStart=/home/video_conference/app/bin/video_conference start
ExecStop=/home/video_conference/app/bin/video_conference stop
Restart=on-failure
EnvironmentFile=/home/env/video_conference
StandardOutput=journal
StandardError=journal
SyslogIdentifier=video_conference

[Install]
WantedBy=multi-user.target
```

More parameters: [execution environment configuration](https://manpages.debian.org/trixie/systemd/systemd.exec.5.en.html)

`EnvironmentFile` is used to set environment variables — `/home/env/video_conference`:

```bash
PHX_SERVER=true
PHX_HOST="your IP"
PORT=4040
JWT_SECRET="generate_a_random_secret"
SECRET_KEY_BASE="generate_with_mix_phx_gen_secret"
HTTP3_SERVER_HOST="http3 server IP"
HTTP3_SERVER_PORT=4433
SSL_KEY_PATH=/home/certs/server.key
SSL_CERT_PATH=/home/certs/server.crt
HTTP3_SERVER_CERT_HASH=your_stream_server_cert_sha256_hash
```

Set ownership and permissions:

```bash
sudo chown root:root video_conference.service
sudo chmod 644 video_conference.service
```

Apply changes and manage the service:

```bash
sudo systemctl daemon-reload

systemctl start video_conference
systemctl stop video_conference
systemctl restart video_conference
systemctl status video_conference
systemctl enable video_conference
```

## Certificates

HTTP/3 requires a certificate. Create a directory for certificates (read up on where to store certs and the right permissions):

```bash
mkdir -p /home/certs
```

Self-signed certificate example:

```bash
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout server.key \
  -x509 -days 13 -out server.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:10.42.0.1"
```

If a self-signed certificate is used, its SHA-256 hash is required for the `HTTP3_SERVER_CERT_HASH` variable:

```bash
openssl x509 -in server.crt -outform DER | openssl dgst -sha256 -hex
```

### Switchboard key pair

The backend signs stream-server auth tokens (JWT, RS256) with an RSA key pair. Generate it with:

```bash
openssl genrsa -out private_key.pem 2048
openssl rsa -in private_key.pem -outform PEM -pubout -out public_key.pem
```

Set `TELEPHONE_SWITCHBOARD_PRIVET_KEY` to the contents of `private_key.pem`.

## Logs

If the service is configured with:

```ini
StandardOutput=journal
StandardError=journal
```

view the app logs with:

```bash
journalctl -fu video_conference.service
```

### Log rotation

If the service uses:

```ini
StandardOutput=journal
StandardError=journal
SyslogIdentifier=video_conference
```

you can use `logrotate` and `rsyslog`.

## Deploy scripts

A couple of simple bash scripts live in the `deploys` folder. Make them executable:

```bash
chmod +x ./gen_release.sh
chmod +x ./copy_to_remote.sh
chmod +x ./switch_to_release.sh
```

Generate a release into a local folder:

```bash
./gen_release.sh "/absolute/path/to/local/folder"
```

Copy a release to a remote server:

```bash
./copy_to_remote.sh remote_user remote_host local_release_dir release_name remote_release_dir

./copy_to_remote.sh root "xx.xx.xx.xx" "/absolute/path/to/local/folder/with/release" "20260428_184535" "/absolute/path/to/folder/on/remote/server"
```

Switch releases on the remote server:

```bash
./switch_to_release.sh remote_user remote_host release
./switch_to_release.sh root "xx.xx.xx.xx" 20260428_184535
```
