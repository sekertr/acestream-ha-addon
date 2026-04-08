#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Acestream Proxy
# Runs acestream via Docker and proxies HTTP requests
# ==============================================================================

set -e

bashio::log.info "Starting Acestream Proxy Add-on..."

# Read config options
ACESTREAM_IMAGE=$(bashio::config 'acestream_image')
LOG_LEVEL=$(bashio::config 'log_level')

bashio::log.info "Acestream image: ${ACESTREAM_IMAGE}"
bashio::log.info "Log level: ${LOG_LEVEL}"

# ---------------------------------------------------------------------------
# Check if Docker socket is available
# ---------------------------------------------------------------------------
if [ ! -S /var/run/docker.sock ]; then
    bashio::log.fatal "Docker socket not found at /var/run/docker.sock"
    exit 1
fi

bashio::log.info "Docker socket found. Fixing permissions..."

# Try to fix Docker socket permissions automatically
# HA OS has a read-only filesystem so we use nsenter to reach the host
if ! nsenter -t 1 -m -u -i -n -p -- chmod 666 /var/run/docker.sock 2>/dev/null; then
    # Fallback: try direct chmod (works if already have permission)
    chmod 666 /var/run/docker.sock 2>/dev/null || true
fi

bashio::log.info "Checking Docker availability..."

if ! docker info > /dev/null 2>&1; then
    bashio::log.fatal "Cannot connect to Docker daemon!"
    bashio::log.fatal "Try running in SSH: nsenter -t 1 -m -u -i -n -p -- chmod 666 /var/run/docker.sock"
    exit 1
fi

bashio::log.info "Docker is available."

# ---------------------------------------------------------------------------
# Stop and remove any existing acestream container
# ---------------------------------------------------------------------------
CONTAINER_NAME="ha_acestream_engine"

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    bashio::log.info "Removing existing acestream container..."
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Pull latest acestream image
# ---------------------------------------------------------------------------
bashio::log.info "Pulling acestream image: ${ACESTREAM_IMAGE}..."
docker pull "${ACESTREAM_IMAGE}" || {
    bashio::log.warning "Failed to pull image. Will try to use cached version if available."
}

# ---------------------------------------------------------------------------
# Start acestream container
# ---------------------------------------------------------------------------
bashio::log.info "Starting acestream container..."

docker run -d \
    --name "${CONTAINER_NAME}" \
    --network host \
    --restart unless-stopped \
    -p 6878:6878 \
    "${ACESTREAM_IMAGE}" || {
    bashio::log.fatal "Failed to start acestream container!"
    exit 1
}

bashio::log.info "Acestream container started. Waiting for engine to be ready..."

# ---------------------------------------------------------------------------
# Wait for acestream engine to be ready
# ---------------------------------------------------------------------------
MAX_WAIT=60
WAITED=0
ACESTREAM_URL="http://127.0.0.1:6878/server/api?api_version=3&method=get_version"

while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -sf "${ACESTREAM_URL}" > /dev/null 2>&1; then
        bashio::log.info "Acestream engine is ready!"
        break
    fi
    bashio::log.info "Waiting for acestream engine... (${WAITED}/${MAX_WAIT}s)"
    sleep 2
    WAITED=$((WAITED + 2))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    bashio::log.warning "Acestream engine did not respond within ${MAX_WAIT}s. Continuing anyway..."
fi

# ---------------------------------------------------------------------------
# Configure and start nginx proxy
# ---------------------------------------------------------------------------
bashio::log.info "Configuring nginx proxy..."

# Get ingress entry point if available
INGRESS_ENTRY=$(bashio::addon.ingress_entry 2>/dev/null || echo "")

cat > /etc/nginx/nginx.conf << EOF
worker_processes 1;
error_log /dev/stderr warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent"';

    access_log /dev/stdout main;

    sendfile on;
    keepalive_timeout 65;
    
    # Increase timeouts for streaming
    proxy_connect_timeout   300s;
    proxy_send_timeout      300s;
    proxy_read_timeout      300s;
    send_timeout            300s;

    server {
        listen 6878 default_server;
        listen [::]:6878 default_server;

        server_name _;

        # Health check endpoint
        location /health {
            return 200 'Acestream Proxy OK';
            add_header Content-Type text/plain;
        }

        # Status page
        location = / {
            return 200 'Acestream HA Proxy is running. Use /ace/getstream?id=<content_id> to stream.';
            add_header Content-Type text/plain;
        }

        # Proxy all acestream API requests
        location / {
            proxy_pass http://127.0.0.1:6878;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # Important for streaming
            proxy_buffering off;
            proxy_cache off;
            proxy_set_header Connection '';
            chunked_transfer_encoding on;
        }
    }
}
EOF

bashio::log.info "Starting nginx..."
nginx -g "daemon off;" &
NGINX_PID=$!

bashio::log.info "============================================"
bashio::log.info "Acestream Proxy is running!"
bashio::log.info "Stream URL format:"
bashio::log.info "http://<HA_IP>:6878/ace/getstream?id=<content_id>"
bashio::log.info "============================================"

# ---------------------------------------------------------------------------
# Monitor acestream container health
# ---------------------------------------------------------------------------
monitor_acestream() {
    while true; do
        sleep 30

        # Check if nginx is still running
        if ! kill -0 $NGINX_PID 2>/dev/null; then
            bashio::log.error "nginx died! Exiting..."
            exit 1
        fi

        # Check if acestream container is still running
        if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            bashio::log.warning "Acestream container stopped! Restarting..."
            docker start "${CONTAINER_NAME}" 2>/dev/null || {
                bashio::log.error "Failed to restart acestream container. Trying fresh start..."
                docker run -d \
                    --name "${CONTAINER_NAME}" \
                    --network host \
                    --restart unless-stopped \
                    -p 6878:6878 \
                    "${ACESTREAM_IMAGE}" || bashio::log.error "Failed to restart acestream!"
            }
        fi
    done
}

monitor_acestream &

# Wait for nginx to exit
wait $NGINX_PID
