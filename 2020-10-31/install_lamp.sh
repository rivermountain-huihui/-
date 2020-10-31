#!/bin/bash
#
#
#Author:	lvzhehui
#QQ:		734709865
#Date:		2020-10-31
#FileName:	install_lamp.sh
#Descripting:	Install LAMP
#Copyright (C):	2020 All rights reserved
#引用action函数
. /etc/init.d/functions

#定义全局变量

#定义软件的压缩包名称
APR=apr-1.7.0.tar.gz
APR_UTIL=apr-util-1.6.1.tar.gz
HTTPD=httpd-2.4.46.tar.bz2
MYSQLD=mariadb-10.5.5-linux-x86_64.tar.gz
PHP=php-7.4.7.tar.bz2
WORDPRESS=wordpress-5.4.2-zh_CN.tar.gz
DISCUZ=Discuz_X3.4_SC_UTF8【20191201】.zip
#取出.tar前的字符
FILENAME_HTTPD=${HTTPD%.tar*}
FILENAME_APR=${APR%.tar*}
FILENAME_APR_UTIL=${APR_UTIL%.tar*}
FILENAME_MYSQLD=${MYSQLD%.tar*}
FILENAME_PHP=${PHP%.tar*}
#定义下载目录和安装目录
DOWNLOAD_DIR=/usr/local/src
INSTALL_HTTPD_DIR=/apps/httpd
INSTALL_MYSQLD_DIR=/apps/mysqld
MYSQLD_DATA_DIR=/data/mysql
INSTALL_PHP_DIR=/apps/php
#定义数据库密码
PASSWORD='centos'
#定义WordPress和Discuz的安装目录，同时也是两个网站的根目录
INSTALL_WORDPRESS_DIR=/data/wordpress
INSTALL_DISCUZ_DIR=/data/discuz


#定义函数
function check_env() {
    echo "开始运行脚本"
    echo "执行第一步：检查安装环境"
    if [ $UID -ne 0 ];then
        action "当前用户不是root，请更换为root用户执行脚本，脚本退出." false
        exit 3
    fi
    for i in {"apache","mysql"};do
        id ${i} &>/dev/null
        if [ $? -eq 0  ];then
            action "当前系统中已经存在用户：${i}，请检查环境，脚本退出." false 
            exit 3
        fi
    done
    if [ -d ${INSTALL_HTTPD_DIR} ];then
        action "${INSTALL_HTTPD_DIR}已存在，脚本退出" false
        exit 3
    fi
    if [ -d ${INSTALL_MYSQLD_DIR} ];then
        action "${INSTALL_MYSQLD_DIR}已存在，脚本退出" false
        exit 3
    fi
    if [ -d ${MYSQLD_DATA_DIR} ];then
        action "${MYSQLD_DATA_DIR}已存在，脚本退出" false
        exit 3
    fi
    if [ -d ${INSTALL_PHP_DIR} ];then
        action "${INSTALL_PHP_DIR}已存在，脚本退出" false
        exit 3
    fi
    if [ ! -f ${DOWNLOAD_DIR}/${APR} ];then
        action "请把${APR}文件放到${DOWNLOAD_DIR}目录下后再重新执行脚本！" false
        exit 3
    fi
    if [ ! -f ${DOWNLOAD_DIR}/${APR_UTIL} ];then
        action "请把${APR_UTIL}文件放到${DOWNLOAD_DIR}目录下后再重新执行脚本！" false
        exit 3
    fi
    if [ ! -f ${DOWNLOAD_DIR}/${HTTPD} ];then
        action "请把${HTTPD}文件放到${DOWNLOAD_DIR}目录下后再重新执行脚本！" false
        exit 3
    fi
    if [ ! -f ${DOWNLOAD_DIR}/${MYSQLD} ];then
        action "请把${MYSQLD}文件放到${DOWNLOAD_DIR}目录下后再重新执行脚本！" false
        exit 3
    fi
    if [ ! -f ${DOWNLOAD_DIR}/${PHP} ];then
        action "请把${PHP}文件放到${DOWNLOAD_DIR}目录下后再重新执行脚本！" false
        exit 3
    fi
    action "环境检查通过，开始进行LAMP的安装"
}


function install_wordpress() {
    echo "开始安装Wordpress"
    cd ${DOWNLOAD_DIR}
    mkdir -p /data/{wordpress,discuz}/logs
    tar xf ${WORDPRESS} -C ${INSTALL_WORDPRESS_DIR%\/word*}
    action "Wordpress安装完成"
}


function install_discuz() {
    echo "开始安装Discuz"
    cd ${DOWNLOAD_DIR}
    unzip ${DISCUZ} &>/dev/null 
    cp -r DiscuzX/upload/* ${INSTALL_DISCUZ_DIR}/
    action "Discuz安装完成"
}

function install_httpd() {
    echo "开始编译安装HTTPD"
    echo "..."
    yum -y install install gcc make pcre-devel openssl-devel expat-devel bzip2 &>/dev/null \
    && action "依赖包安装完成!" || { action  "安装依赖包失败" false ;exit 3; } 
    mkdir -p /apps/httpd
    useradd -r -s /sbin/nologin -d /apps/httpd -M -U -u 80 apache
    cd ${DOWNLOAD_DIR}
    tar xf ${HTTPD} 
    tar xf ${APR} 
    tar xf ${APR_UTIL} 
    mv ${FILENAME_APR} ${FILENAME_APR_UTIL} ${FILENAME_HTTPD}/srclib/
    mv ${FILENAME_HTTPD}/srclib/${FILENAME_APR} ${FILENAME_HTTPD}/srclib/apr
    mv ${FILENAME_HTTPD}/srclib/${FILENAME_APR_UTIL} ${FILENAME_HTTPD}/srclib/apr-util
    cd ${FILENAME_HTTPD}
    #开始编译环节
    ./configure \
    --prefix=${INSTALL_HTTPD_DIR} \
    --enable-so \
    --enable-ssl \
    --enable-cgi \
    --enable-rewrite \
    --with-zlib \
    --with-pcre \
    --with-included-apr \
    --enable-modules=most \
    --enable-mpms-shared=all \
    --with-mpm=event &>/dev/null
    if [ $? -eq 0 ];then
        action "Configuration successful!"
    else
        action "Configuration false,please check ./configure options" false 
        exit 3
    fi
    TIME_1=`date +%s`
    make -j `lscpu | awk 'NR==4{print $2}'` &>/dev/null && make install &>/dev/null
    if [ $? -eq 0 ];then
        action "Making Progress Finished"
        TIME_2=`date +%s`
        TIME_USED=$(( TIME_2 - TIME_1 ))
    else
        action false "Making Progress false"
        exit 3
    fi
    #编译完成，开始修改配置文件 
    sed -i.bak -e 's/^User daemon/User apache/' \
        -e 's/^Group daemon/Group apache/' \
        -e 's/^#LoadModule proxy_module modules\/mod_proxy\.so/LoadModule proxy_module modules\/mod_proxy\.so/' \
        -e 's/^#LoadModule proxy_fcgi_module modules\/mod_proxy_fcgi\.so/LoadModule proxy_fcgi_module modules\/mod_proxy_fcgi\.so/' \
        -e 's/  DirectoryIndex index\.html/    DirectoryIndex index\.php/' \
        ${INSTALL_HTTPD_DIR}/conf/httpd.conf
    cat>>${INSTALL_HTTPD_DIR}/conf/httpd.conf<<EOF
<virtualhost *:80>
servername blog.lv.dota
documentroot /data/wordpress
<directory /data/wordpress>
require all granted
</directory>
ProxyPassMatch ^/(.*\.php)$ fcgi://127.0.0.1:9000${INSTALL_WORDPRESS_DIR}/\$1
ProxyPassMatch ^/(fpm_status|ping)$ fcgi://127.0.0.1:9000/\$1
Customlog "logs/access_wordpress_log" common
Errorlog "logs/error_wordpress_log"
</virtualhost>

<virtualhost *:80>
servername forum.lv.dota
documentroot /data/discuz
<directory /data/discuz>
require all granted
</directory>
ProxyPassMatch ^/(.*\.php)$ fcgi://127.0.0.1:9000${INSTALL_DISCUZ_DIR}/\$1
ProxyPassMatch ^/(fpm_status|ping)$ fcgi://127.0.0.1:9000/\$1
Customlog "logs/access_discuz_log" common
Errorlog "logs/error_discuz_log"
</virtualhost>
EOF
    cat>/etc/profile.d/httpd.sh<<EOF
PATH=${INSTALL_HTTPD_DIR}/bin:\$PATH
EOF
    source /etc/profile.d/httpd.sh
    echo "MANDATORY_MANPATH       ${INSTALL_HTTPD_DIR}/man" >> /etc/man_db.conf
    #生成service文件
    cat>/lib/systemd/system/httpd.service<<EOF
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=forking
ExecStart=${INSTALL_HTTPD_DIR}/bin/apachectl -k start
ExecReload=${INSTALL_HTTPD_DIR}/httpd/bin/apachectl -k graceful
ExecStop=${INSTALL_HTTPD_DIR}/bin/apachectl -k stop
KillSignal=SIGCONT                                                                      
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    chown -R apache.apache ${INSTALL_HTTPD_DIR}
    chown -R apache.apache ${INSTALL_WORDPRESS_DIR}
    chown -R apache.apache ${INSTALL_DISCUZ_DIR}
    systemctl daemon-reload
    systemctl enable --now httpd.service &>/dev/null
    if [ $? -eq 0 ];then
        action "httpd服务启动成功！"
    else
        action "httpd服务启动失败" false 
    fi
    echo "Apache编译用时：${TIME_USED}s"
}



function install_mariadb() {
    echo "开始安装数据库"
    cd ${DOWNLOAD_DIR}
    yum -y install perl-Data-Dumper libaio numactl-devel &> /dev/null \
    || action "Yum安装Mariadb的依赖包失败" false
    groupadd mysql &> /dev/null
    useradd -r -g mysql -s /bin/false mysql &> /dev/null
    mkdir -p ${MYSQLD_DATA_DIR}
    mkdir -p ${INSTALL_MYSQLD_DIR}
    tar xf ${MYSQLD} -C ${INSTALL_MYSQLD_DIR}
    ln -s ${INSTALL_MYSQLD_DIR}/${FILENAME_MYSQLD} ${INSTALL_MYSQLD_DIR}/mysql
    chown -R mysql:mysql  ${INSTALL_MYSQLD_DIR}/mysql
    echo "PATH=${INSTALL_MYSQLD_DIR}/mysql/bin:\$PATH" > /etc/profile.d/mysqld.sh
    source /etc/profile.d/mysqld.sh
cat >/etc/my.cnf<<EOF
[mysqld]
basedir = ${INSTALL_MYSQLD_DIR}/mysql
datadir = ${MYSQLD_DATA_DIR}
socket = ${MYSQLD_DATA_DIR}/mysql.sock
skip_name_resolve = on
port = 3306
[client]
socket = ${MYSQLD_DATA_DIR}/mysql.sock
port = 3306
[mysqld_safe]
pid-file = ${MYSQLD_DATA_DIR}/mysql.pid
log-error = ${MYSQLD_DATA_DIR}/mysql.log
EOF
    chown -R  mysql:mysql ${MYSQLD_DATA_DIR}
    chown -R  mysql:mysql ${INSTALL_MYSQLD_DIR}
    cd ${INSTALL_MYSQLD_DIR}/mysql
    echo "开始初始化数据库"
    ./scripts/mysql_install_db --user=mysql --datadir=${MYSQLD_DATA_DIR} \
    &> /dev/null
    if [ $? -ne 0 ];then
        action "生成数据库文件异常，安装退出" false
        exit 9
    else
        action "初始化数据库完成！"
    fi
    cp ${INSTALL_MYSQLD_DIR}/mysql/support-files/mysql.server /etc/rc.d/init.d/mysqld
    chkconfig --add mysqld
    service mysqld start &> /dev/null
    if [ $? -ne 0 ];then
        action "数据库服务启动失败，脚本退出" false
        echo  "日志文件在/data/mysql/mysql.log"
        exit 9
    else
        action "数据库服务启动!"
    fi
    mysql -uroot  -e "alter user 'root'@'localhost' identified by 'centos'"
    mysql -uroot -p"$PASSWORD" -e "create user wordpress@'10.0.0.%' identified by 'centos'"
    mysql -uroot -p"$PASSWORD" -e "create database wordpress"
    mysql -uroot -p"$PASSWORD" -e "grant all privileges on wordpress.* to wordpress@'10.0.0.%'"
    mysql -uroot -p"$PASSWORD" -e "create user discuz@'10.0.0.%' identified by 'centos'"
    mysql -uroot -p"$PASSWORD" -e "create database discuz"
    mysql -uroot -p"$PASSWORD" -e "grant all privileges on discuz.* to discuz@'10.0.0.%'"
}

function install_php() {
    echo "开始编译安装PHP"
    yum -y install gcc libxml2-devel bzip2-devel libmcrypt-devel \
    sqlite-devel oniguruma-devel openssl-devel xz zip unzip &>/dev/null 
    if [ $? -ne 0 ];then
        action "Yum安装PHP依赖包失败" false
        exit 3
    fi
    cd ${DOWNLOAD_DIR}
    tar xf ${PHP} 
    cd ${FILENAME_PHP}
    echo "开始编译PHP"
    ./configure --prefix=${INSTALL_PHP_DIR} --enable-mysqlnd \
    --with-mysqli=mysqlnd \
    --with-pdo-mysql=mysqlnd --with-openssl --with-zlib \
    --with-config-file-path=/etc --with-config-file-scan-dir=/etc/php.d \
    --enable-mbstring --enable-xml --enable-sockets --enable-fpm \
    --enable-maintainer-zts --disable-fileinfo --with-libdir=lib64 &>/dev/null
    if [ $? -ne 0 ];then
        action "PHP预编译失败" false
        exit 9
    fi
    make -j `lscpu | awk 'NR==4{print $2}'` &>/dev/null 
    if [ $? -ne 0 ];then
        action "PHP编译失败" false
        exit 9
    fi
    make install &>/dev/null
    if [ $? -ne 0 ];then
        action "PHP编译安装失败" false
        exit 9
    fi
    action "编译PHP成功"
    echo "PATH=${INSTALL_PHP_DIR}/bin:\$PATH" > /etc/profile.d/php.sh
    source /etc/profile.d/php.sh
    cp php.ini-production /etc/php.ini
    cp sapi/fpm/php-fpm.service /usr/lib/systemd/system/php-fpm.service
    cd ${INSTALL_PHP_DIR}/etc/
    cp php-fpm.conf.default php-fpm.conf
    cd php-fpm.d/
    cp www.conf.default www.conf
    sed -i -e 's/^user =.*/user = apache/ ' -e 's/^group =.*/group = apache/' \
        -e '/^;pm\.status_path/a pm\.status_path = \/fpm_status' www.conf
    mkdir -p /etc/php.d
    cat>/etc/php.d/opcache.ini<<EOF
[opcache]
zend_extension=opcache.so
opcache.enable=1
EOF
    systemctl daemon-reload
    systemctl enable --now php-fpm &>/dev/null 
    if [ $? -ne 0 ];then
        action "启动PHP-FPM服务失败" false
        exit 9
    fi
    action "PHP-FPM服务已启动！"
    PHP_VERSION=`php -v| awk 'NR==1{print $1,$2}'`
    action "PHP已编译完成,版本信息是：${PHP_VERSION}"
}


#调用函数

check_env
install_wordpress
install_discuz
install_httpd
install_mariadb
install_php
