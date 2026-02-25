# ============================================================
# MagnusBilling 7 + Asterisk 13 - Docker para EasyPanel
# ============================================================
# 
# PORTAS NECESSÁRIAS:
# - 80/443 (HTTP/HTTPS) - Interface web
# - 5060/udp (SIP) - Sinalização SIP
# - 5060/tcp (SIP) - Sinalização SIP (TCP)
# - 5038/tcp (AMI) - Asterisk Manager Interface
# - 10000-20000/udp (RTP) - Media/Áudio
# - 4569/udp (IAX2) - Inter-Asterisk Exchange (opcional)
#
# SERVIÇOS:
# - Apache2 + PHP 8.x
# - MariaDB (MySQL)
# - Asterisk 13
# - Fail2ban
# - Cron
#
# ============================================================

FROM debian:12-slim

LABEL maintainer="To-Ligado.com"
LABEL description="MagnusBilling 7 + Asterisk 13 - VoIP PBX System"

# Evitar prompts interativos
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Belem
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ============================================================
# DEPENDÊNCIAS DO SISTEMA
# ============================================================

RUN apt-get update && apt-get install -y \
    # Básicos
    locales \
    curl \
    wget \
    gnupg2 \
    ca-certificates \
    lsb-release \
    apt-transport-https \
    # Compilação (necessário para Asterisk)
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    git \
    subversion \
    # Apache + PHP
    apache2 \
    libapache2-mod-php \
    php \
    php-mysql \
    php-gd \
    php-curl \
    php-mbstring \
    php-xml \
    php-zip \
    php-intl \
    php-bcmath \
    # MariaDB
    mariadb-server \
    mariadb-client \
    # Asterisk dependencies
    libncurses5-dev \
    libncurses-dev \
    libjansson-dev \
    libxml2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libsqlite3-dev \
    sqlite3 \
    unixodbc \
    unixodbc-dev \
    odbcinst \
    libodbc1 \
    # Utilitários
    cron \
    rsyslog \
    fail2ban \
    supervisor \
    procps \
    htop \
    vim \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Locale
RUN sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ============================================================
# COMPILAR ASTERISK 13
# ============================================================

WORKDIR /usr/src

# Jansson (JSON library para Asterisk) - instalar via apt
RUN apt-get update && apt-get install -y libjansson-dev libjansson4 && \
    rm -rf /var/lib/apt/lists/*

# Asterisk 13 (LTS)
RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-13.38.3.tar.gz && \
    tar -xzf asterisk-13.38.3.tar.gz && \
    cd asterisk-13.38.3 && \
    # Criar usuário asterisk
    useradd -r -d /var/lib/asterisk -s /sbin/nologin asterisk || true && \
    # Configurar sem usar install_prereq (que precisa de aptitude)
    ./configure --with-jansson --with-pjproject-bundled && \
    # Compilar e instalar (sem menuselect interativo)
    make && make install && make samples && make config && \
    ldconfig && \
    cd .. && rm -rf asterisk-13.38.3*

# ============================================================
# CONFIGURAR ASTERISK
# ============================================================

RUN mkdir -p /var/run/asterisk /var/log/asterisk /var/spool/asterisk /var/lib/asterisk && \
    chown -R asterisk:asterisk /var/run/asterisk /var/log/asterisk /var/spool/asterisk /var/lib/asterisk /etc/asterisk

# Asterisk Manager Interface (AMI) config
RUN echo '[general]\n\
enabled = yes\n\
bindaddr = 0.0.0.0\n\
port = 5038\n\
\n\
[magnus]\n\
secret = magnus123\n\
deny = 0.0.0.0/0.0.0.0\n\
permit = 127.0.0.1/255.255.255.0\n\
permit = 10.0.0.0/255.0.0.0\n\
permit = 172.16.0.0/255.240.0.0\n\
permit = 192.168.0.0/255.255.0.0\n\
read = system,call,log,verbose,agent,user,config,dtmf,reporting,cdr,dialplan\n\
write = system,call,agent,user,config,command,reporting,originate' > /etc/asterisk/manager.conf

# SIP config básico
RUN echo '[general]\n\
context = default\n\
bindaddr = 0.0.0.0\n\
bindport = 5060\n\
udpbindaddr = 0.0.0.0\n\
transport = udp\n\
\n\
[default]\n\
context = default' > /etc/asterisk/sip.conf

# RTP config (range de portas para áudio)
RUN echo '[general]\n\
rtpstart=10000\n\
rtpend=20000' > /etc/asterisk/rtp.conf

# Extensions básico
RUN echo '[default]\n\
exten => s,1,Answer()\n\
exten => s,n,Wait(1)\n\
exten => s,n,Playback(demo-congrats)\n\
exten => s,n,Hangup()' > /etc/asterisk/extensions.conf

# ============================================================
# MAGNUSBILLING
# ============================================================

WORKDIR /var/www/html

# Baixar MagnusBilling
RUN wget --no-check-certificate https://magnusbilling.org/download/MagnusBilling-current.tar.gz -O mb.tar.gz && \
    tar -xzf mb.tar.gz && \
    rm mb.tar.gz && \
    mv MagnusBilling-* mbilling 2>/dev/null || true && \
    # Se o tar não tiver subpasta
    [ -d "mbilling" ] || mkdir -p mbilling && \
    chown -R www-data:www-data mbilling && \
    chmod -R 755 mbilling

# Criar diretórios necessários
RUN mkdir -p /var/www/html/mbilling/protected/runtime \
             /var/www/html/mbilling/assets \
             /var/www/html/mbilling/tmp \
             /var/www/html/mbilling/resources/reports \
             /var/www/html/mbilling/resources/images && \
    chown -R www-data:www-data /var/www/html/mbilling/protected/runtime \
                                /var/www/html/mbilling/assets \
                                /var/www/html/mbilling/tmp \
                                /var/www/html/mbilling/resources/reports \
                                /var/www/html/mbilling/resources/images

# ============================================================
# APACHE CONFIG
# ============================================================

RUN a2enmod rewrite headers expires

# VirtualHost
RUN echo '<VirtualHost *:80>\n\
    ServerAdmin admin@localhost\n\
    DocumentRoot /var/www/html/mbilling\n\
    <Directory /var/www/html/mbilling>\n\
        Options Indexes FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    ErrorLog ${APACHE_LOG_DIR}/error.log\n\
    CustomLog ${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>' > /etc/apache2/sites-available/mbilling.conf && \
    a2dissite 000-default && \
    a2ensite mbilling

# PHP config
RUN sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 20M/' /etc/php/*/apache2/php.ini && \
    sed -i 's/post_max_size = 8M/post_max_size = 50M/' /etc/php/*/apache2/php.ini && \
    sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/*/apache2/php.ini && \
    sed -i 's/memory_limit = 128M/memory_limit = 512M/' /etc/php/*/apache2/php.ini

# ============================================================
# SUPERVISOR (Gerencia todos os serviços)
# ============================================================

RUN mkdir -p /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# ============================================================
# SCRIPTS DE INICIALIZAÇÃO
# ============================================================

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# ============================================================
# SCRIPT DE INSTALAÇÃO DO BANCO
# ============================================================

COPY init-database.sh /init-database.sh
RUN chmod +x /init-database.sh

# ============================================================
# PORTAS
# ============================================================

# HTTP
EXPOSE 80 443

# SIP (UDP e TCP)
EXPOSE 5060/udp 5060/tcp

# AMI (Asterisk Manager)
EXPOSE 5038/tcp

# IAX2 (opcional)
EXPOSE 4569/udp

# RTP (Áudio) - Range grande
EXPOSE 10000-20000/udp

# ============================================================
# VOLUMES (para persistência)
# ============================================================

VOLUME ["/var/lib/mysql", "/var/www/html/mbilling/protected/runtime", "/var/log/asterisk", "/etc/asterisk"]

# ============================================================
# HEALTHCHECK
# ============================================================

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# ============================================================
# ENTRYPOINT
# ============================================================

WORKDIR /var/www/html/mbilling

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
