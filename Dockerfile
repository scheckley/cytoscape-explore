# Use a more recent Node.js version with Debian Bullseye base
FROM node:18-bullseye-slim

# Build arguments and environment variables
ARG NODE_ENV
ENV NODE_ENV=${NODE_ENV:-production} \
    NPM_CONFIG_PREFIX=/app/.npm \
    PATH="/app/.npm/bin:${PATH}" \
    HOME=/app \
    CHROME_PATH=/usr/bin/google-chrome \
    XDG_DATA_HOME=/app/.local/share \
    SKIP_PREFLIGHT_CHECK=true \
    # Chrome flags for running without root
    CHROMIUM_FLAGS="--headless --no-sandbox --disable-dev-shm-usage --disable-gpu --disable-software-rasterizer --disable-dbus" \
    # Disable features that require privileged access
    CHROME_DBUS_SYSTEM_BUS_SOCKET=0 \
    CHROME_OOM_SCORE_ADJUST=0

# Create non-root user and set up directory structure
RUN useradd -u 1001 -r -g 0 -d /app appuser && \
    mkdir -p \
    /app \
    /app/.npm \
    /app/.local/share/applications \
    /app/.config/google-chrome \
    /app/.cache/google-chrome \
    /app/.config \
    /app/.npm/_cacache \
    /app/.npm/_logs \
    /app/build && \
    # Create dummy dbus directory to prevent errors
    mkdir -p /var/run/dbus && \
    # Set permissions
    chown -R 1001:0 /app && \
    chmod -R g=u /app && \
    chmod -R 775 /app

# Install Chrome and dependencies in a single layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf \
    libxss1 libxtst6 libasound2 libatk1.0-0 libatk-bridge2.0-0 libcairo2 libcups2 \
    libdbus-1-3 libexpat1 libfontconfig1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 \
    libglib2.0-0 libgtk-3-0 libnspr4 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 \
    libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 \
    libxfixes3 libxi6 libxrandr2 libxrender1 ca-certificates fonts-liberation \
    libappindicator1 libnss3 lsb-release xdg-utils wget gnupg && \
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list && \
    apt-get update && \
    apt-get install -y google-chrome-stable && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Switch to non-root user
USER 1001
WORKDIR /app

# Copy package files and install dependencies
COPY --chown=1001:0 package*.json ./

RUN npm install --no-global
RUN chown -R 1001:0 /app && chmod -R g=u /app

# Install ALL dependencies including devDependencies for build process
RUN npm config set cache /app/.npm/_cacache --global && \
    npm ci --unsafe-perm && \
    npm install npm-run-all rimraf webpack webpack-cli --save-dev --unsafe-perm && \
    npm cache clean --force

# Copy application files
COPY --chown=1001:0 . .

# Build the application
RUN npm run build

# Remove devDependencies after build
RUN if [ "${NODE_ENV}" = "production" ]; then \
    npm prune --production; \
    fi

# Copy and set up entrypoint script
COPY --chown=1001:0 entrypoint.sh ./
RUN chmod 775 /app/entrypoint.sh

# Expose port for OpenShift
EXPOSE 8080

ENTRYPOINT ["./entrypoint.sh"]