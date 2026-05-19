# VideoConference

It was interesting to explore and test various libraries, as well as different approaches to implementing a video conferencing solution without using WebRTC.

I decided to use 

  - [WebCodecs](https://developer.mozilla.org/en-US/docs/Web/API/WebCodecs_API)
  - [WebTransport](https://developer.mozilla.org/en-US/docs/Web/API/WebTransport_API)


The WebCodecs API gives web developers low-level access to the individual frames of a video stream and chunks of audio. It is useful for web applications that require full control over the way media is processed. For example, video or audio editors, and video conferencing.


The WebTransport API provides a modern update to WebSockets, transmitting data between client and server using HTTP/3 Transport.


The main codebase is located in the following directory

  ```video_conference/assets/js```

Look at group_socket.js file

I will try to add more information about different parts of that code

This app uses [http3_server](https://github.com/AlexeyAlexey/http3_server) as Stream Server

## HTTP/3

HTTP/3 uses the QUIC protocol over UDP to eliminate head-of-line blocking, providing better performance on unstable networks and reducing latency.


It enables reliable transport via streams and unreliable transport via UDP-like datagrams.

I use a stream here, but datagrams could be used for the video stream, while a stream is better for the voice stream.

The way we manage the data packets we send needs to be revised to support datagrams.

When we open a stream and send chunks of video through it, the receiving side gets a continuous stream of bytes, so we need a way to determine where each chunk begins and ends.

look at

(group_socket.js file)
```
decodeChunk(payload) 
```

(group_socket.js file)
```
decodeAudioChunk(payload) 
```

(current_participant_camera.js file)
```
#encodeChunk(chunk)
```

(http3_stream_message_parser file)
```
 class Http3StreamMessageParser
```

```js
const http3ServerStreamVideoReaderStream = http3ServerStream.readable.pipeThrough(
      new TransformStream(new Http3StreamMessageParser(1024 * 1024)) // 1MB buffer
    );
```


# HTTP3 SERVE

It is a service that supports http/3 protocol




#### datagrams

If we use datagrams, we need to account for ordering and size limitations—each packet cannot exceed a certain maximum size. To work within these constraints, we would split each chunk into smaller parts and then reassemble them on the receiving side.


# Docker

```bash
docker build -t video_conference .

```

# with d

```bash
docker run  -d \
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

# without d
```bash
docker run  --name video_conference \
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


SECRET_KEY_BASE 64 length  (```mix phx.gen.secret```)


HTTP3_SERVER_CERT_HASH - If self signed cert is used, It is required


You can use the following commands to archive an copy an image to another computer/server

```bash
docker save -o video_conference.tar video_conference:latest
```

You can unarchive the image and to run it on another computer/server

```bash
docker load -i video_conference.tar

docker run -d -p 4000:4000 -p 4040:4040 video_conference
```

[requirements](https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-requirements)

```
    Target architecture (for example, x86_64 or ARM)
    Target vendor + operating system (for example, Windows, Linux, or Darwin/macOS)
    Target ABI (for example, musl or gnu)
```


# Setting up dev env


```bash
sudo apt update
sudo apt install dotenv-cli
```

Dev env

```bash
dotenv -e .env iex -S mix phx.server
```

Test env

```bash
dotenv -e .env.test mix test
```

# Copying release to a host machine 

The ```docker container``` create (or shorthand: docker create) command creates a new container from the specified image, without starting it.


```bash
docker create --name temp-video_conference video_conference

docker cp temp-video_conference:/app /path/to/release/folder
```

```bash
docker rm temp-video_conference
```


You can use the following command to archive a release

```bash
cd /path/to/release/folder

tar -czvf video_conference.tar.gz ./app
```

# Deploying to remote server

If you want to deploy it to remote server you can use the following approach.
If you want to use this approach you should read more what directory should be used what system users should be used and what permissions they should be have and what folder permissions should be.

The following example is a quick example 

Coping to remote server

```bash
scp ./video_conference.tar.gz roor@remote_ip:/path/to/destination/
```

```bash 
ssh user@remote_host "mkdir -p /path/to/directory"
```

decompress on remote server
```bash
tar -xvf video_conference.tar.gz
```


## Adding Service

```bash
cd /etc/systemd/system/
```

```bash
nano video_conference.service
```



```                                                                  
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

You can read more parameters in 

[Execution environment configuration](https://manpages.debian.org/trixie/systemd/systemd.exec.5.en.html)



I use EnvironmentFile to set up environment variable

/home/env/video_conference
```
PHX_SERVER=true
PHX_HOST="your IP"
PORT=4040
JWT_SECRET="BFH5WS/JXiNWFcNNHRrBxAm+yczW/kzn9yqfvtoITi3GHiyxDlGoHEqj1sQ7wULe"
SECRET_KEY_BASE="3ekUXBcKioR/Alnrm+RSl6c1Rf0kqBdLvjrnlPYqrTWSObL4/p7PJYt5v+X/du5o"
HTTP3_SERVER_HOST="http3 server IP"
HTTP3_SERVER_PORT=4433
SSL_KEY_PATH=/home/certs/server.key
SSL_CERT_PATH=/home/certs/server.crt
HTTP3_SERVER_CERT_HASH=11359926719aa95366099e87baefd7c27f6046b121aab42969702bd1eb9b8063
```

Set ownership to root
```bash
sudo chown root:root video_conference.service
```

# Set permissions to 644
```bash
sudo chmod 644 video_conference.service
```

```bash
# Apply changes to systemd
sudo systemctl daemon-reload
```



```bash
systemctl start video_conference

systemctl stop video_conference

systemctl restart video_conference

systemctl status video_conference


systemctl enable video_conference
```


## Self signed certificate (http/3 requires certificate)

Creating a directory for certificates (You should read more where to save a certs and about permissions)

```bash
mkdir -p /home/certs
```

self signed certificate example
```bash
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout server.key \
  -x509 -days 13 -out server.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:10.42.0.1"
```

If you use self signed certificate. A hash is required for HTTP3_SERVER_CERT_HASH variable
```bash
openssl x509 -in server.crt -outform DER | openssl dgst -sha256 -hex
```

# Logs

if you use
```
StandardOutput=journal
StandardError=journal
```

You can use the following command to view the app logs
```bash
journalctl -fu video_conference.service
```

## Log rotation

if you use

```
StandardOutput=journal
StandardError=journal
SyslogIdentifier=video_conference
```

You can use logrotate and rsyslog


# Added bash scrips to deploy the app to remote server

Added a couple of simple bash scripts (look at deploys folder)

It is required to do the script executable

```bash
chmod +x ./gen_release.sh
chmod +x ./copy_to_remote.sh
chmod +x ./switch_to_release.sh
```
  
  
  to generate a release to local folder

```bash
./gen_release.sh "/absolute/path/to/local/folder"
```

  to copy a release to remote server

```bash
./copy_to_remote.sh remote_user remote_host local_release_dir release_name remote_release_dir

./copy_to_remote.sh root "xx.xx.xx.xx" "/absolute/path/to/local/folder/with/release" "20260428_184535" "/absolute/path/to/folder/on/remote/server"
```

  to switch from one to another on on remote server

```bash 
./switch_to_release.sh remote_user remote_host release
./switch_to_release.sh root "xx.xx.xx.xx" 20260428_184535
```