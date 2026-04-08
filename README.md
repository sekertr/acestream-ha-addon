# Acestream HA Addon

[![Build and Publish Addon](https://github.com/sekertr/acestream-ha-addon/actions/workflows/build.yml/badge.svg)](https://github.com/sekertr/acestream-ha-addon/actions/workflows/build.yml)

Home Assistant addon that runs [Acestream](https://acestream.org/) engine via Docker and exposes an HTTP proxy so you can stream Acestream content from any device on your network.

## Features

- 🎬 **HTTP Proxy** — Stream any Acestream content via simple HTTP URL
- 🏠 **HA Integration** — Runs as a native Home Assistant addon
- 🔄 **Auto-restart** — Monitors and restarts Acestream engine if it crashes
- 📱 **Network-wide** — Access streams from any device (TV, phone, Kodi, VLC...)
- 🍓 **RPi4 Ready** — Built for `aarch64` (Raspberry Pi 4)

## Installation

### Method 1: Add Repository (Recommended)

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**
2. Click the **⋮ menu** (top right) → **Repositories**
3. Add this URL:
   ```
   https://github.com/sekertr/acestream-ha-addon
   ```
4. Find **Acestream Proxy** in the store and click **Install**

### Method 2: Manual

Copy the `acestream/` folder to your HA config directory:
```
/config/addons/acestream/
```
Then go to **Settings → Add-ons → Add-on Store → ⋮ → Check for updates**

## Prerequisites

> ⚠️ **Important:** This addon requires access to the Docker socket.

Since the Acestream engine itself runs as a Docker container (pulled from `jopsis/acestream`), the addon needs to communicate with Docker. You need to expose the Docker socket:

On your Home Assistant OS host, run via SSH addon:
```bash
chmod 666 /var/run/docker.sock
```

Or add this to your HA configuration for persistence — see [Docker socket documentation](https://developers.home-assistant.io/docs/add-ons/communication).

## Configuration

```yaml
acestream_image: "jopsis/acestream"   # Docker image to use
log_level: "info"                     # Logging verbosity
```

| Option | Default | Description |
|---|---|---|
| `acestream_image` | `jopsis/acestream` | Docker Hub image for the Acestream engine |
| `log_level` | `info` | Log level: `trace`, `debug`, `info`, `warning`, `error` |

## Usage

Once the addon is running, stream Acestream content via:

```
http://<YOUR_HA_IP>:6878/ace/getstream?id=<CONTENT_ID>
```

### Example

```
http://192.168.1.100:6878/ace/getstream?id=367f1bb1d5e85bbffcc14bd8b7297da7f4fa2e51
```

### Use with VLC

1. Open VLC
2. Go to **Media → Open Network Stream**
3. Paste the URL above

### Use with Kodi

1. Install the **IPTV Simple Client** addon
2. Add the stream URL as an M3U source or directly as a channel

### Use with Home Assistant Media Player

```yaml
service: media_player.play_media
target:
  entity_id: media_player.my_player
data:
  media_content_type: video
  media_content_id: "http://192.168.1.100:6878/ace/getstream?id=367f1bb1d5e85bbffcc14bd8b7297da7f4fa2e51"
```

### Check Acestream Engine Status

```
http://<YOUR_HA_IP>:6878/server/api?api_version=3&method=get_version
```

## Supported Platforms

| Architecture | Supported |
|---|---|
| `aarch64` (RPi4 64-bit) | ✅ |
| `amd64` | ❌ (planned) |
| `armv7` | ❌ (not supported by acestream) |

## Ports

| Port | Description |
|---|---|
| `6878` | Acestream HTTP proxy (TCP) |

## How It Works

```
Client (VLC/Kodi/TV)
        │
        ▼ HTTP :6878
  [HA Addon - nginx]
        │
        ▼ proxy_pass
  [Acestream Engine]  ← Docker container (jopsis/acestream)
        │
        ▼
  [P2P Network]
```

1. The addon starts and pulls the `jopsis/acestream` Docker image
2. Launches the Acestream engine container with `--network host`
3. Starts an nginx reverse proxy on port `6878`
4. Your requests go through nginx → Acestream engine → P2P network

## Troubleshooting

### Addon won't start
- Check that Docker socket is accessible: `ls -la /var/run/docker.sock`
- Run `chmod 666 /var/run/docker.sock` via SSH

### Stream won't play
- Verify the content ID is valid and the stream is live
- Check addon logs: **Settings → Add-ons → Acestream Proxy → Log**
- Test the engine API: `http://<HA_IP>:6878/server/api?api_version=3&method=get_version`

### Port 6878 already in use
- Stop any other Acestream instance running on your network
- Restart the addon

## License

MIT License — see [LICENSE](LICENSE) for details.

## Credits

- Acestream engine Docker image by [jopsis](https://hub.docker.com/r/jopsis/acestream)
- Built for the Home Assistant community
