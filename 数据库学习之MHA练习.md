# 数据库学习之MHA练习

## MHA Master High Availability

### MHA的工作原理：

1.从宕机崩溃的master主机保存二进制日志事件（binlog events）

2.识别含有最新更新的slave

3.应用差异的中继日志（relay log）到其他的slave

4.应用从master保存的二进制日志事件

5.提升一个slave为新的master

6.使其他的slave连接新的master进行复制

7.注意，为了尽量减少主库宕机造成的数据丢失，因此在配置MHA的同时建议配置成MySQL的半同步复制



### MHA软件

MHA软件由两部分组成，Manager工具包和Node工具包



### 实验：使用MHA实现高可用

一共四台机器，一台是MHA的管理机，一台主服务器，两台从服务器

操作系统都是centos7，数据库使用mysql 5.7.30

MHA使用mha4mysql-manager-0.58-0.el7.centos.noarch.rpm和mha4mysql-node-0.58-0.el7.centos.noarch.rpm

**注意：MHA的软件存在兼容性问题，上面的组合是可以的**

**提前下载好mha软件，我们用yum只是为了让yum帮我们解决依赖关系**

#### 1.在管理机上安装manager包，注意先安装node包，再安装manager包

```
yum install mha4mysql-node-0.58-0.el7.centos.noarch.rpm -y

yum install -y mha4mysql-manager-0.58-0.el7.centos.noarch.rpm

```

#### 2.在所有节点上安装node包，管理机也安装

```
yum install -y mha4mysql-manager-0.58-0.el7.centos.noarch.rpm
```



#### 3.在所有的节点中实现基于key验证的ssh登录方式

1.生成密钥

```
ssh-keygen -t rsa -f /root/.ssh/id_rsa -P 'passwd'
#选项都可以不加，默认就是 -t rsa -f /root/.ssh/id_rsa，默认没有密码
```

2.分发公钥

```
ssh-copy-id -i /root/.ssh/id_rsa 本机IP
#这一步是为了生成认证文件和公钥，这样下一步可以直接把这个文件拷贝到其他主机上
```

```
➜  ~ scp -r ./.ssh 10.0.0.112:/root/
```



#### 4.在管理节点配置文件，主要得有两个脚本

```
mkdir /etc/mastermha/ #目录和配置文件要自己创建
vim /etc/mastermha/app1.cnf
  1 [server default]                                                       
  2 user=mhauser
  3 password=centos
  4 manager_workdir=/data/mastermha/app1/
  5 manager_log=/data/mastermha/manager.log
  6 remote_workdir=/data/mastermha/app1/
  7 ssh_user=root
  8 repl_user=repluser
  9 repl_password=centos
 10 ping_interval=1
 11 master_ip_failover_script=/usr/local/bin/master_ip_failover
 12 report_script=/usr/local/bin/sendmail.sh
 13 check_repl_delay=0
 14 master_binlog_dir=/data/mysql/
 15 
 16 [server1]
 17 hostname=10.0.0.101
 18 candidate_master=1
 19 
 20 [server2]
 21 hostname=10.0.0.110
 22 candidate_master=1
 23 
 24 [server3]
 25 hostname=10.0.0.112

```

脚本1：master_ip_failover

```
#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';
use Getopt::Long;
my (
$command, $ssh_user, $orig_master_host, $orig_master_ip,
$orig_master_port, $new_master_host, $new_master_ip, $new_master_port
);
my $vip = '10.0.0.100';#设置Virtual IP
my $gateway = '10.0.0.254';#网关Gateway IP
my $interface = 'eth0';
my $key = "1";
my $ssh_start_vip = "/sbin/ifconfig $interface:$key $vip;/sbin/arping -I $interface -c 3 -s $vip $gateway >/dev/null 2>&1";
my $ssh_stop_vip = "/sbin/ifconfig $interface:$key down";
GetOptions(
'command=s' => \$command,
'ssh_user=s' => \$ssh_user,
'orig_master_host=s' => \$orig_master_host,
'orig_master_ip=s' => \$orig_master_ip,
'orig_master_port=i' => \$orig_master_port,
'new_master_host=s' => \$new_master_host,
'new_master_ip=s' => \$new_master_ip,
'new_master_port=i' => \$new_master_port,
);
exit &main();
sub main {
print "\n\nIN SCRIPT TEST====$ssh_stop_vip==$ssh_start_vip===\n\n";
if ( $command eq "stop" || $command eq "stopssh" ) {
# $orig_master_host, $orig_master_ip, $orig_master_port are passed.
# If you manage master ip address at global catalog database,
# invalidate orig_master_ip here.
my $exit_code = 1;
eval {
print "Disabling the VIP on old master: $orig_master_host \n";
&stop_vip();
$exit_code = 0;
};
if ($@) {
warn "Got Error: $@\n";
exit $exit_code;
}
exit $exit_code;
}
elsif ( $command eq "start" ) {
# all arguments are passed.
# If you manage master ip address at global catalog database,
# activate new_master_ip here.
# You can also grant write access (create user, set read_only=0, etc) here.
my $exit_code = 10;
eval {
print "Enabling the VIP - $vip on the new master - $new_master_host \n";
&start_vip();
$exit_code = 0;
};
if ($@) {
warn $@;
exit $exit_code;
}
exit $exit_code;
}
elsif ( $command eq "status" ) {
print "Checking the Status of the script.. OK \n";
`ssh $ssh_user\@$orig_master_host \" $ssh_start_vip \"`;
exit 0;
}
else {
&usage();
exit 1;
}
}
# A simple system call that enable the VIP on the new master
sub start_vip() {
`ssh $ssh_user\@$new_master_host \" $ssh_start_vip \"`;
}
# A simple system call that disable the VIP on the old_master
sub stop_vip() {
`ssh $ssh_user\@$orig_master_host \" $ssh_stop_vip \"`;
}
sub usage {
print
"Usage: master_ip_failover --command=start|stop|stopssh|status --orig_master_host=host --orig_master_ip=ip --orig_master_port=port --new_master_host=host --new_master_ip=ip --new_master_port=port\n";
}


```

脚本2：sendmail.sh

```
echo "MySQL is down" | mail -s "MHA Warning" root@abc.com
#这个脚本需要你的机器已经配置过/etc/mail.rc 添加过邮件服务器了
```



#### 5.在三台节点上实现一主多从，并且开启半同步复制，减少数据丢失的风险

```
实现master主机，基于GTID实现

​```
gtid_mode=on
enforce_gtid_consistency=on
log_bin
server-id=xxx
开启半同步复制
plugin-load-add=semisync_master.so
rpl_semi_sync_master_enabled=on
rpl_semi_sync_master_timeout=3000

新建复制账号和MHA管理账号
CREATE USER 'repluser'@'10.0.0.%' identified by 'centos';
CREATE USER 'mhauser'@'10.0.0.%' identified by 'centos';

GRANT replication slave on *.* to 'repluser'@'10.0.0.%'
GRANT all on *.* to 'mhauser'@'10.0.0.%'

​```

实现slave主机

​```
gtid_mode=on
enforce_gtid_consistency=on
plugin-load-add=semisync_slave.so
rpl_semi_sync_slave_enabled=on

change master to master_host='10.0.0.112',
 master_user='repluser',
 master_password='centos',
 master_auto_position;
​```


```



#### 6.运行MHA的程序，检查MHA的环境

```
➜  src /usr/bin/masterha_check_ssh --conf=/etc/mastermha/app1.cnf
➜  src /usr/bin/masterha_check_repl --conf=/etc/mastermha/app1.cnf
#根据提示修改不符合要求的设置
➜  src /usr/bin/masterha_check_status --conf=/etc/mastermha/app1.cnf
app1 is stopped(2:NOT_RUNNING).
现在还没开MHA，所以这个是正常的
```



#### 7.启动MHA

```
➜  nohub src /usr/bin/masterha_manager --conf=/etc/mastermha/app1.cnf
这个是前台启动的，程序运行时命令行不会变化
另外开一个窗口观察当前MHA状态
➜  ~ /usr/bin/masterha_check_status --conf=/etc/mastermha/app1.cnf 
app1 (pid:5767) is running(0:PING_OK), master:10.0.0.101
启动成功
```



#### 8.重要的日志

```
tail -f /data/mastermha/manager.log
```



#### 9.模拟故障，测试MHA的功能

```
#MHA有个特点，当master主机down后，MHA开始工作，提拔一个从服务器为主服务器，之后MHA服务就停止了
当故障发生后，我测试几乎5秒不到就切换好了新主机，MHA发送了邮件，然后停止了服务
```

注意：如果再次运行MHA，需要先删除了下面的文件

```
rm -f /data/mastermha/app1/app1.failover.complete
```

