#!/bin/bash
#
#
# http://bertvv.github.io/notes-to-self/2015/11/16/automating-mysql_secure_installation/
mysql_install(){
    step "Instalando MySQL"
        try yum -y localinstall https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
        try yum -y install mysql-community-server
    next

    step "Habilitando MySQL"
        try systemctl enable mysqld.service
        try systemctl start mysqld.service
    next

    # gera a senha para o usuário root do banco
    MYSQL_PASSWORD=$(date +%s | sha256sum | base64 | head -c 8 ; echo)
    MYSQL_PASSWORD="_M1*${MYSQL_PASSWORD}"

    # recupera a senha definida no momento da instalação
    MYSQL_CURRENT_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $11}')

    step "Redefinindo senha de root"
        try mysql -u root --password=${MYSQL_CURRENT_PASSWORD} -e "SET PASSWORD = PASSWORD('$MYSQL_PASSWORD')" --connect-expired-password;
    next

    # mysql_secure_installation.sql
    cat > .tmp/MYSQL_SECURE_INSTALL_SQL << EOF
        UPDATE mysql.user SET authentication_string=PASSWORD('$MYSQL_PASSWORD') WHERE User='root';
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        DROP DATABASE IF EXISTS test;
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
        FLUSH PRIVILEGES;
EOF

    step "Redefinindo permissões"
        try mysql -uroot -p"${MYSQL_PASSWORD}" < .tmp/MYSQL_SECURE_INSTALL_SQL --connect-expired-password
    next

    step "Removendo lixo"
        try unlink .tmp/MYSQL_SECURE_INSTALL_SQL
    next

    echo "$MYSQL_PASSWORD"
}