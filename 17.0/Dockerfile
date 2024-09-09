# Use Ubuntu base image
FROM ubuntu:jammy
MAINTAINER Odoo S.A. <info@odoo.com>

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for PostgreSQL and general locale data
ENV LANG en_US.UTF-8

# Retrieve the target architecture to install the correct wkhtmltopdf package
ARG TARGETARCH

# Install dependencies including Nginx, PostgreSQL client, and other required packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        dirmngr \
        fonts-noto-cjk \
        libssl-dev \
        node-less \
        npm \
        python3-magic \
        python3-num2words \
        python3-odf \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        postgresql-client \
        nginx \
        xz-utils && \
    npm install -g rtlcss && \
    curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb \
    && apt-get install -y ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# Install Python dependencies via pip that are not available via apt
RUN pip3 install \
    werkzeug \
    xlsxwriter \
    zeep \
    freezegun

# Install Odoo
ENV ODOO_VERSION 17.0
ARG ODOO_RELEASE=20240904
ARG ODOO_SHA=9fd807d55facb850ead1ad86dc628e26961dfb20
RUN curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
    && echo "${ODOO_SHA} odoo.deb" | sha1sum -c - \
    && apt-get install -y ./odoo.deb \
    && rm odoo.deb

# Copy configuration files and entrypoint
COPY ./odoo.conf /etc/odoo/odoo.conf
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/wait-for-psql.py /entrypoint.sh

# Substitute environment variable in Nginx config
RUN envsubst '${SERVER_NAME}' < /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.tmp && \
    mv /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf

# Set permissions for Odoo and Nginx
RUN chown -R odoo /etc/odoo && \
    mkdir -p /mnt/extra-addons /var/log/nginx && \
    chown -R odoo /mnt/extra-addons /var/log/nginx

VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose necessary ports
EXPOSE 80 8069 8072

# Set default environment and user
ENV ODOO_RC /etc/odoo/odoo.conf
USER odoo

# Start services via entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
