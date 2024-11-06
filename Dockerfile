# Use a more recent Node.js version with Debian Bullseye base
FROM node:18-bullseye-slim

# Build arguments and environment variables
ARG NODE_ENV
ENV NODE_ENV=${NODE_ENV:-production} \
    NPM_CONFIG_PREFIX=/app/.npm \
    PATH="/app/.npm/bin:/app/node_modules/.bin:${PATH}" \
    HOME=/app \
    CHROME_PATH=/usr/bin/google-chrome \
    XDG_DATA_HOME=/app/.local/share \
    SKIP_PREFLIGHT_CHECK=true \
    # Chrome flags for running without root
    CHROMIUM_FLAGS="--headless --no-sandbox --disable-dev-shm-usage --disable-gpu --disable-software-rasterizer --disable-dbus --disable-notifications --disable-extensions --disable-logging --disable-in-process-stack-traces --disable-crash-reporter --disable-permissions-api --disable-setuid-sandbox --no-zygote --single-process" \
    # Disable features that require privileged access
    CHROME_DBUS_SYSTEM_BUS_SOCKET=0 \
    CHROME_OOM_SCORE_ADJUST=0 \
    CHROME_LOG_FILE=/dev/null \
    CHROME_LOG_LEVEL=3

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
    mkdir -p /var/run/dbus && \
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

# Copy package files first
COPY --chown=1001:0 package*.json ./

# Install dependencies with specific webpack setup for cytoscape-explore
RUN npm config set cache /app/.npm/_cacache && \
    # Remove any existing node_modules to ensure clean install
    rm -rf node_modules && \
    # Install dependencies without production flag to include dev dependencies
    npm install && \
    # Install specific webpack version locally
    npm install --save-dev \
    webpack@4.46.0 \
    webpack-cli@4.9.2 \
    webpack-dev-server@4.9.3 \
    babel-loader@8.2.5 \
    @babel/core@7.18.9 \
    @babel/preset-env@7.18.9 \
    style-loader@3.3.1 \
    css-loader@6.7.1 && \
    # Install global packages
    npm install -g npm-run-all@4.1.5 rimraf@3.0.2 && \
    # Create webpack executable link
    ln -s /app/node_modules/.bin/webpack /app/.npm/bin/webpack && \
    # Clean npm cache
    npm cache clean --force

# Copy application files
COPY --chown=1001:0 . .

# Ensure the build directory exists and is writable
RUN mkdir -p build && \
    chmod 775 build

# Add a basic webpack config if it doesn't exist
RUN if [ ! -f webpack.config.js ]; then \
    echo 'module.exports = { \
      mode: "production", \
      entry: "./src/index.js", \
      output: { \
        filename: "bundle.js", \
        path: __dirname + "/build", \
        library: "cytoscapeExplore", \
        libraryTarget: "umd" \
      }, \
      module: { \
        rules: [ \
          { \
            test: /\.js$/, \
            exclude: /node_modules/, \
            use: { \
              loader: "babel-loader", \
              options: { \
                presets: ["@babel/preset-env"] \
              } \
            } \
          }, \
          { \
            test: /\.css$/, \
            use: ["style-loader", "css-loader"] \
          } \
        ] \
      }, \
      externals: { \
        "cytoscape": "cytoscape" \
      } \
    }' > webpack.config.js; \
    fi

# Try building with verbose output and error handling
RUN set -x && \
    echo "PATH is: $PATH" && \
    echo "Webpack location: $(which webpack)" && \
    echo "Directory contents:" && ls -la && \
    echo "Running build..." && \
    npm run build --verbose || { \
        echo "Build failed. Package.json contents:"; \
        cat package.json; \
        echo "Node modules contents:"; \
        ls -la node_modules/.bin; \
        exit 1; \
    }

# Only remove devDependencies in production
RUN if [ "${NODE_ENV}" = "production" ]; then \
    npm prune --production; \
    fi

# Copy and set up entrypoint script
COPY --chown=1001:0 entrypoint.sh ./
RUN chmod 775 /app/entrypoint.sh

# Expose port for OpenShift
EXPOSE 8080

ENTRYPOINT ["./entrypoint.sh"]