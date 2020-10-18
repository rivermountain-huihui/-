问题：当master服务器宕机，提升一个slave成为master的步骤

回答：

情况一：有MHA这类的高可用架构时

如果有MHA，那么我们要做的就是去修复旧的MASTER，修复好后重新配置MHA，作为一个从节点把它添加进去，然后启动MHA

情况二：没有高可用的架构时：

1.如果主节点的宕机是那种还能登陆进操作系统的，那么赶紧把主节点的二进制日志拷贝出来；

2.查看每一台从节点的slave状态，看看谁的数据是最新的，具体命令是：

```
#登陆到mysql数据库中
show slave status\G
#查看复制主节点二进制日志的位置编号谁的最新
```

3.找到最新的那台从节点后，把刚刚从主节点拷贝出来的二进制日志中比从节点位置新的那部分数据导入到这个新的主节点中，记得临时关闭一下二进制日志

```
#关闭slave
stop slave;
reset slave all;
#临时关闭二进制日志，在mysql命令行中输入
set sql_log_bin=0
#查看刚刚从主节点拷贝的二进制日志文件
mysqlbinlog --start-position=Numer xxxx.log > inc.sql
#导入二进制日志
source inc.sql
#重新开启二进制日志
set sql_log_bin=1
```

4.对新主节点全量备份

```
mysqldump -A -F --single-transaction --master-data=1 |gzip > full.sql.gz
```

5.其他的从节点导入新主节点的全量备份，并且重新设置主节点IP和位置

```
set sql_log_bin=0
source full.sql
set sql_log_bin=1
stop slave;
reset slave all;
change master to master_host='新的主节点IP'，
 master_user='repluser',
 master_password='centos',
 master_log_file='xxx.log',#这个文件和位置需要查看全量备份文件中记录的CHANGE MASTER TO 后面的内容
 master_log_pos=xxx;
```

6.修复宕机节点，并根据情况把它添加进主从复制中