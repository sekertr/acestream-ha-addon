ARG BUILD_FROM
FROM ${BUILD_FROM}

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="sekertr" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="sekertr" \
    org.opencontainers.image.authors="sekertr" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://github.com/sekertr/acestream-ha-addon" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/sekertr/acestream-ha-addon/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}

# Install required packages
RUN apk add --no-cache \
    nginx \
    curl \
    bash \
    docker \
    docker-cli \
    jq \
    python3 \
    py3-pip

# Copy root filesystem
COPY rootfs /

# Make scripts executable
RUN chmod a+x /run.sh

# Set working directory
WORKDIR /

CMD ["/run.sh"]
