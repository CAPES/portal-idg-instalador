#!/bin/bash
# set -o errexit # abort on nonzero exitstatus
# set -o nounset # abort on unbound variable

WORKSPACE=$(dirname $(readlink -f $0))

source ${WORKSPACE}/lib/try.sh
source ${WORKSPACE}/lib/next.sh
source ${WORKSPACE}/lib/step.sh
source ${WORKSPACE}/lib/print_usage.sh
source ${WORKSPACE}/lib/echo_passed.sh
source ${WORKSPACE}/lib/echo_failure.sh
source ${WORKSPACE}/lib/echo_success.sh
source ${WORKSPACE}/lib/echo_warning.sh
source ${WORKSPACE}/lib/linux_sudo_required.sh
source ${WORKSPACE}/lib/linux_deps_required.sh
source ${WORKSPACE}/lib/mysql/mysql_install.sh

# verifise o usuário tem permissão roots
linux_sudo_required
# linux_deps_required

# argumentos insuficientes
echo
if [ $# -lt 1 ]; then
    print_usage
    exit 1
fi

# area de variaveis
PORTAL_DOMAIN=$1
MYSQL_PASSWORD=

PORTAL_DATABASE_NAME=
PORTAL_LOG_DIR=

NGINX_USER=
NGINX_CONF_DIR=
NGINX_LOG_DIR="/var/log/nginx"
NGINX_HTDOCS_DIR="/usr/share/nginx/html"

# local que será recuperado os arquivos do portal CAPES
CAPES_GITHUB_JOOMLA_IDG2='https://github.com/CAPES/portal-idg2.git'

step "Instalando firewall"
    try yum -y install firewalld > /dev/null 2>&1
next

step "Habilitando firewalld..."
    try systemctl enable firewalld > /dev/null 2>&1
    try systemctl start firewalld  > /dev/null 2>&1
next

step  "Adicionando regras ao firewalld para liberar acesso ao servidor web"
    try firewall-cmd --permanent --zone=public --add-service=http   > /dev/null 2>&1
    try firewall-cmd --permanent --zone=public --add-service=https  > /dev/null 2>&1
    try firewall-cmd --reload                                       > /dev/null 2>&1
next

if [! -f "$file" ]; then
    step "Adicionando repositório oficial Nginx a sua lista de repositório"
    try cp ${WORKSPACE}/nginx/nginx.repo /etc/yum.repos.d/  > /dev/null 2>&1
fi

step "Instalando repositório remi para instalar PHP 7.2"
    try yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm > /dev/null 2>&1
    try yum-config-manager --enable remi-php72 > /dev/null 2>&1
next

step "Instalando NGINX"
    try yum install -y nginx > /dev/null 2>&1

    NGINX_USER=$(cat $(find /etc | grep nginx.conf$) | egrep '^(user)'  | rev | cut -d" " -f1 | cut -d";" -f2 | rev)
    NGINX_CONF_DIR=$(dirname $(cat $(find /etc | grep nginx.conf$) | egrep '(conf\.d/\*\.conf;)$' | rev | cut -d' ' -f1 | rev))

    if [ ! -d "$NGINX_LOG_DIR" ] ; then
        try mkdir -p "$NGINX_LOG_DIR";
        try chown $NGINX_USER:$NGINX_USER $NGINX_LOG_DIR;
    fi

    if [ ! -d "${NGINX_HTDOCS_DIR}" ] ; then
        try mkdir -p "$NGINX_HTDOCS_DIR";
        try chown $NGINX_USER:$NGINX_USER $NGINX_HTDOCS_DIR;
    fi
next

step "Instalando PHP 7.2"
    try yum install -y php-fpm php-common php-pecl-zip php-gd php-intl php-mbstring php-pdo php-pecl-imagick php-pecl-memcache php-soap php-opcache php-xml php-mysqlnd php-pecl-mysql
next

step "instalando Banco de dados"
    MYSQL_PASSWORD=$(mysql_install)
next

step "Configurando o PHP-FPM para o Nginx"
    # recupera localizacao do arquivo de conf do php-fpm
    PHPFPM_CONF_FILE=$(find /etc | grep \/www.conf$)

    # recupera o usuário e grupo que executa o serviço web
    WWW_CURRENT_USER=$(cat $PHPFPM_CONF_FILE  | egrep '^(user)'  | awk '{print $3}')
    WWW_CURRENT_GROUP=$(cat $PHPFPM_CONF_FILE | egrep '^(group)' | awk '{print $3}')

    try sed -i "s/^user = ${WWW_CURRENT_USER}/user = ${NGINX_USER}/g"    $WWW_CONF_FILE     > /dev/null 2>&1
    try sed -i "s/^group = ${WWW_CURRENT_GROUP}/group = ${NGINX_USER}/g" $WWW_CONF_FILE     > /dev/null 2>&1
next

step "Configurando o NGINX para utilizar o PHP-FPM"
    try cp ${WORKSPACE}/nginx/portal.conf $NGINX_CONF_DIR > /dev/null 2>&1
    try sed -i "s/__PORTAL_DOMAIN__/${PORTAL_DOMAIN}/g" ${NGINX_CONF_DIR}/portal.conf
next

step "Baixando portal portal do repositório github/CAPES"
    try git clone "${CAPES_GITHUB_JOOMLA_IDG2}" > /dev/null 2>&1
next

step "Configurando VHOST para ${PORTAL_DOMAIN}"
    try cp ${WORKSPACE}/nginx/portal.conf $NGINX_CONF_DIR > /dev/null 2>&1
    try sed -i "s/__PORTAL_DOMAIN__/${PORTAL_DOMAIN}/g" ${NGINX_CONF_DIR}/portal.conf
next

PORTAL_DOMAIN

step "Distribuindo arquivos do IDG2 para pasta destino"
    try unzip "${WORKSPACE}/portal-idg2/portal/portalcapes-idg2019.zip" -d "$NGINX_HTDOCS_DIR/${PORTAL_DOMAIN}"
    try sed -i "s/__PORTAL_DOMAIN__/${PORTAL_DOMAIN}/g" ${NGINX_CONF_DIR}/portal.conf
next

step "Ajustando permissão"
    try chown -R "$NGINX_USER:$NGINX_USER" "$NGINX_HTDOCS_DIR/${PORTAL_DOMAIN}"
next

step "Restaurando o banco de dados"
    try unzip -o "${WORKSPACE}/portal-idg2/database/portalcapes-idg2019.zip" -d "./.tmp"
    PORTAL_DATABASE_NAME=$(egrep '^(-- Host:\s*localhost\s*Database:)' "${WORKSPACE}/.tmp/portalcapes-idg2019.sql" | awk '{print $5}')

    # use database
    try sed -i "1s/^/use $PORTAL_DATABASE_NAME;\r/" "${WORKSPACE}/.tmp/portalcapes-idg2019.sql"
    try sed -i "1s/^/CREATE DATABASE IF NOT EXISTS $PORTAL_DATABASE_NAME;\r/" "${WORKSPACE}/.tmp/portalcapes-idg2019.sql"
    try sed -e "s/^M/\n/g" "${WORKSPACE}/.tmp/portalcapes-idg2019.sql" > .tmp/portalcapes-idg2019
    try unlink .tmp/portalcapes-idg2019
    try unlink .tmp/portalcapes-idg2019.sql

    try mysql -uroot -p"${MYSQL_PASSWORD}" < "${WORKSPACE}/.tmp/portalcapes-idg2019" --connect-expired-password
next

# step "Configurando acesso a banco de dados"
# next


# step "Configurando Joomla!"
#     public $password = '';
#     public $host = 'localhost';
#     public $db = 'portalcapes_idg2019';
#     public $log_path = '/var/www/html/portal/logs';
#     public $tmp_path = '/var/www/html/portal/tmp';
# next

exit 0