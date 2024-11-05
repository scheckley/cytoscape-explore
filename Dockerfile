# Use node:14-buster as the base image
FROM node:14-buster

# Allow user configuration of variable at build-time
ARG NODE_ENV
ENV NODE_ENV=${NODE_ENV:-production}

# Set up environment variables first
ENV NPM_CONFIG_PREFIX=/app/.npm \
    PATH="/app/.npm/bin:${PATH}" \
    HOME=/app \
    CHROME_PATH=/usr/bin/google-chrome \
    XDG_DATA_HOME=/app/.local/share \
    SKIP_PREFLIGHT_CHECK=true

# Create all required directories and set permissions
# This must be done as root before switching to non-root user
RUN mkdir -p /app && \
    mkdir -p /app/.npm && \
    mkdir -p /app/.local/share/applications && \
    mkdir -p /app/.config/google-chrome && \
    mkdir -p /app/.cache/google-chrome && \
    mkdir -p /app/.config && \
    mkdir -p /app/.npm/_cacache && \
    mkdir -p /app/.npm/_logs && \
    mkdir -p /app/build && \
    chown -R 1001:0 /app && \
    chmod -R g=u /app && \
    chmod -R 775 /app

# Install system dependencies including Chrome
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf \
    libxss1 libxtst6 libasound2 libatk1.0-0 libatk-bridge2.0-0 libcairo2 libcups2 libdbus-1-3 libexpat1 \
    libfontconfig1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libnspr4 libpango-1.0-0 \
    libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 \
    libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 ca-certificates fonts-liberation libappindicator1 \
    libnss3 lsb-release xdg-utils wget gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list && \
    apt-get update && \
    apt-get install -y google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# Switch to non-root user
USER 1001

WORKDIR /app

# Copy package files first
COPY --chown=1001:0 package*.json ./

# Install dependencies including global packages
RUN npm config set cache /app/.npm/_cacache && \
    npm ci --only=production && \
    npm install -g npm-run-all rimraf && \
    # Clear npm cache after installation
    npm cache clean --force

# Copy application files
COPY --chown=1001:0 . .

# Expose port 8080 for OpenShift
EXPOSE 8080

# Set the entrypoint
COPY --chown=1001:0 entrypoint.sh ./
RUN chmod 775 /app/entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]