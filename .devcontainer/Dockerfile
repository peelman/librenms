FROM php:8.4-cli-bookworm

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies (matching CI workflow)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    git \
    curl \
    zip \
    unzip \
    # PHP extensions dependencies
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libldap2-dev \
    libmemcached-dev \
    libsnmp-dev \
    # SNMP tools (for testing)
    snmp \
    snmp-mibs-downloader \
    # Database clients
    mariadb-client \
    sqlite3 \
    # Python for snmpsim and pylint
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    # Network tools for debugging
    iputils-ping \
    net-tools \
    dnsutils \
    # RRDtool
    rrdtool \
    librrd-dev \
    # Misc tools
    fping \
    graphviz \
    imagemagick \
    mtr-tiny \
    nmap \
    whois \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        bcmath \
        curl \
        gd \
        intl \
        ldap \
        mbstring \
        opcache \
        pcntl \
        pdo \
        pdo_mysql \
        posix \
        snmp \
        sockets \
        xml \
        zip

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Create non-root user (for dev container)
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Set up Python pip for user installs
RUN mkdir -p /home/$USERNAME/.local/bin \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME/.local

# Set user PATH
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Install global PHP tools for development
RUN composer global require --dev \
    "friendsofphp/php-cs-fixer" \
    "php-parallel-lint/php-parallel-lint" \
    && composer global config bin-dir /usr/local/bin \
    && composer global install

# Expose dev server port
EXPOSE 8000

# Switch to non-root user
USER $USERNAME
WORKDIR /workspaces/librenms
