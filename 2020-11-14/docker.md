本周作业

1.通过RPM安装docker 17.03.0 版本并且配置docker阿里加速

脚本中配置了一个阿里云的docker-ce仓库，然后从这个仓库中下载各个版本的docker-ce，安装完成后再把从阿里云申请

centos7一键安装docker脚本

```
#!/bin/bash
# Centos7一键安装docker同时配置阿里云的镜像加速器脚本
# 采用的方法是使用阿里云的Yum源

# 调用Linux系统自带函数action
source /etc/init.d/functions

# 定义变量
DOWNLOAD_DIR="/usr/local/src"
VERSION="17.03.0.ce-1.el7"

# 定义函数
function install_docker() {
    echo "开始安装docker，请稍等"
    # step 1: 安装必要的一些系统工具
    yum install -y yum-utils device-mapper-persistent-data lvm2 &>/dev/null || { action "必要工具下载失败，请检查yum源" false;exit 9; }
    # Step 2: 添加软件源信息
    yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo &>/dev/null
    # Step 3: 更新并安装Docker-CE
    yum makecache fast &>/dev/null
    # 中间centos7需要额外安装一个包
    cd ${DOWNLOAD_DIR}
    yum -y install https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/docker-ce-selinux-17.03.0.ce-1.el7.centos.noarch.rpm
    yum -y install docker-ce-${VERSION} &>/dev/null && action "docker-ce-${VERSION}安装成功！" || { action "安装docker-ce-${VERSION}失败" false;exit 9; }
    # 如果要选择不同版本的软件，那么加上--showduplicates选项
    # yum list docker-ce --showduplicates
    # Step 4: 开启Docker服务
    systemctl enable --now docker && action "Docker守护进程已开启！" || { action "Docker守护进程启动失败" false;exit 9; } 
}

function speedUp() {
    tee /etc/docker/daemon.json <<-'EOF'
{
    "registry-mirrors": ["https://6kqxd7ws.mirror.aliyuncs.com"]
}
EOF
    systemctl restart docker
}
# 调用函数
install_docker
speedUp

```

2.通过docker安装一个LAMP架构

一共使用两个容器，一个是php:7.2-apache，另一个是mysql:8.0.22，php:7.2-apache镜像提供了apache和php

```bash
# 先拉取一个mysql的镜像，把容器的3306端口映射成宿主机的3307端口，同时指定容器数据库的root用户的密码
docker run --name mysql1 -e MYSQL_ROOT_PASSWORD=centos -d -p 3307:3306 mysql:8.0.22

# 因为PHP和Apache的镜像可以使用宿主机的网页php代码，因此提前准备一个文件夹，里面放上php网页代码
mkdir /data
# 然后在里面写一个index.php
vim /data/index.php
<?
phpinfo();
# 然后进去/data目录
cd /data
# 然后拉取一个php:7.2-apache镜像，这是PHP在dockerhub上提供的官方镜像
docker run -d -p 80:80 --name my-apache-php-app -v "$PWD":/var/www/html php:7.2-apache
# 这时候查看容器状态，可以看到两个容器都运行正常，端口也暴露给宿主机了
root@ubuntu1804:/data# docker container list
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                               NAMES
9fbd46f71004        php:7.2-apache      "docker-php-entrypoi…"   15 minutes ago      Up 15 minutes       0.0.0.0:80->80/tcp                  my-apache-php-app
065d8b9c9289        mysql:8.0.22        "docker-entrypoint.s…"   5 hours ago         Up 5 hours          33060/tcp, 0.0.0.0:3307->3306/tcp   mysql1

# 查看宿主机端口情况，可以看到3307端口和80端口
root@ubuntu1804:/data# ss -ntl
State     Recv-Q     Send-Q          Local Address:Port         Peer Address:Port
LISTEN    0          128             127.0.0.53%lo:53                0.0.0.0:*
LISTEN    0          128                   0.0.0.0:22                0.0.0.0:*
LISTEN    0          128                 127.0.0.1:6010              0.0.0.0:*
LISTEN    0          128                         *:3307                    *:*
LISTEN    0          128                         *:80                      *:*
LISTEN    0          128                      [::]:22                   [::]:*
LISTEN    0          128                     [::1]:6010                 [::]:*

# 在浏览器访问宿主机IP，可以看到phpinfo()展示的内容了，搭建成功

# 在上面的实验中，还可以让数据库使用宿主机的目录作为数据目录，这样数据库容器停止了也没事，数据还在，
使用命令
docker run --name some-mysql -v /data/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=centos -d mysql:8.0.22
这样数据库启动时，使用的数据目录就是宿主机的目录了
```



3.使用docker run 命令的延伸指令，如在停止一个docker容器的时候自动删除该容器

```
docker run --name httpd -d -p 8080:80 --rm httpd:latest 
```

docker run的其他延伸指令

```
root@ubuntu1804:~# docker run --help

Usage:  docker run [OPTIONS] IMAGE [COMMAND] [ARG...]

Run a command in a new container
-i,--interactive 交互模式
-t,--tty  分配pseudo-tty，通常和-i一起使用，注意对应的容器必须运行shell才支持
-d，--detach  后台运行容器，并打印容器ID
--name 设定容器名称
--h，hostname，设定容器主机名
--rm，Automatically remove the container when it exits 在容器停止时自动删除容器
-p，--publish list Publish a container's port(s) to the host  把容器的一个端口暴露给宿主机的一个端口
-P，--publish-all  Publish all exposed ports to random ports 把容器的全部端口暴露给宿主机，端口之间的映射关系是在一定的端口范围内随机分配的
--dns list                       Set custom DNS servers  设置自定义的DNS服务器
--entrypoint string              Overwrite the default ENTRYPOINT of the image 
--restart string                 Restart policy to apply when a container exits (default "no")
重启容器的规则，默认是不重启，可以跟always，只要容器退出就重启
还有on-failure
unless-stopped

--privileged Give extended privileges to this container 给容器特定的权限
-e,--env=[]		Set environment variables，设定容器的环境变量

```

4.写出docker run 命令在自动启动docker服务时通过什么参数能够启动docker中的容器，从而实现容器随着docker服务的启动而自动启动

设置`--restart always`选项可以达到这个目的

```
docerk run --name httpd1 -d -p 8080:80 --restart always httpd
```










