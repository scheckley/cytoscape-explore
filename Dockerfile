# Use Node.js 18 slim base with security updates
FROM node:18-bullseye-slim

# Build arguments and environment variables
ARG NODE_ENV
ENV NODE_ENV=${NODE_ENV:-production} \
    NPM_CONFIG_PREFIX=/app/.npm-global \
    PATH="/app/.npm-global/bin:/app/node_modules/.bin:${PATH}" \
    HOME=/app \
    # Disable Chrome sandbox and other privileged features for OpenShift
    CHROMIUM_FLAGS="--headless --no-sandbox --disable-dev-shm-usage --disable-gpu --disable-setuid-sandbox --no-zygote" \
    # Reduce logging and disable features requiring privileged access
    CHROME_DBUS_SYSTEM_BUS_SOCKET=0 \
    CHROME_LOG_FILE=/dev/null \
    CHROME_LOG_LEVEL=3 \
    # Skip React preflight checks
    SKIP_PREFLIGHT_CHECK=true

# Create OpenShift-compatible directory structure with arbitrary user support
RUN mkdir -p /app && \
    chgrp -R 0 /app && \
    chmod -R g=u /app && \
    mkdir -p \
    /app/.npm-global \
    /app/.config/google-chrome \
    /app/.cache/google-chrome \
    /app/build && \
    chmod 775 /app/build

# Install Chrome and minimal dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    gnupg \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libgbm1 \
    libgtk-3-0 \
    libnss3 \
    xdg-utils && \
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list && \
    apt-get update && \
    apt-get install -y google-chrome-stable && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files
COPY --chown=0:0 package*.json ./

# Install dependencies with improved error handling
RUN npm config set cache /app/.npm-global/_cacache && \
    npm cache clean --force && \
    rm -rf node_modules && \
    # Install dependencies with legacy peer deps
    npm ci --legacy-peer-deps && \
    # Install build tools globally
    npm install -g npm-run-all@4.1.5 rimraf@3.0.2 webpack webpack-cli && \
    # Clean npm cache
    npm cache clean --force

# Copy application files
COPY --chown=0:0 . .

# Create a basic webpack config if needed
RUN if [ ! -f webpack.config.js ]; then \
    echo 'module.exports = { \
      mode: "production", \
      entry: "./src/index.js", \
      output: { \
        filename: "bundle.js", \
        path: __dirname + "/build" \
      }, \
      module: { \
        rules: [ \
          { \
            test: /\.js$/, \
            exclude: /node_modules/, \
            use: { \
              loader: "babel-loader" \
            } \
          }, \
          { \
            test: /\.css$/, \
            use: ["style-loader", "css-loader"] \
          } \
        ] \
      } \
    }' > webpack.config.js; \
    fi

# Build with verbose output
RUN set -x && \
    echo "Node version: $(node --version)" && \
    echo "NPM version: $(npm --version)" && \
    echo "Webpack version: $(webpack --version)" && \
    echo "PATH: $PATH" && \
    echo "Directory contents:" && ls -la && \
    # Run build with additional debugging
    NODE_OPTIONS="--max-old-space-size=4096" npm run build --verbose || { \
        echo "Build failed. Debugging information:"; \
        echo "Package.json contents:"; \
        cat package.json; \
        echo "Node modules binaries:"; \
        ls -la node_modules/.bin; \
        echo "Webpack config:"; \
        cat webpack.config.js; \
        exit 1; \
    }

# Only remove devDependencies in production
RUN if [ "$NODE_ENV" = "production" ]; then \
    npm prune --production; \
    fi

# Copy and setup entrypoint
COPY --chown=0:0 entrypoint.sh ./
RUN chmod g+x ./entrypoint.sh

# OpenShift runs containers with a random UID, so we need group permission
USER 1001

# Default to port 8080 for OpenShift
EXPOSE 8080

ENTRYPOINT ["./entrypoint.sh"]