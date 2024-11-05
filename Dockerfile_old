# Use node:14-buster as the base image to use a supported Debian version
FROM node:14-buster

# Allow user configuration of variable at build-time using --build-arg flag
ARG NODE_ENV

# Initialize environment and override with build-time flag, if set
ENV NODE_ENV=${NODE_ENV:-production}

# Switch to a non-root user and create a directory structure for them
RUN groupadd -r appuser && useradd -r -g appuser -d /home/appuser -s /sbin/nologin appuser

# Create necessary directories and set permissions
RUN mkdir -p /home/appuser/app /home/appuser/.npm && \
    chown -R appuser:appuser /home/appuser

WORKDIR /home/appuser/app

# Copy the source code to the app directory
COPY --chown=appuser:appuser . /home/appuser/app

# Install app dependencies as appuser to avoid root-level installs
USER appuser
RUN npm ci --only=production

# Switch to root to install system dependencies, including Google Chrome
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf \
    libxss1 libxtst6 libasound2 libatk1.0-0 libatk-bridge2.0-0 libcairo2 libcups2 libdbus-1-3 libexpat1 \
    libfontconfig1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libnspr4 libpango-1.0-0 \
    libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 \
    libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 ca-certificates fonts-liberation libappindicator1 \
    libnss3 lsb-release xdg-utils wget gnupg \
    && rm -rf /var/lib/apt/lists/*

# Add Google Chrome’s signing key and repository
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list && \
    apt-get update && \
    apt-get install -y google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# Expose port 8080 instead of 3000 for OpenShift
EXPOSE 8080

# Use appuser for the runtime
USER appuser

# Apply start commands
COPY entrypoint.sh /
CMD ["/entrypoint.sh"]
