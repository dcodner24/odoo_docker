# Use Ubuntu base image
FROM ubuntu:jammy

MAINTAINER Odoo S.A. <info@odoo.com>

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for Postgres and general locale data
ENV LANG en_US.UTF-8

# Install dependencies, including Nginx, Odoo, and wkhtmltopdf
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
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
        xz-utils \
        nginx && \
    apt-get install -y postgresql-client

# Install wkhtmltopdf
ARG TARGETARCH
RUN case ${TARGETARCH} in \
    "amd64") WKHTMLTOPDF_ARCH=amd64 ;; \
    "arm64") WKHTMLTOPDF_ARCH=arm64 ;; \
    "ppc64le" | "ppc64el") WKHTMLTOPDF_ARCH=ppc64el ;; \
    esac && \
    curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${WKHTMLTOPDF_ARCH}.deb && \
    apt-get install -y ./wkhtmltox.deb && \
    rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# Install Odoo
ENV ODOO_VERSION 17.0
RUN curl -o odoo.deb -sSL http://nightly.odoo.com/17.0/nightly/deb/odoo_17.0-20240826_all.deb && \
    apt-get install -y ./odoo.deb && \
    rm -rf /var/lib/apt/lists/* odoo.deb

# Create directories for custom modules
RUN mkdir -p /mnt/custom-modules /mnt/extra-addons

# Copy entrypoint, Odoo config, and Nginx config
COPY ./entrypoint.sh /
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./odoo.conf /etc/odoo/

# Set permissions
RUN chown -R odoo /mnt/custom-modules /mnt/extra-addons /etc/nginx /var/lib/nginx /var/log/nginx /etc/odoo

# Expose necessary ports
EXPOSE 80 8069 8072

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

# Start Odoo and Nginx
ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
