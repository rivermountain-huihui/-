### nfs客户端实现自动挂载的两种方式

#### 2.Centos 7.6中nfs客户端使用/etc/fstab实现开机自动挂载

需要两台主机，一台nfs服务器 10.0.0.7，一台nfs客户端 10.0.0.11

实验步骤：

1.搭建nfs服务

2.设置共享文件夹

3.在客户端配置挂载

4.测试挂载

开始

1.在10.0.0.7上搭建nfs服务

```
yum install nfs-utils
systemctl start nfs-server
```

2.设置共享文件夹

```
➜  ~ mkdir -p /data/share
➜  ~ vim /etc/exports
  1 /data/share 10.0.0.0/24(rw,sync)
➜  ~ exportfs -r
➜  ~ exportfs -v
/data/share   	10.0.0.0/24(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
```

3.客户端挂载

```
yum install nfs-utils
[root@node_7 ~]$showmount -e 10.0.0.7
Export list for 10.0.0.7:
/data/share 10.0.0.0/24
vim /etc/fstab
10.0.0.7:/data/share                     /data/file               nfs     defaults,_netdev     0 0   
```

注释：_netdev的意思是这个文件挂载不上也能开机，避免因为网络原因导致客户端无法开机

4.重启客户端测试，可以实现

```
[root@node_7 ~]$df -h
Filesystem            Size  Used Avail Use% Mounted on
devtmpfs              476M     0  476M   0% /dev
tmpfs                 487M     0  487M   0% /dev/shm
tmpfs                 487M  7.7M  479M   2% /run
tmpfs                 487M     0  487M   0% /sys/fs/cgroup
/dev/sda3             197G  3.4G  194G   2% /
/dev/sda1             976M  113M  797M  13% /boot
10.0.0.7:/data/share  197G  5.0G  192G   3% /data/file
tmpfs                  98M     0   98M   0% /run/user/0
```





#### 3.通过autofs实现实时挂载

实验需要两台主机，一台nfs服务器端 10.0.0.7，一台nfs客户端 10.0.0.11

实验步骤：

1.搭建nfs服务

2.配置共享文件

3.客户端安装和配置autofs

4.测试挂载

开始

1.在10.0.0.7搭建nfs服务

```
yum install nfs-utils
systemctl start nfs-server
```

2.配置共享文件

```
mkdir -p /data/share_1
vim /etc/exports
/data/share1 10.0.0.0/24(rw,sync)
➜  ~ exportfs -r
➜  ~ exportfs -v
/data/share1  	10.0.0.0/24(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)

```

3.在客户端安装autofs以及配置自动挂载

```
[root@node_7 ~]$yum -y install nfs-utils autofs
[root@node_7 ~]$mkdir -p /data/file1
#配置autofs，使用绝对路径的方法
vim /etc/auto.master
/-      /etc/auto.file1
vim /etc/auto.file1
  1 /data/file1 -fstype=nfs 10.0.0.7:/data/share1 
#启动autofs服务
systemctl start autofs
```

4.访问测试

在没有访问/data/file1时的挂载情况

```
[root@node_7 ~]$df 
Filesystem           1K-blocks    Used Available Use% Mounted on
devtmpfs                486876       0    486876   0% /dev
tmpfs                   497840       0    497840   0% /dev/shm
tmpfs                   497840    7820    490020   2% /run
tmpfs                   497840       0    497840   0% /sys/fs/cgroup
/dev/sda3            206467588 3538860 202928728   2% /
/dev/sda1               999320  114776    815732  13% /boot

```

访问/data/file1后的挂载情况

```
[root@node_7 ~]$ll /data/file1
total 0
[root@node_7 ~]$df -h
Filesystem             Size  Used Avail Use% Mounted on
devtmpfs               476M     0  476M   0% /dev
tmpfs                  487M     0  487M   0% /dev/shm
tmpfs                  487M  7.7M  479M   2% /run
tmpfs                  487M     0  487M   0% /sys/fs/cgroup
/dev/sda3              197G  3.4G  194G   2% /
/dev/sda1              976M  113M  797M  13% /boot
tmpfs                   98M     0   98M   0% /run/user/0
10.0.0.7:/data/share1  197G  5.0G  192G   3% /data/file1
```

测试成功