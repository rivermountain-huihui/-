# Linux Virtual Server

LVS：负载均衡服务器

Linux Virtual Server

尝试使用80/20方法进行LVS的学习，得分步骤做：80%的需要是在20%的内容中的

LVS的重要的20%是：

* LVS的工作原理
* LVS-DR模型的实现方法
* LVS-DR的实际操作

## 内容：

* **集群概念**
* **LVS模型**
* **LVS调度算法**
* **LVS实现**
* **Idirectord**

# 1.集群和分布式

系统性能扩展方式：

* Scale Up：垂直扩展，向上扩展，增强单个服务器的性能
* Scale Out：水平扩展，向外扩展，增加更多设备

水平扩展更合适，性价比高，所以需要一个调度器

## 1.1 集群 Cluster

Cluster分为三个类型

* LB：Load Balancing 负载均衡，多个主机组成，每个主机只承担一部分访问请求

* HA：High Availiablity，高可用，避免单点失败问题

  考核指标：MTBF：Mean Time Between failure 平均无故障时间，即正常时间

  MTTR：Mean Time To Restoration  平均恢复前时间，即故障时间

  故障时间 / 全部时间	的比值，99% 99.9% 99.99% 99.999%，按年来算

  SLA：服务等级协议，就是看你能有几个9

  计划外的停机时间是我们需要关注的

* HPC：

## 1.2 分布式系统

分布式存储：Ceph，Gluster，FastDFS，MogileFS

分布式计算：Hadoop，Spark



1.3 集群和分布式的区别



1.4 集群设计原则



1.5 集群涉及实现

1.5.1 基础设施层面

1.5.2 业务层面

## 1.6 LB Cluster 负载均衡集群

1.6.1 实现方式

* 硬件实现
* 软件



# 2.LVS

LVS工作原理：LVS是内核级功能，工作在INPUT链的位置，将发往INPUT链的数据报文根据目标IP和目标端口及协议将其调度转发到真实的业务服务器上，转发的依据是多种调度算法

查看内核对LVS的支持：

```bash
➜  ~ grep -i -C 10 ipvs /boot/config-3.10.0-1127.el7.x86_64
# IPVS transport protocol load balancing support    #支持的协议
#
CONFIG_IP_VS_PROTO_TCP=y
CONFIG_IP_VS_PROTO_UDP=y
CONFIG_IP_VS_PROTO_AH_ESP=y
CONFIG_IP_VS_PROTO_ESP=y
CONFIG_IP_VS_PROTO_AH=y
CONFIG_IP_VS_PROTO_SCTP=y

#
# IPVS scheduler    #调度算法
#
CONFIG_IP_VS_RR=m
CONFIG_IP_VS_WRR=m
CONFIG_IP_VS_LC=m
CONFIG_IP_VS_WLC=m
CONFIG_IP_VS_LBLC=m
CONFIG_IP_VS_LBLCR=m
CONFIG_IP_VS_DH=m
CONFIG_IP_VS_SH=m
CONFIG_IP_VS_SED=m
CONFIG_IP_VS_NQ=m

#
# IPVS SH scheduler
#
CONFIG_IP_VS_SH_TAB_BITS=8

#
# IPVS application helper
#
CONFIG_IP_VS_FTP=m
CONFIG_IP_VS_NFCT=y
CONFIG_IP_VS_PE_SIP=m
```



## LVS集群中的术语

VS：Virtual Server，Load Balancer

RS：Real Server(LSV)，upstream server(nginx)，backend server(haproxy)

CIP：Client Server

VIP：Virtual server IP，面对用户的IP

DIP：Director IP，面对业务服务器的IP

RIP：Real Server IP

访问流程：CIP-->VIP-->DIP-->RIP

## LVS工作模式和相关命令

TCP/IP在各个层数据单位是什么？

应用层：报文

传输层：报文段

网络层：数据包

链路层：帧

### 1 LVS集群的工作模式

* lvs-nat：本质是多目标IP的DNAT；重点：对报文的修改！
* lvs-dr：Direct Routing 直接路由，基于数据链路层的MAC地址进行修改
* lvs-tun：tunnel，隧道，在原请求的IP报文之外新添加一个IP首部
* lvs-fullnat：修改请求报文的源和目标IP

#### LVS-NAT

本质：是多目标IP的DNAT，通过将请求报文中的目标地址和目标端口修改为根据调度算法选择出的一个RS的RIP和Port实现转发；同时把从RS回来的响应报文的目标地址和目标端口修改为客户端的IP和端口

特征：

> 1.RIP和DIP应该在同一个IP网络，且应该使用私网地址；RS的网关要指向DIP
>
> 2.请求报文和响应报文都必须经由Director转发，因此Director容易成为系统瓶颈
>
> 3.支持端口映射，可以修改请求报文的目标Port
>
> 4.因为使用的技术是Linux的内核技术LVS，因此Director必须是Linux操作系统，RS可以是任意系统
>
> 5.Director需要开启FORWORD选项，net.ipv4.ip_forward

画报文图，应该画两个，去方向一个图，回方向一个图

请求报文流程图：

![image-20201105223908434](C:\Users\a\AppData\Roaming\Typora\typora-user-images\image-20201105223908434.png)

响应报文流程图：

![image-20201105224836162](C:\Users\a\AppData\Roaming\Typora\typora-user-images\image-20201105224836162.png)



#### LVS-DR：最主流的使用模型、默认的模型

Direct Routing

工作方式：通过为请求报文重新封装一个MAC首部进行转发，源MAC是DIP所在的接口的MAC，目标MAC是根据调试算法挑选出的RS的RIP所在接口的MAC地址，需要注意的是，源IP/PORT以及目标IP/PORT是在整个请求过程中是不被改变的；当RS发送响应报文时，根本不经过Director，而是自己把这个响应报文发送给路由器，由路由器把响应报文发给客户端

特点：

> 1.DR模型可以降低LVS的负载压力，因为回复报文不需要经过LVS了
>
> 2.需要确保前端的路由器将目标IP为VIP的请求报文真的发送给Director而不是具有相同VIP的RS，方法大体上有三种：
>
> ​	1）在前端的路由器上做静态的IP和MAC地址的绑定，把VIP绑定到Director的MAC地址
>
> ​	2）在RS上使用arptables工具
>
> ​	3）在RS上修改内核参数，本质上是对绑定了VIP的网卡的arp协议的广播和接收进行了关闭
>
> ​	修改的参数是：/proc/sys/net/ipv4/conf/all/arp_ignore
>
> ​				 /proc/sys/net/ipv4/conf/all/arp_announce
>
> ​	上面的参数是对一个主机的arp的总开关，对于我们需要真正要修改的、VIP的网卡还需要开小开关
>
> ​				 /proc/sys/net/ipv4/conf/lo/arp_ignore
>
> ​				 /prof/sys/net/ipv4/conf/lo/arp_announce
>
> 3.RS的RIP可以使用私网地址，也可以是公网地址，只要RIP和DIP在同一个网络就行；RIP的网关不能指向DIP，以确保响应报文不会经由Director
>
> 4.RS和Director要在同一个物理网络
>
> 5.请求报文要经由Director，但响应报文不经由Director，而是由RS之间发送给路由器，路由器再发送给客户端
>
> 6.因为是对数据链路层的MAC地址的改变，因此不支持端口映射
>
> 7.Director不需要开启路由转发，因为数据不经过他的FORWARD链
>
> 8.因为使用的技术是Linux的内核技术LVS，因此Director必须是Linux操作系统，RS可以是大多数系统



LVS-DR模型中的重点问题：

> 如何解决IP地址冲突问题？--->地址冲突是因为arp的广播和接收，导致每个主机都会通知其他主机自己的IP和MAC的对应关系，而通过修改内核参数，关闭RS的arp广播和接收选项，而Director正常广播自己的VIP和MAC的对应关系，这样就不冲突了
>
> 支持端口映射吗？--->LVS-DR模型只修改数据链路层，因此不支持端口映射；
>
> 为什么Director和RS之间必须在交换机环境，不可以有路由器？--->因为LVS-DR模型是Director通过对请求报文中MAC地址的修改进行转发和调度的，而在转发的过程中是把目标MAC从Director改成了RS的MAC，因此Director和RS需要知道彼此的MAC地址，而MAC地址又是通过arp协议来获取的，而arp协议是通过广播来实现的，而广播又不能穿过路由器，因此，Director和RS要在同一个路由器下，所以他们中间不能是路由器
>
> 重点：对ARP的理解；免费ARP是？，自问自答，判断IP地址冲突；
>
> 根据ARP协议的工作流程，修改ARP协议中的发送和接收选项；修改的是内核参数
>
> 配置在回环网卡上，lo，网络地址稳定，不影响其他网卡



#### LVS-DR模型的数据流程图：



> **注意：Web服务器网关要指向防火墙（路由器），因为响应报文不需要经过LVS，而是Web服务器自己发往客户端**

> **注意：图中的防火墙提供了DNAT功能，把目标地址为172.30.0.200的请求都转发到了10.0.0.200上**

> 注意：图中我认为客户端不应该之间知道内网LVS的地址，因此使用了防火墙的DNAT，对于LVS来说，目标IP是没变过的，一致是VIP

> 注意：因为LVS-DR要让LVS和多台Web服务器使用一个相同的VIP，所以涉及地址冲突问题，但是可以通过修改所有Web服务器上的内核arp参数来解决这一问题，这样可以实现在这个局域网中，所有主机都认为拥有VIP地址的主机是LVS，因此防火墙会把报文先发送给LVS

> 注意：因为VIP是绑定在回环网卡lo上的，而lo网卡没有MAC地址，因此其实是使用了每个主机的其他网卡进行信息传输的，所以在报文中的MAC地址都是本机的其他网卡的

图中IP地址和MAC的对应关系

|    网卡IP    | MAC地址 |
| :----------: | :-----: |
| 172.30.0.100 |   5a    |
| 172.30.0.200 |   5b    |
|  10.0.0.100  |   5c    |
|  10.0.0.200  |   5d    |
|  10.0.0.130  |   5e    |
|  10.0.0.140  |   5f    |

请求报文的数据流：

![image-20201105231944974](C:\Users\a\AppData\Roaming\Typora\typora-user-images\image-20201105231944974.png)

响应报文的数据流：

![image-20201106082943359](C:\Users\a\AppData\Roaming\Typora\typora-user-images\image-20201106082943359.png)

#### LVS-TUN：为了跨网段通信

Tunnel

转发方式：Director不修改请求报文的IP首部（源IP为CIP，目标IP为VIP），而是在原IP报文之外再封装一个IP首部（源IP是DIP，目标IP是RIP）后，将报文发往由调度算法选出的目标RS；RS在发送响应报文时，将直接把报文发送给路由器，路由器再把报文发送回客户端，因此tun模式的响应报文也不经过Director

特点：

> 1.RIP和DIP可以不处于同一个物理网络中，RS的网关一般不能指向DIP，而是指向路由器。因此RS和Director是可以跨互联网的，DIP，RIP，VIP都可以是公网IP
>
> 2.RS的tun接口上需要配置VIP地址，以便于接收Director转发过来的数据包，以及作为响应的报文源IP
>
> 3.Director转发给RS时需要借助隧道，隧道外层的IP头部的源IP是DIP，目标IP是RIP，而RS响应给客户端的IP头是根据隧道内层的IP头分析得到的，源IP是VIP，目标IP是CIP
>
> 4.请求报文要经由Director，但响应不经由Director，响应由RS自己完成
>
> 5.不支持端口映射
>
> 6.RS的操作系统必须支持隧道功能
>
> 7.使用的很少，因为在广域网模式下使用代理服务比如nginx和DNS更多

#### LVS-FULLNAT模式：

转发原理：通过同时修改请求报文的源IP地址和目标IP地址进行转发

特点：

> 1.请求和响应报文都经由Director
>
> 2.支持端口映射
>
> 3.VIP是公网地址，RIP和DIP是私网地址，且通常不在同一个IP网络中，因此RIP的网关不指向DIP
>
> 4.相对NAT模式，可以更好地实现RS间跨VLAN通讯
>
> 5.这个模式Kernel默认不支持

#### LVS工作模式总结和比较

| 对比种类         | NAT              | TUN              | DR                                     |
| ---------------- | ---------------- | ---------------- | -------------------------------------- |
| RS的操作系统要求 | 任意操作系统     | 支持隧道         | 支持禁止arp广播和接收的系统            |
| RS所处的网络类型 | 私网             | 公网/私网        | 私网，而且必须与调度器在同一个路由器中 |
| 支持的RS数量     | 10~20            | 100+             | 100+                                   |
| RS的网关配置     | 需要指向调度器   | 指向自身的路由器 | 指向自身的路由器                       |
| 优点             | 可以进行端口转换 | 可以跨WAN        | 性能最好                               |
| 缺点             | 性能差           | 系统需要支持隧道 | 不可以跨网段                           |



### 2 LVS调试算法

Ipvs scheduler：根据其调度时是否考虑各RS当前的负载状态

根据其调度时是否考虑RS当前负载状态分为静态和动态算法

#### 1 静态算法

* RR：roundrobin，轮询，使用较多
* WRR：Weighted RR，加权轮询，使用较多
* SH：Source Hashing，源地址哈希，实现session sticky，会话绑定
* DH：Destination Hashing，目标地址哈希,典型使用场景是正向代理缓存场景中的负载均衡，比如Web缓存

#### 2 动态算法

根据后端RS的负载状态进行调度

活动连接：建立连接并且有数据交互

* LC：least connections 最短连接算法，适用于长连接

```
Overhead=activeConnections*256+inactiveConnections

```

* WLC：WeightedLC，带权重的最短连接算法，默认调度方法，较常用

```
Overhead=(activeConnections*256+inactiveConnections)/weight
```

* SED：Shortest Expection Delay，初始连接高权重优先，只检查活动连接，而不考虑非活动连接

```
Overhead=(activeConnections+1)*256/weight
```

* NQ：Never Queue，第一轮均匀分配，后续使用SED
* LBLC：Locallity-Based LC，动态的DH算法
* LBLCR：LBLC with Replication，带复制功能的LBLC，解决LBLC负载不均衡的问题
* 内核版本4.15之后新增调度算法：FO和OVF



# 3 LVS相关软件

## 1 ipvsadm

程序包：ipvsadm

主程序：/usr/sbin/ipvsadm

规则保存程序：/usr/sbin/ipvsadm-save

规则加载工具：/usr/sbin/ipvsadm-restore

配置文件：/etc/sysconfig/ipvsadm-config

调度规则文件：/etc/sysconfig/ipvsadm

```
yum -y install ipvsadm
[root@node_7 ~]$rpm -ql ipvsadm
/etc/sysconfig/ipvsadm-config
/usr/lib/systemd/system/ipvsadm.service
/usr/sbin/ipvsadm
/usr/sbin/ipvsadm-restore
/usr/sbin/ipvsadm-save
/usr/share/doc/ipvsadm-1.27
/usr/share/doc/ipvsadm-1.27/README
/usr/share/man/man8/ipvsadm-restore.8.gz
/usr/share/man/man8/ipvsadm-save.8.gz
/usr/share/man/man8/ipvsadm.8.gz

```



## 2 ipvsadm 使用

ipvsadm与iptables很像，他们的服务开启都是加载规则，所以不需要开服务，只需要写规则，他们都是对内核功能的调用

核心功能：

* 集群的管理：增加、删除、修改
* 集群中业务服务器的管理：增加、删除、修改
* 查看：`ipvsadm -Ln`

#### 创建一个完整的集群的步骤：

分两步：

第一步：创建集群

```
ipvsadm -A -t VIP:port -s 调度算法
-A：--add-service add virtual service with options 表示添加虚拟服务器
-t：--tcp-service service-address is host[:port]  添加tcp协议的服务器IP和端口
-s：scheduler one of rr|wrr|lc|wlc|lblc|lblcr|dh|sh|sed|nq,the default scheduler 	is wlc.
```

例子：

```
ipvsadm -A -t 172.30.0.200:80 -s rr
```

第二步：添加集群中的服务器

```
ipvsadm -a -t VIP:port -r RS的IP:RS的端口 -工作模式
-a：--add-server add real server with options 表示添加真实的业务服务器
-t：添加tcp协议的服务器的IP和端口
工作模式：
-m：masquerading (NAT) NAT模式
-g：gatewaying (direct routing) (default) DR模式
-i：ipip encapsulation (tunneling) TUN模式
```

例子：

```
ipvsadm -a -t 172.30.0.200:80 -r 10.0.0.7:80 -m
ipvsadm -a -t 172.30.0.200:80 -r 10.0.0.14:80 -m
```

#### 集群的管理操作：

增加、修改

```
ipvsadm -A|E -t|u|f service-address [-s scheduler] [-p [timeout]]
-A：增加虚拟服务
-E：修改虚拟服务
-t：使用tcp协议  -u：使用udp  -f：firewall Mark，防火墙标记，是一个数字
-s：使用的调度算法
-p：持久连接的保存时间，-p 后面不跟时间就是代表360秒
```

删除：

```
ipvsadm -D -t|u|f service-address
```

#### 集群中的RS的增、删、改：

增、改：

```
ipvsadm -a|e -t|u|f service-address -r server-address [-g|i|m] [-w weight]
-a：增加RS服务器
-e：修改RS服务器
-t|u|f：tcp,udp,firewall mark
-r：real server 的IP和Port
-g：DR模式，默认模式
-i：TUN模式
-m：NAT模式
-w：权重
```

删除：

```
ipvsadm -d -t|u|f service-address -r server-address
```

#### 清空集群命令：

```
ipvsadm -C
```

#### 清空计数器：

```
ipvsadm -Z [-t|u|f service-address]
```

#### 保存规则：建议保存到/etc/sysconfig/ipvsadm

```bash
ipvsadm-save > /etc/sysconfig/ipvsadm
或者
ipvsadm -S > /etc/sysconfig/ipvsadm
或者
systemctl stop ipvsadm.service #这个service文件中调用的命令有保存
```

#### 载入规则：会自动加载/etc/sysconfig/ipvsadm

```bash
ipvsadm-restore < /path/from/ipvsadm_file
或者
systemctl start ipvsadm.service #会自动加载/etc/sysconfig/ipvsadm
```

#### 防火墙标记

FWM：FireWall Mark

Mark target 可用于给特定的报文打标记，--set-mark value，其中value可以是十六进制数字

工作原理：借助于防火墙标记来分类报文，而后基于标记定义集群服务，可以将多个不同的应用使用同一个集群服务进行调度

实现方法：

在Director主机打标记：

```
iptables -t mangle -A PREROUTING -d ${VIP} -p ${protocol} -m multiport --dport ${port1},${port2},... -j MARK --set-mark NUMBER
```

之后在ipvsadm中可以直接利用这个标记来标记集群

```
ipvsadm -A -f NUMBER [options]
```

例子：



#### LVS持久连接

session绑定：对共享同一组RS的多个集群服务，需要统一进行绑定，lvs sh算法无法实现

持久连接（lvs persistence）模板：实现无论使用任何调度算法，在一段时间内（默认360s），能够实现将来自同一个地址的请求始终发往同一个RS

```
ipvsadm -A|E -t|u|f service-address [-s scheduler] [-p [timeout]]
使用-p选项就代表了持久连接，默认是360秒
```

持久连接的实现方法：

* 按照端口，PPC，每端口持久，每个端口定义为一个集群服务，每个集群服务单独调度
* 按照防火墙标记，PFWMC，每防火墙标记持久，基于防火墙标记定义集群服务，可以实现将多个端口上的应用同意调度，即port Affinity

例子：





## 3 LVS的操作实例

### 1 NAT模式的操作

环境说明：

![image-20201105153045726](C:\Users\a\AppData\Roaming\Typora\typora-user-images\image-20201105153045726.png)

操作步骤

#### 第一步：环境配置

1.准备两个网段，

2.配置IP地址

3.这个图里画了防火墙，但是其实防火墙和LVS是一台主机

配置192段主机的网关

```
先把原来的指向0.0.0.0的默认路由删掉
ip route del default dev eth0 
然后把默认路由指向防火墙一侧
ip route add default dev eth0 via 172.30.0.200
```

配置10段主机的网关，这个网关是指向Director的，因为响应报文要先发给Director进行处理

```
先把原来的指向0.0.0.0的默认路由删掉
ip route del default dev eth0 
然后把默认路由指向防火墙一侧
ip route add default dev eth0 via 10.0.0.100
```

4.注意一点，防火墙两边的主机的网关都要指向防火墙，而且防火墙上不要配置Iptables规则，尤其是nat表的规则，因为LVS的ipvsadm是作用在INPUT表的

5.防火墙要开启路由转发功能 

```
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p;让sysctl.conf的内容生效
```



#### 第二步：LVS的操作

```
[root@node_7 ~]$yum install ipvsadm
[root@node_7 ~]$ipvsadm -A -t 172.30.0.200:80 -s rr
[root@node_7 ~]$ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  172.30.0.200:80 rr
[root@node_7 ~]$ipvsadm -a -t 172.30.0.200:80 -r 10.0.0.7:80 -m
[root@node_7 ~]$ipvsadm -a -t 172.30.0.200:80 -r 10.0.0.14:80 -m
[root@node_7 ~]$ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  172.30.0.200:80 rr
  -> 10.0.0.7:80                  Masq    1      0          0         
  -> 10.0.0.14:80                 Masq    1      0          0 
```

#### 第三步：在外网进行访问

```
[root@node_7 ~]$curl 172.30.0.200
Hello,my friends!,this is 14
[root@node_7 ~]$curl 172.30.0.200
Hello,my friends! this is 7
[root@node_7 ~]$curl 172.30.0.200
Hello,my friends!,this is 14
[root@node_7 ~]$curl 172.30.0.200
Hello,my friends! this is 7

```

测试成功！

保存规则：

```
ipvsadm-save > /etc/sysconfig/ipvsadm
```

清除规则

```
ipvsadm -C
```

重新导入规则

```
ipvsadm-restore < /etc/sysconfig/ipvsadm
```

设置开机自动导入规则

```
systemctl enable ipvsadm.service
前提是保存的规则文件确实是/etc/sysconfig/ipvsadm才行，为什么，因为ipvsadm.service文件里面是：
  7 ExecStart=/bin/bash -c "exec /sbin/ipvsadm-restore < /etc/sysconfig/ipvsadm"
  8 ExecStop=/bin/bash -c "exec /sbin/ipvsadm-save -n > /etc/sysconfig/ipvsadm"
  9 ExecStop=/sbin/ipvsadm -C

```



### 2.DR模式的操作

#### 杂谈：

单网段和多网段

LVS也需要配置一个路由

网络环境的配置尽量按照一个方向配置

修改内核参数需要修改ALL和lo网卡

如何永久添加一个网卡上的两个IP：

```
nmcli connection modify eth0 +ipv4.address 172.16.0.200/24 ifname eth0
其实就是在ifcfg-eth0的配置文件中添加了ipaddr1=172.16.0.200 prefix1=24 这样的行
```

#### LVS-DR单网段

DR模型中LVS和各个RS主机上都需要配置VIP，但是他们不是同一台主机，因此会出现一个VIP地址有三个MAC地址的问题，也就是地址冲突问题，所以要解决这个问题，解决这个问题的方法大概有三种：

1）在前端的路由器上做VIP地址和LVS服务器MAC的绑定

2）在各个RS上使用arptables工具

3）在各个RS上修改内核参数（arp的广播和接收），来限制arp响应和通告的级别

方法一存在问题，那就是每当更换LVS服务器时，都需要修改路由器上的绑定关系，因此不推荐使用

方法二的配置还需要学习，因此暂时不用，arptables的思路与iptables思路一样，只不过协议变了

方法三好配置，因此推荐使用

需要修改的内核参数：arp_ignore,arp_announce

**注意：这两个参数都是有一个总的配置和每个网卡上的配置，因此修改的时候需要修改总的配置和需要配置VIP的网卡的配置**

>  arp_ignore：限制响应级别
>
> * 0：默认值，表示可以使用本地任意接口上配置的任意地址进行响应
> * 1：仅在请求的目标IP配置在本地主机的接收请求报文的接口上时，才给予响应

> arp_announce：限制通告级别
>
> * 0：默认值，把本机所有接口的所有信息向每个接口的网络进行通告
> * 1：尽量避免将接口信息向非直接连接的网络进行通告
> * 2：必须避免将接口信息向非本网络进行通告

范例1：

环境：

![image-20201105161821292](C:\Users\a\AppData\Roaming\Typora\typora-user-images\image-20201105161821292.png)



环境准备：5台主机，两个网段，注意网关的配置，每个主机的网关都要指向路由器，路由器要开启路由转发

**注意：LVS服务器和两台RS服务器上，都要配置VIP，VIP都配置到lo网卡上**

配置网络环境中最主要的命令：

修改路由：

```
ip route del default dev eth0
ip route add default dev etho via 10.0.0.100
```

查看路由

```
route -n
或者
ip route
```

添加IP地址

```
ip address add 10.0.0.200/32 dev lo
```



步骤：

1.两台RS的配置，即arp参数的修改

```
➜  ~ echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore 
➜  ~ echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce 
➜  ~ echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore 
➜  ~ echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce

```

2.LVS服务器的配置

```
➜  ~ ipvsadm -A -t 10.0.0.200:80 -s wrr
➜  ~ ipvsadm -a -t 10.0.0.200:80 -r 10.0.0.7:80 -g 
➜  ~ ipvsadm -a -t 10.0.0.200:80 -r 10.0.0.14:80 -g

```

3.172网段的主机进行访问测试

```
[root@node_7 ~]$curl 10.0.0.200
Hello,my friends!,this is 14
[root@node_7 ~]$curl 10.0.0.200
Hello,my friends!,this is 7
[root@node_7 ~]$curl 10.0.0.200
Hello,my friends!,this is 14
[root@node_7 ~]$curl 10.0.0.200
Hello,my friends!,this is 7
```

测试成功

想要对LVS-DR模式的修改MAC地址进行了解，那么就抓包查看

首先开启抓包软件，然后监听NAT网卡，也就是VMNET8，然后在172.30.0.100上curl；

注意：因为抓的是VMNET8网段，所以看不到172主机与路由器之间的通讯，下面我们看到的通讯已经经过了路由器的转发了，也就是说，172.30.0.100这个IP所带的MAC其实已经是路由器的MAC了

```
curl 10.0.0.200
```

![image-20201105174819989](C:\Users\a\AppData\Roaming\Typora\typora-user-images\image-20201105174819989.png)

下面对这个报文进行分析

> 1.请求报文： SRC 172.30.0.100 SRC-MAC 8a DEST 10.0.0.200 DEST-MAC 0d
> 2.请求报文： SRC 172.30.0.100 SRC-MAC 0d DEST 10.0.0.200 DEST-MAC a5
> 3.响应报文： SRC 10.0.0.200 SRC-MAC a5 DEST 172.30.0.100 DEST-MAC 8a

通过对报文的分析，可以看到：

首先，172主机向10.0.0.200的IP地址发起请求，这个时候的10.0.0.200的MAC是LVS主机

然后，LVS主机根据调度算法，向一个MAC地址是a5（IP是10.0.0.14）的主机转发了这个报文，可以注意到，此时的源IP地址和源MAC并没有改变，目标IP也没有改变，但是目标MAC改变了

最后，10.0.0.14主机向172.30.0.100主机发出响应报文，此时可以看到，源IP地址是10.0.0.200，源MAC是10.0.0.14的MAC，目标IP是172.30.0.100，目标MAC是路由器的MAC



#### LVS-DR模式多网段

环境搭建

![image-20201105191226209](C:\Users\a\AppData\Roaming\Typora\typora-user-images\image-20201105191226209.png)



这个实验与上一个实验的区别就是对VIP是一个与RS服务器不在同一个网段的IP，因此在路由器上需要增加一个192.168.0.0/24的地址；还有一个区别，那就是LVS服务器的网关，这个网关其实是没用的，因为它接收到报文后，通过修改MAC的方式调度到RS服务器上了，它不需要跨网段通信，但是不设置这个网关还真不行，随便设置一个就行

在这里还碰到了问题，那就是通过命令临时添加的路由和IP会自动消失（虚拟机环境），因此我写到了配置文件中，给一个网卡上永久保存两个IP的命令是：

```
nmcli connection modify eth0 +ipv4.address 192.168.0.200/24 ifname eth0
```

这个命令其实是修改了ifcfg-eth0的配置文件，所以也需要通过命令重新加载网卡配置文件

```
nmcli connection reload
nmcli connection up eth0
```

查看ifcfg-eth0文件

```
  1 DEVICE=eth0                                                                  
  2 NAME=eth0
  3 ONBOOT=yes
  4 BOOTPROTO=static
  5 IPADDR=10.0.0.100
  6 NETMASK=255.255.255.0
  7 GATEWAY=10.0.0.1
  8 DNS1=180.76.76.76
  9 DNS2=223.6.6.6
 10 TYPE=Ethernet
 11 PROXY_METHOD=none
 12 BROWSER_ONLY=no
 13 PREFIX=24
 14 IPADDR1=192.168.0.200
 15 PREFIX1=24
 16 NETMASK1=255.255.255.0
 17 DEFROUTE=yes
 18 IPV4_FAILURE_FATAL=no
 19 IPV6INIT=no
 20 UUID=5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03

```

脚本：

自动配置LVS服务器、RS服务器，其实就是修改arp内核参数，配置VIP到lo网卡上

### 3.tunnel模式的操作

ip addr add xxxx dev tunl0

ip link set tunl0 up



防火墙标记

使用mangle表的标记



LVS的持久连接

一段时间内让一个用户访问同一个业务服务器，这样可以保留session信息

这个时间可以设置









## 4 LVS的高可用

使用keepalive实现LVS的高可用

### LVS的两个痛点：

高可用的解决方法：

Keepalive，使用一个虚拟IP，谁工作，VIP就是谁的



对业务服务器状态无法感知的解决方法：

KeepAlive，定期检查业务服务器的状态









要求：LVS-DR模型操作

在实验中加入LVS+

