FROM ubuntu:jammy
MAINTAINER Odoo S.A. <info@odoo.com>

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG en_US.UTF-8

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
USER root
RUN set -e && \
    echo "Starting dependency installation as root..." && \
    apt-get update && \
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
        gettext-base \
        gosu && \
    echo "Downloading wkhtmltopdf..." && \
    curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb && \
    echo "Verifying wkhtmltopdf package..." && \
    echo "967390a759707337b46d1c02452e2bb6b2dc6d59 wkhtmltox.deb" | sha1sum -c - && \
    echo "Installing wkhtmltopdf..." && \
    apt-get install -y --no-install-recommends ./wkhtmltox.deb && \
    rm -rf /var/lib/apt/lists/* wkhtmltox.deb && \
    echo "Dependency installation completed successfully."

# install latest postgresql-client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

# Install rtlcss (on Debian buster)
RUN npm install -g rtlcss

# Install Odoo
ENV ODOO_VERSION 17.0
ARG ODOO_RELEASE=20240912
ARG ODOO_SHA=4456afb92e3235660c711160b1f457d31902c391
RUN curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
    && echo "${ODOO_SHA} odoo.deb" | sha1sum -c - \
    && apt-get update \
    && apt-get -y install --no-install-recommends ./odoo.deb \
    && rm -rf /var/lib/apt/lists/* odoo.deb

# Ensure Odoo command is executable and in PATH
RUN chmod +x /usr/bin/odoo && \
    ln -sf /usr/bin/odoo /usr/local/bin/odoo

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

# Ensure odoo user has necessary permissions
RUN mkdir -p /mnt/extra-addons && \
    chown -R odoo:odoo /etc/odoo && \
    chown -R odoo:odoo /var/lib/odoo && \
    chown -R odoo:odoo /mnt/extra-addons && \
    chmod -R 755 /mnt/extra-addons

# Add odoo command to odoo user's PATH
RUN echo 'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"' >> /etc/bash.bashrc

# Install Nginx (latest stable version)
RUN apt-get update && \
    apt-get install -y curl gnupg2 ca-certificates lsb-release && \
    echo "deb http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" \
    | tee /etc/apt/sources.list.d/nginx.list && \
    curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add - && \
    apt-get update && \
    apt-get install -y nginx && \
    rm -rf /var/lib/apt/lists/*

# Install gosu for easy step-down from root
RUN apt-get update && apt-get install -y gosu \
    && rm -rf /var/lib/apt/lists/*

# Copy Nginx configuration file
COPY ./nginx.conf /etc/nginx/nginx.conf

# Copy entrypoint script, Odoo configuration file, and wait-for-psql script
COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/
COPY ./wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Conditionally create custom-modules directory and copy modules if they exist
RUN if [ -d "./custom-modules" ] && [ "$(ls -A ./custom-modules 2>/dev/null)" ]; then \
        echo "Custom modules found. Creating directory and copying files..."; \
        mkdir -p /mnt/custom-modules && \
        cp -R ./custom-modules/* /mnt/custom-modules/ && \
        chown -R odoo:odoo /mnt/custom-modules && \
        chmod -R 755 /mnt/custom-modules; \
    else \
        echo "No custom modules found or directory is empty. Skipping creation."; \
    fi

# Update ADDONS_PATH in odoo.conf only if custom modules were copied
RUN if [ -d "/mnt/custom-modules" ] && [ "$(ls -A /mnt/custom-modules 2>/dev/null)" ]; then \
        echo "Updating ADDONS_PATH to include custom modules..."; \
        sed -i 's|addons_path = |addons_path = /mnt/custom-modules,|' /etc/odoo/odoo.conf; \
    else \
        echo "No custom modules found. ADDONS_PATH remains unchanged."; \
    fi

# Set permissions only if the directory was created
RUN if [ -d "/mnt/custom-modules" ]; then \
        chown -R odoo:odoo /mnt/custom-modules && \
        chmod -R 755 /mnt/custom-modules; \
    fi

# Set permissions and Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN chown odoo /etc/odoo/odoo.conf \
    && mkdir -p /mnt/extra-addons \
    && chown -R odoo /mnt/extra-addons \
    && if [ -d "/mnt/custom-modules" ]; then \
         chown -R odoo /mnt/custom-modules; \
       fi \
    && chmod +x /entrypoint.sh /usr/local/bin/wait-for-psql.py

VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose Odoo services
EXPOSE 8069 8071 8072

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

# Add logging for build process
RUN set -e && \
    echo "Build summary:" && \
    echo "Odoo version: $ODOO_VERSION" && \
    echo "Odoo release: $ODOO_RELEASE" && \
    echo "Odoo SHA: $ODOO_SHA" && \
    echo "Python version: $(python3 --version)" && \
    echo "$(nginx -v 2>&1)" && \
    echo "Build completed successfully."

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]

# Add a final log message
RUN echo "Dockerfile execution completed. Image is ready."
