# Use Ubuntu base image
FROM ubuntu:jammy
MAINTAINER Odoo S.A. <info@odoo.com>

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale and install dependencies, including Nginx, wget, and PostgreSQL client
ENV LANG en_US.UTF-8
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl dirmngr fonts-noto-cjk gnupg \
        libssl-dev node-less npm python3-pip postgresql-client nginx \
        xz-utils wget && apt-get clean

# Install wkhtmltopdf
ARG TARGETARCH
RUN curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${TARGETARCH}.deb && \
    apt-get install -y ./wkhtmltox.deb && rm wkhtmltox.deb

# Add Odoo repository and install Odoo
RUN wget -O /etc/apt/trusted.gpg.d/odoo.gpg https://nightly.odoo.com/odoo.key && \
    echo "deb http://nightly.odoo.com/17.0/nightly/deb/ ./" > /etc/apt/sources.list.d/odoo.list && \
    apt-get update && \
    apt-get install -y odoo

# Set up custom directories
RUN mkdir -p /mnt/custom-modules /mnt/extra-addons && chown -R odoo /mnt/custom-modules /mnt/extra-addons

# Copy configuration files and entrypoint script
COPY ./entrypoint.sh /
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./odoo.conf /etc/odoo/odoo.conf
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Set permissions and volumes
RUN chown odoo /etc/odoo/odoo.conf && \
    echo "\naddons_path = /mnt/custom-modules,/mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons" >> /etc/odoo/odoo.conf

VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose necessary ports
EXPOSE 80 8069 8071 8072

# Set the default user and Odoo configuration file
USER odoo
ENV ODOO_RC /etc/odoo/odoo.conf

# Entrypoint and CMD
ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
