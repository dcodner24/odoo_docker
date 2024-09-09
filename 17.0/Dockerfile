# Use Ubuntu base image
FROM ubuntu:jammy

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Install dependencies including Nginx and PostgreSQL client
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        nginx \
        python3-pip \
        postgresql-client && \
    rm -rf /var/lib/apt/lists/*

# Set up wkhtmltopdf and Odoo installation (same as before)
ENV ODOO_VERSION 17.0
RUN curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.20240826_all.deb \
    && apt-get install -y ./odoo.deb \
    && rm odoo.deb

# Copy custom config files
COPY ./odoo.conf /etc/odoo/odoo.conf
COPY ./nginx.conf /etc/nginx/nginx.conf

# Replace the server name in Nginx with an environment variable
RUN envsubst '${SERVER_NAME}' < /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp && mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf

# Expose necessary ports
EXPOSE 80 8069 8072

# Copy the wait-for-psql script and set user permissions
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py
RUN chmod +x /usr/local/bin/wait-for-psql.py

# Entrypoint script
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Command to run Odoo
CMD ["odoo"]
