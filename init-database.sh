#!/bin/bash
# Script para inicializar o banco de dados manualmente

MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-magnus123}
MYSQL_DATABASE=${MYSQL_DATABASE:-mbilling}
MYSQL_USER=${MYSQL_USER:-mbilling}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-mbilling123}

echo "Inicializando banco de dados MagnusBilling..."

# Iniciar MariaDB
/etc/init.d/mariadb start
sleep 5

# Criar banco
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'localhost';
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';
FLUSH PRIVILEGES;
EOF

# Importar schema se existir
if [ -f "/var/www/html/mbilling/protected/data/schema.sql" ]; then
    echo "Importando schema..."
    mysql -u root $MYSQL_DATABASE < /var/www/html/mbilling/protected/data/schema.sql
fi

echo "Banco de dados inicializado!"
echo "Database: $MYSQL_DATABASE"
echo "User: $MYSQL_USER"
echo "Password: $MYSQL_PASSWORD"
