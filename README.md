# Instalar CAPES Portal Joomla! IDG2

# Recomenda-se que se use um servidor dedicado para esse processo.
## Caso use um servidor compartilhado com outros serviços, faça backup da aplicação e do banco antes de proceguir.

Para realizar a instalação execute

`
 $ sudo chmod +x install.sh
 $ sudo install.sh www.dominio-portal.gov.br
`
Será instalando um servidor de banco de dados MySQL, cuja senha será conhecda apenas pelo Joomla!

yum remove -y mysql-community-server && > /var/log/mysqld.log && rm -rf /var/lib/mysql && rm -rf /usr/share/nginx/html/www.domain.com.br && rm -rf /etc/nginx/conf.d/portal.conf && rm -rf ./.tmp