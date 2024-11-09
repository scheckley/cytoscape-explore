# Use a Node 14 image
FROM node:14.18.3

# Set build-time argument for environment configuration
ARG NODE_ENV
ENV NODE_ENV ${NODE_ENV:-production}

# Create and set up an unprivileged user and app directory
RUN useradd -m -s /bin/bash appuser \
    && mkdir -p /home/appuser/app

# Switch to app directory
WORKDIR /home/appuser/app

# Copy application source code to app directory
COPY . .

# Install dependencies
RUN npm ci

# Set up permissions for OpenShift
RUN chown -R appuser:appuser /home/appuser/app

# Set unprivileged user
USER appuser

# Expose the application port
EXPOSE 3000

# Copy entrypoint script
COPY entrypoint.sh /

# Start the application
CMD ["/entrypoint.sh"]

