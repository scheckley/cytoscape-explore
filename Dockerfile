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

# Configure npm to use the user's .npm directory
ENV NPM_CONFIG_CACHE=/home/appuser/.npm

# Switch to unprivileged user and install dependencies
USER appuser
RUN npm ci --no-optional

# Expose the application port
EXPOSE 3000

# Copy entrypoint script
COPY entrypoint.sh /

# Start the application
CMD ["/entrypoint.sh"]
