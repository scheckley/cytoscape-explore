# Use node:14-buster as the base image
FROM node:14-buster

# Allow user configuration of variable at build-time
ARG NODE_ENV
ENV NODE_ENV=${NODE_ENV:-production}

# Create a numeric user/group that fits OpenShift's requirements
RUN groupadd -r -g 1001 appgroup && useradd -r -g appgroup -u 1001 appuser

# Create app directory and set permissions - critical for OpenShift
RUN mkdir -p /app /app/.npm /app/.local/share/applications \
    /app/.config/google-chrome /app/.cache/google-chrome /app/.config && \
    chown -R 1001:1001 /app && \
    chmod -R g+rwx /app

WORKDIR /app

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

# Copy application files
COPY --chown=1001:1001 . /app/

# Switch to non-root user
USER 1001

# Set environment variables for Chrome and npm
ENV HOME=/app \
    CHROME_PATH=/usr/bin/google-chrome \
    XDG_DATA_HOME=/app/.local/share \
    NPM_CONFIG_PREFIX=/app/.npm \
    PATH="/app/.npm/bin:${PATH}" \
    SKIP_PREFLIGHT_CHECK=true

# Install global dependencies
RUN npm install -g npm-run-all rimraf

# Install dependencies
RUN npm ci --only=production

# Copy and set permissions for entrypoint
COPY --chown=1001:1001 entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

# Expose port 8080 for OpenShift
EXPOSE 8080

# Set the entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]