# Use Node 14 image
FROM node:14.18.3

# Set build-time argument for environment configuration
ARG NODE_ENV
ENV NODE_ENV ${NODE_ENV:-production}

# Create and set up an unprivileged user and app directory
RUN useradd -m -s /bin/bash appuser \
    && mkdir -p /home/appuser/app \
    && mkdir -p /home/appuser/.npm \
    && chown -R appuser:appuser /home/appuser

# Set the working directory to the app directory
WORKDIR /home/appuser/app

# Copy application source code to app directory
COPY . .

# Install dependencies required for Chromium
RUN apt-get update && apt-get install -y \
    chromium \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    fonts-thai-tlwg \
    fonts-kacst \
    fonts-freefont-ttf \
    libxss1 \
    libxtst6 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcairo2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libgdk-pixbuf2.0-0 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libnss3 \
    --no-install-recommends && rm -rf /var/lib/apt/lists/*

# Configure npm to use the user's .npm directory
ENV NPM_CONFIG_CACHE=/home/appuser/.npm

# Install app dependencies as appuser
USER appuser
RUN npm ci --no-optional

# Expose the application port
EXPOSE 3000

# Copy entrypoint script
COPY entrypoint.sh /

# Start the application
CMD ["/bin/bash", "/entrypoint.sh"]
