FROM netboxcommunity/netbox:latest

# Metadata
LABEL maintainer="rgomez@presidio.com"
LABEL description="Custom NetBox image with plugins"

# Switch to root for installations
USER root

# Install system dependencies if needed
# RUN apt-get update && \
#     apt-get install -y --no-install-recommends \
#     your-package-here && \
#     rm -rf /var/lib/apt/lists/*

# Copy plugin requirements
COPY plugins-example/requirements.txt /tmp/plugin-requirements.txt

# Install plugin requirements using uv (used by netbox-docker image)
RUN /usr/local/bin/uv pip install --no-cache-dir -r /tmp/plugin-requirements.txt

# Copy custom plugins (if developing locally)
# COPY plugins-example/my_plugin /opt/netbox/netbox/plugins/my_plugin

# Copy any custom configuration or scripts
# COPY scripts/ /opt/netbox/scripts/

# Switch back to netbox user
USER netbox

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/api/ || exit 1

# The base image already has the correct ENTRYPOINT and CMD
# ENTRYPOINT ["/opt/netbox/docker-entrypoint.sh"]
# CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "3", "netbox.wsgi"]
