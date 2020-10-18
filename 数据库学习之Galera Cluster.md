# 数据库学习之Galera Cluster以及Percona Xtradb Cluster 操作

## 1.Galera Cluster是什么？

Galera Cluster是：集成了Galera插件的MySQL集群，是一种新型的，数据不共享的，高度冗余的高可用方案，目前Galera Cluster有两个版本，分别是Percona Xtradb Cluster和Mariadb Cluster，Galera本身是多个主服务器的架构，multi-master，它在稳健性、数据一致性、完整性以及高性能方面有出色表现，是一个有用的高可用方案

我理解一下：多主的集群，通过全局校验的方式保证多个主服务器之间数据不冲突，同时多个主服务器的集群也解决了单个主服务器的单点失败问题，但是因为要全局校验，速度会下降。

节点最少3个，最多8个

限制最少节点是为了避免脑裂，最好使用奇数个数的节点。脑裂指的是双方数据不一致，而且双方服务器数量一致，无法判断应该听从谁的。

* Percona Xtradb Cluster
* Mariadb Galera Cluster

Galera Cluster好的特点：

* 多主架构：真正的多点读写的集群，在任何时候读写数据，都是最新的
* 同步复制：集群不同节点之间数据同步，没有延迟，在数据库挂掉之后，数据不会丢失
* 并发复制：从节点APPLY数据时，支持并行执行，更好的性能
* 故障切换：在出现数据库故障时，因支持多点写入，切换容易
* 热拔插：在服务期间，如果数据库挂了，只要监控程序发现的够快，不可服务时间就会非常少。在节点故障期间，节点本身对集群的影响非常小。
* 自动节点克隆：在新增节点，或者停机维护时，增量数据或者基础数据不需要人工手动备份提供，Galera Cluster会自动拉取在线节点数据，最终集群会变成一致
* 对应用透明：集群的维护，对应用程序是透明的

Galera Cluster缺点：

* 由于DDL需要全局验证通过，则集群性能有集群中最差的服务器决定（一般集群节点配置都是一样的）
* 新节点加入或延后较大的节点重新加入需要全量拷贝数据（SST State Snapshot Transfer），作为doner（贡献者：同步数据时提供数据的服务器）的节点在同步过程中无法提供读写
* 只支持Innodb存储引擎的表

## 2.PXC操作

PXC官方文档：

```
https://www.percona.com/doc/percona-xtradb-cluster/LATEST/overview.html
```

操作指导文档：

```
https://www.percona.com/doc/percona-xtradb-cluster/LATEST/overview.html
```

PXC支持的版本列表：

```
https://www.percona.com/services/policies/percona-software-support-lifecycle#mysql
```



### 2.1 环境准备

三台主机CentOS7.8用于搭建环境，一台是ansible主机CentOS7.8，负责管理他们，另外还可以顺便试试添加新主机进入PXC的操作

```
10.0.0.7：ansible主机
10.0.0.101
10.0.0.111
10.0.0.112
```



```
Note

Avoid creating a cluster with two or any even number of nodes, because this can lead to split brain.（脑裂）
```

端口使用：TCP

```
3306
4444
4567
4568
```

SELinux关闭

### 2.2开始操作

**1.Install Percona XtraDB Cluster on all nodes and set up**

推荐使用国内镜像仓库下载安装，下面就是添加仓库

```
https://mirrors.tuna.tsinghua.edu.cn/percona/release/7/os/x86_64/
```

写一个ansible的playbook，顺便练手

```
  1 ---
  2 - hosts: dbservers
  3   gather_facts: no
  4 
  5   tasks:
  6     - name: create a repository file
  7       copy: content="[percona-xtradb-cluster]\nname=pxc\nbaseur    l=https://mirrors.tuna.tsinghua.edu.cn/percona/release/7/os/x86    _64/\nenabled=1\ngpgcheck=0\n" dest=/etc/yum.repos.d/pxc.repo
  8     - name: install pxc
  9       yum: name=Percona-XtraDB-Cluster-57 state=present    
```

**2.配置PXC**
一共这几个配置文件：

```
/etc/my.cnf
/etc/percona-xtradb-cluster.conf.d/mysqld.cnf
/etc/percona-xtradb-cluster.conf.d/mysqld_safe.cnf
/etc/percona-xtradb-cluster.conf.d/wsrep.cnf
```

改/etc/percona-xtradb-cluster.conf.d/mysqld.cnf

```
server-id=N #默认都是1，需要改成不同的id
```

/etc/percona-xtradb-cluster.conf.d/mysqld_safe.cnf不需要修改

每台节点都需要修改：/etc/percona-xtradb-cluster.conf.d/wsrep.cnf

```
需要修改的地方：
wsrep_cluster_address=gcomm://10.0.0.101,10.0.0.110,10.0.0.112 #填所有节点的IP

wsrep_node_address=10.0.0.101 #这行原本被注释了，取消注释，然后填写自己的IP

wsrep_node_name=pxc-cluster-node-1  #这个nodeId也改成不一样的

wsrep_sst_auth="sstuser:s3cretPass" #取消注释，sst:state snapshot transfer 全量传输
```

**3.启动PXC集群的第一个节点**

```
systemctl start mysql@bootstrap.service
ss -ntl
LISTEN      0      80       [::]:3306 
这个会随机生成密码，密码在日志里
grep "temporary password" /var/log/mysqld.log
2020-10-18T08:48:41.805204Z 1 [Note] A temporary password is generated for root@localhost: q>ydrkytt0Lh

q>ydrkytt0Lh

登录数据库
mysql -uroot -p
q>ydrkytt0Lh

修改密码
ALTER USER 'root'@'localhost' identified by 'passwd';

创建一个sst的用户，并给他授权
create user 'sstuser'@'localhost' identified by 's3cretPass';

grant reload,lock tables,process,replication client on *.* to 'sstuser'@'localhost';

查看几个重要的状态值

show status like 'wsrep%'
| wsrep_cluster_size               | 1      #当前的节点数量
| wsrep_local_state_comment        | Synced  #当前的数据同步状态，synced表示同步完成
| wsrep_cluster_status             | Primary  #集群状态，表示准备好了


```

**4.启动集群中的其他节点**

```
ss -nlt
systemctl start mysql
#这个启动要点时间
ss -nlt
LISTEN      0      80       [::]:3306
```

这时候再去看那几个状态值，发现变了

```
#在任意的节点上看
show status like 'wsrep%';
| wsrep_cluster_size               | 3 
```



**5.测试**

通过在任意一个节点上修改数据，查看其他节点

这样就完成了PXC的基本配置，但是我在做的时候也发现了一个问题，mysql生成的随机密码不能登录，不论是

```
mysql -uroot -p""
还是
mysql -uroot -p''
或者手输入都不行，不知道是不是需要对随机密码中的符号进行转义？
```

