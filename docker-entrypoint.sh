#!/bin/bash
set -e

echo "============================================================"
echo "  MagnusBilling 7 + Asterisk 13 - Docker Container"
echo "============================================================"
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================
# CONFIGURAR TIMEZONE
# ============================================================

if [ -n "$TZ" ]; then
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
    log_info "Timezone configurado: $TZ"
fi

# ============================================================
# INICIALIZAR MARIADB
# ============================================================

log_info "Inicializando MariaDB..."

# Criar diretórios do MySQL
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

# Iniciar MariaDB temporariamente para configurar
/etc/init.d/mariadb start

# Aguardar MySQL iniciar
sleep 5

# Configurar banco de dados se não existir
if [ ! -d "/var/lib/mysql/mbilling" ]; then
    log_info "Criando banco de dados MagnusBilling..."
    
    # Senha root do MySQL
    MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-magnus123}
    MYSQL_DATABASE=${MYSQL_DATABASE:-mbilling}
    MYSQL_USER=${MYSQL_USER:-mbilling}
    MYSQL_PASSWORD=${MYSQL_PASSWORD:-mbilling123}
    
    # Criar banco e usuário
    mysql -u root <<EOF
-- Criar banco
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Criar usuário
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'localhost';
FLUSH PRIVILEGES;

-- Criar usuário para conexões externas (se necessário)
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';
FLUSH PRIVILEGES;
EOF
    
    log_info "Banco de dados criado: $MYSQL_DATABASE"
    
    # Importar schema do MagnusBilling se existir
    if [ -f "/var/www/html/mbilling/protected/data/schema.sql" ]; then
        log_info "Importando schema do MagnusBilling..."
        mysql -u root $MYSQL_DATABASE < /var/www/html/mbilling/protected/data/schema.sql
    fi
    
    # Criar usuário admin padrão
    if [ -f "/var/www/html/mbilling/protected/data/initial_data.sql" ]; then
        log_info "Importando dados iniciais..."
        mysql -u root $MYSQL_DATABASE < /var/www/html/mbilling/protected/data/initial_data.sql
    fi
fi

# Parar MariaDB (será gerenciado pelo supervisor)
/etc/init.d/mariadb stop

# ============================================================
# CONFIGURAR ASTERISK
# ============================================================

log_info "Configurando Asterisk..."

# Criar diretórios
mkdir -p /var/run/asterisk /var/log/asterisk /var/spool/asterisk
chown -R asterisk:asterisk /var/run/asterisk /var/log/asterisk /var/spool/asterisk /etc/asterisk

# Configurar manager.conf com senha customizada
AMI_PASSWORD=${AMI_PASSWORD:-magnus123}
cat > /etc/asterisk/manager.conf <<EOF
[general]
enabled = yes
bindaddr = 0.0.0.0
port = 5038

[magnus]
secret = $AMI_PASSWORD
deny = 0.0.0.0/0.0.0.0
permit = 127.0.0.1/255.255.255.0
permit = 10.0.0.0/255.0.0.0
permit = 172.16.0.0/255.240.0.0
permit = 192.168.0.0/255.255.0.0
read = system,call,log,verbose,agent,user,config,dtmf,reporting,cdr,dialplan
write = system,call,agent,user,config,command,reporting,originate
EOF

log_info "Asterisk AMI configurado na porta 5038"

# ============================================================
# CONFIGURAR MAGNUSBILLING
# ============================================================

log_info "Configurando MagnusBilling..."

# Arquivo de configuração do banco
if [ -f "/var/www/html/mbilling/protected/config/main.php" ]; then
    # Atualizar configuração do banco
    sed -i "s/'connectionString' => 'mysql:host=localhost;dbname=mbilling'/'connectionString' => 'mysql:host=localhost;dbname=$MYSQL_DATABASE'/" /var/www/html/mbilling/protected/config/main.php
    sed -i "s/'username' => 'root'/'username' => '$MYSQL_USER'/" /var/www/html/mbilling/protected/config/main.php
    sed -i "s/'password' => ''/'password' => '$MYSQL_PASSWORD'/" /var/www/html/mbilling/protected/config/main.php
    
    log_info "Configuração do banco aplicada"
fi

# Permissões
chown -R www-data:www-data /var/www/html/mbilling/protected/runtime
chown -R www-data:www-data /var/www/html/mbilling/assets
chown -R www-data:www-data /var/www/html/mbilling/tmp
chown -R www-data:www-data /var/www/html/mbilling/resources/reports
chown -R www-data:www-data /var/www/html/mbilling/resources/images

chmod -R 775 /var/www/html/mbilling/protected/runtime
chmod -R 775 /var/www/html/mbilling/assets

# Permissões do Asterisk para mbilling
chown -R asterisk:asterisk /var/www/html/mbilling/resources/asterisk 2>/dev/null || true
chmod +x /var/www/html/mbilling/resources/asterisk/mbilling.php 2>/dev/null || true

log_info "Permissões configuradas"

# ============================================================
# CONFIGURAR CRON
# ============================================================

log_info "Configurando cron jobs..."

# Cron jobs do MagnusBilling
cat > /etc/cron.d/magnusbilling <<EOF
* * * * * www-data php /var/www/html/mbilling/cron.php TrunkSIPCodes >> /var/log/magnusbilling-cron.log 2>&1
* * * * * www-data php /var/www/html/mbilling/cron.php CheckReminders >> /var/log/magnusbilling-cron.log 2>&1
* * * * * www-data php /var/www/html/mbilling/cron.php CheckRecurring >> /var/log/magnusbilling-cron.log 2>&1
0 0 * * * www-data php /var/www/html/mbilling/cron.php CleanUp >> /var/log/magnusbilling-cron.log 2>&1
EOF

chmod 644 /etc/cron.d/magnusbilling

log_info "Cron jobs configurados"

# ============================================================
# INFORMAÇÕES DE ACESSO
# ============================================================

echo ""
echo "============================================================"
echo "  MagnusBilling está pronto!"
echo "============================================================"
echo ""
echo "  Acesso Web: http://localhost/"
echo "  Usuário: root"
echo "  Senha: magnus"
echo ""
echo "  MySQL:"
echo "    Banco: ${MYSQL_DATABASE:-mbilling}"
echo "    Usuário: ${MYSQL_USER:-mbilling}"
echo "    Senha: ${MYSQL_PASSWORD:-mbilling123}"
echo ""
echo "  Asterisk AMI:"
echo "    Porta: 5038"
echo "    Usuário: magnus"
echo "    Senha: ${AMI_PASSWORD:-magnus123}"
echo ""
echo "============================================================"
echo ""

# ============================================================
# EXECUTAR COMANDO PRINCIPAL
# ============================================================

exec "$@"
