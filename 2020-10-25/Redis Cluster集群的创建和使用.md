# Redis Cluster集群的创建和使用

## 操作：使用Redis 5.0部署Cluster

需要使用到的命令：

```
[root@node_7 ~]$redis-cli --cluster help
Cluster Manager Commands:
  create         host1:port1 ... hostN:portN
                 --cluster-replicas <arg>
  check          host:port
                 --cluster-search-multiple-owners
  info           host:port
  fix            host:port
                 --cluster-search-multiple-owners
  reshard        host:port
                 --cluster-from <arg>
                 --cluster-to <arg>
                 --cluster-slots <arg>
                 --cluster-yes
                 --cluster-timeout <arg>
                 --cluster-pipeline <arg>
                 --cluster-replace
  rebalance      host:port
                 --cluster-weight <node1=w1...nodeN=wN>
                 --cluster-use-empty-masters
                 --cluster-timeout <arg>
                 --cluster-simulate
                 --cluster-pipeline <arg>
                 --cluster-threshold <arg>
                 --cluster-replace
  add-node       new_host:new_port existing_host:existing_port
                 --cluster-slave
                 --cluster-master-id <arg>
  del-node       host:port node_id
  call           host:port command arg arg .. arg
  set-timeout    host:port milliseconds
  import         host:port
                 --cluster-from <arg>
                 --cluster-copy
                 --cluster-replace
  help           

For check, fix, reshard, del-node, set-timeout you can specify the host and port of any working node in the cluster.
```

**注意：在操作前先监控日志**

部署要求：

* 每个redis节点采用相同的硬件配置、相同的密码、相同的redis版本
* 所有redis服务器必须没有任何书籍
* 先启动为单机redis且没有任何key value

### 1.创建集群

```
➜  ~ redis-cli -a centos --cluster create 10.0.0.7:6379 10.0.0.101:6379 10.0.0.110:6379 1
0.0.0.11:6379 10.0.0.12:6379 10.0.0.13:6379 --cluster-replicas 1

#命令说明：
--cluster create  表示创建集群
后面跟着的主机名:端口，表示要加入集群的主机和端口
--cluster-replicas 1  表示集群中主从复制，并且每个主节点配合一个从节点
cluster会自动把前面三个变成主节点，后面三个变成从节点
```

创建的过程中：

```
>>> Performing hash slots allocation on 6 nodes...
Master[0] -> Slots 0 - 5460
Master[1] -> Slots 5461 - 10922
Master[2] -> Slots 10923 - 16383                       #分配槽位
Adding replica 10.0.0.12:6379 to 10.0.0.7:6379
Adding replica 10.0.0.13:6379 to 10.0.0.101:6379
Adding replica 10.0.0.11:6379 to 10.0.0.110:6379       #分配主从节点
M: 4566b927c1fa4d183de1e510300b27fe0fe3d96d 10.0.0.7:6379
   slots:[0-5460] (5461 slots) master
M: 276433f13427e2476a0b650b5b591397c06647e7 10.0.0.101:6379
   slots:[5461-10922] (5462 slots) master
M: 6f7e7f5b60d527c9cb9f4a643f10b461d57d5b15 10.0.0.110:6379
   slots:[10923-16383] (5461 slots) master
S: 118ef9055d7465fbc6ba7999beaacf69b3892ad6 10.0.0.11:6379
   replicates 6f7e7f5b60d527c9cb9f4a643f10b461d57d5b15
S: 819d053d78d249570b5bd610436fdb0e4ac59627 10.0.0.12:6379
   replicates 4566b927c1fa4d183de1e510300b27fe0fe3d96d
S: 85b6872df50db7e8644b855cebd0a3ee3656e20f 10.0.0.13:6379
   replicates 276433f13427e2476a0b650b5b591397c06647e7
Can I set the above configuration? (type 'yes' to accept):  #需要接受或拒绝

```

完成的样子：

```
>>> Nodes configuration updated
>>> Assign a different config epoch to each node
>>> Sending CLUSTER MEET messages to join the cluster
Waiting for the cluster to join
........
>>> Performing Cluster Check (using node 10.0.0.7:6379)
M: 4566b927c1fa4d183de1e510300b27fe0fe3d96d 10.0.0.7:6379
   slots:[0-5460] (5461 slots) master
   1 additional replica(s)
S: 118ef9055d7465fbc6ba7999beaacf69b3892ad6 10.0.0.11:6379
   slots: (0 slots) slave
   replicates 6f7e7f5b60d527c9cb9f4a643f10b461d57d5b15
M: 6f7e7f5b60d527c9cb9f4a643f10b461d57d5b15 10.0.0.110:6379
   slots:[10923-16383] (5461 slots) master
   1 additional replica(s)
S: 85b6872df50db7e8644b855cebd0a3ee3656e20f 10.0.0.13:6379
   slots: (0 slots) slave
   replicates 276433f13427e2476a0b650b5b591397c06647e7
M: 276433f13427e2476a0b650b5b591397c06647e7 10.0.0.101:6379
   slots:[5461-10922] (5462 slots) master
   1 additional replica(s)
S: 819d053d78d249570b5bd610436fdb0e4ac59627 10.0.0.12:6379
   slots: (0 slots) slave
   replicates 4566b927c1fa4d183de1e510300b27fe0fe3d96d
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.

```

查看当前的集群状态：

```
127.0.0.1:6379> cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6           #节点个数
cluster_size:3                  #主节点个数，也是主从对的个数
cluster_current_epoch:6
cluster_my_epoch:1
cluster_stats_messages_ping_sent:92
cluster_stats_messages_pong_sent:94
cluster_stats_messages_sent:186
cluster_stats_messages_ping_received:89
cluster_stats_messages_pong_received:92
cluster_stats_messages_meet_received:5
cluster_stats_messages_received:186

```

### 2.测试多个主节点分别写入

```
127.0.0.1:6379> set huihui jiayou
(error) MOVED 16071 10.0.0.110:6379
127.0.0.1:6379> set dota haowan
(error) MOVED 7267 10.0.0.101:6379
127.0.0.1:6379> set dota2 haowan
(error) MOVED 14116 10.0.0.110:6379
```

### 3.测试主从的切换：

```
关闭主节点7，看它的从节点11会怎么样
1688:S 24 Oct 2020 19:33:23.826 # Starting a failover election for epoch 7.
1688:S 24 Oct 2020 19:33:23.837 # Failover election won: I'm the new master.
1688:S 24 Oct 2020 19:33:23.837 # configEpoch set to 7 after successful failover
1688:M 24 Oct 2020 19:33:23.837 # Setting secondary replication ID to 1786540a1dc01f327cbde7f520591090c96a9f4d, valid up to offset: 715. New replication ID is 6e95b3f60a28e9510a43da88105357924d1e344d
1688:M 24 Oct 2020 19:33:23.837 * Discarding previously cached master state.
切换成功！
```

### 4.写一个可以向集群写入数据的Python脚本：用redis-cli -c 可能更方便

```
  1 #!/usr/bin/env python3
  2 
  3 from rediscluster import RedisCluster
  4 startup_nodes = [
  5     {"host":"10.0.0.7", "port":6379},
  6     {"host":"10.0.0.101", "port":6379},
  7     {"host":"10.0.0.110", "port":6379},
  8     {"host":"10.0.0.11", "port":6379},
  9     {"host":"10.0.0.12", "port":6379},
 10     {"host":"10.0.0.13", "port":6379}
 11 ]
 12 redis_conn = RedisCluster(startup_nodes = startup_nodes, password = 'centos', \
 13                          decode_responses = True)
 14 
 15 for i in range(0, 10000):
 16     redis_conn.set('huihuide' + str(i), 'xinxinde' + str(i))
 17     print('huihuide' + str(i) + ':', redis_conn.get('huihuide' + str(i)) )

```



#### 