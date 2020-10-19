Ansible的实际练习：在Centos8虚拟机上二进制包方式安装Mysql_8.0.20

步骤：

1.准备mysql_8.0.20的Linux下的二进制包

获取方式：官网，地址如下，在里面挑选你想要的包

```
https://downloads.mysql.com/archives/community/
```
我下载的是：mysql-8.0.20-linux-glibc2.12-x86_64.tar.xz，下载地址是

```
https://downloads.mysql.com/archives/get/p/23/file/mysql-8.0.20-linux-glibc2.12-x86_64.tar.xz
```

2.准备mysql的配置文件

3.编写playbook，我就一步一步从把之前写的脚本修改成playbook的模块实现的

```
---
- hosts: 10.0.0.119
  remote_user: root
  gather_facts: no

#剧本任务顺序：
#需要提前准备好tar包和配置文件
#1.拷贝二进制文件到远程主机，并解压到指定目录/usr/local/
#2.创建mysql组和用户
#3.创建mysql解压文件的软链接，修改环境变量
#4.创建数据目录/data/mysql，并修改文件用户和组
#5.安装依赖软件包
#6.拷贝配置文件过去
#.执行mysql的初始化脚本，生成数据文件
#.复制启动脚本到/etc/init./下
#.添加到开机自启动
#.启动服务
#.进行安全加固
  
  tasks:
    - name: copy the tar file to the remote hosts
      unarchive: remote_src=no src=/usr/local/src/mysql-8.0.20-linux-glibc2.12-x86_64.tar.xz dest=/usr/local/
    - name: create a group mysql
      group: name=mysql 
    - name: create a user mysql
      user: name=mysql state=present system=yes shell=/bin/nologin group=mysql
    - name: create a symbolic link for mysql file
      file: src=/usr/local/mysql-8.0.20-linux-glibc2.12-x86_64 dest=/usr/local/mysql state=link
    - name: add mysql bin path to the env path
      copy: content="PATH=/usr/local/mysql/bin:$PATH" dest=/etc/profile.d/mysql.sh
    - name: create a data directory
      file: path=/data/mysql/ owner=mysql group=mysql state=directory
    - name: install the dependent rpm packages
      yum : name=libaio,ncurses-compat-libs,perl-Data-Dumper state=present
    - name: copy the config file to  the remote hosts
      copy: src=/data/ansible/my.cnf dest=/etc/my.cnf backup=yes
    - name: execute the initialize shell script
      shell: mysqld --initialize-insecure --user=mysql --datadir=/data/mysql
    - name: copy the start-script-file to /etc/init.d/
      shell: cp /usr/local/mysql/support-files/mysql.server /etc/rc.d/init.d/mysqld ; chkconfig --add mysqld
    - name: start mysql
      shell: service mysqld start
    - name: change the passwd
      shell: mysql -e "alter user 'root'@'localhost' identified by 'centos'"



```
4.安装测试，在ansible管理机上执行
```
ansible-playbook install_mysql_8.0.20.yml
···
执行成功！
