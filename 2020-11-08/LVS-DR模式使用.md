### 1.DR模式下VIP不在同一网段上实现过程

![image-20201108110910045](C:\Users\a\AppData\Roaming\Typora\typora-user-images\image-20201108110910045.png)

实验：使用LVS的DR模式实现对后台Web服务器访问的调度管理，从而实现负载均衡的目标

实验步骤：

1.环境准备

2.RS的http服务搭建

3.lvs配置

4.访问测试



开始：

1.环境配置：操作是修改IP和路由

本次实验用到了三个网段，其中VIP只需要路由器添加一个IP地址即可，不需要单独一个网卡，因此需要用到在VMware中使用两个网络，172.30.0.0/24和192.168.16.0/24

没有按照图片网段进行配置的原因：因为我们本地网段都是172.16.0.0/16，所以我换了一个网段

把客户端配置为：172.30.0.100/24，路由指向172.30.0.200/24

```
vim /etc/sysconfig/network-scripts/ifcfg-eth0
  1 DEVICE=eth0
  2 NAME=eth0                                                                                 
  3 ONBOOT=yes
  4 BOOTPROTO=static
  5 IPADDR=172.30.0.100
  6 NETMASK=255.255.255.0
  
  ip route add default dev eth0 via 172.30.0.200

```

路由器配置：路由器需要两个网卡、三个IP

```
vim /etc/sysconfig/network-scripts/ifcfg-eth0
  1 DEVICE=eth0
  2 NAME=eth0
  3 ONBOOT=yes
  4 BOOTPROTO=static
  5 IPADDR=192.168.16.7                                        
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
 vim /etc/sysconfig/network-scripts/ifcfg-eth1
  1 DEVICE=eth1
  2 NAME=eth1
  3 ONBOOT=yes
  4 BOOTPROTO=static
  5 IPADDR=172.30.0.200                                         
  6 NETMASK=255.255.255.0
```

两个RS服务器的真实IP和路由配置，路由应该指向路由器，因为响应报文是由RS自己发送给客户端的

RS1

```
vim /etc/sysconfig/network-scripts/ifcfg-eth0
  2 NAME="eth0"
  3 DEVICE="eth0"
  4 ONBOOT=yes
  5 NETBOOT=yes
  6 BOOTPROTO=static
  7 TYPE=Ethernet
  8 IPADDR=192.168.16.17                                         
  9 PREFIX=24
 10 GATEWAY=192.168.16.7
 11 DNS1=223.5.5.5
 12 DNS2=180.76.76.76


```

RS2

```
vim /etc/sysconfig/network-scripts/ifcfg-eth0
  2 NAME="eth0"
  3 DEVICE="eth0"
  4 ONBOOT=yes
  5 NETBOOT=yes
  6 BOOTPROTO=static
  7 TYPE=Ethernet
  8 IPADDR=92.168.16.27  
  9 PREFIX=24
 10 GATEWAY=192.168.16.7
 11 DNS1=223.5.5.5
 12 DNS2=180.76.76.76
```

Director设置IP

```
  1 NAME="eth0"
  2 DEVICE="eth0"
  3 ONBOOT=yes
  4 NETBOOT=yes
  5 UUID="86c4af5e-8ff6-4de3-a55a-669460dc9f60"
  6 IPV6INIT=yes
  7 BOOTPROTO=static
  8 TYPE=Ethernet
  9 IPADDR=192.168.16.8
 10 PREFIX=24
 11 GATEWAY=192.168.16.7                         
 12 DNS1=223.5.5.5
 13 DNS2=180.76.76.76
```

2.RS的http服务搭建

在两台RS服务器上都搭建http服务，使用apache来实现

RS1

```
yum -y install httpd
systemctl start httpd
echo "This is RS1" > /var/www/html/index.html
```

RS2

```
yum -y install httpd
systemctl start httpd
echo "This is RS2" > /var/www/html/index.html
```

访问测试：

```
curl 192.168.16.17
This is RS1
curl 92.168.16.27
This is RS2
```

3.lvs配置：操作主要是给Director和RS添加VIP、在Director上配置lvs规则

1）在Director和RS上执行添加VIP的指令，这是临时添加的方法，把VIP添加到回环网卡上

```
ip addr add 10.0.0.100/32 dev lo
```

2）在Director安装ipvsadm并配置规则，这里我写了一个脚本，利用脚本去实现

```
#!/bin/bash
#配置LVS服务器和RS服务器

#定义变量
DATE=`date +%F_%H_%M_%S`
#定义调度算法，我默认设置了wrr
Scheduler="wrr"
#定义工作模式，我默认设置了LVS-DR
Method="-g"

#定义函数
function config_lvs() {
	read -p "请输入要加入集群的RS的IP和端口，格式是IP:Port，有几个RS就写几个，每个RS之间用空格分隔,这个变量是个数组：" -a RealServers
	rpm -ql ipvsadm &>/dev/null || yum -y install ipvsadm &>/dev/null 
	if [ $? -ne 0 ];then
		echo "ipvsadm下载安装失败，请检查yum环境"
		exit 9
	fi
	iptables-save > /etc/sysconfig/iptables_old_version_${DATE}.bak
	iptables -F &>/dev/null
	ipvsadm-save > /etc/sysconfig/ipvsadm_old_version_${DATE}.bak
	ipvsadm -C &>/dev/null
	ipvsadm -A -t ${VirtualService} -s ${Scheduler}
	for i in ${RealServers[@]};do
		ipvsadm -a -t ${VirtualService} -r ${i} ${Method}
	done
	echo "iptables规则已经被清空，备份放在了/etc/sysconfig/iptables_old_version_${DATE}.bak"
	echo "原来的ipvsadm已经被清空，备份放在了/etc/sysconfig/ipvsadm_old_version_${DATE}.bak"
	echo "lvs已配置完成，下面是当前的配置："
	ipvsadm -Ln
}

function config_rs() {
	echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore
	echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore
	echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce
	echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce
}

function add_vip() {
	rpm -ql iproute &>/dev/null || yum -y install iproute &>/dev/null
	if [ $? -ne 0 ];then
		echo "iproute下载安装失败，请检查yum环境"
		exit 9
	fi	
	ip addr add ${VirtualService%:*}/32 dev lo label lo:10
}

function remove_all() {
	ipvsadm-save > /etc/sysconfig/ipvsadm_${DATE}.bak &>/dev/null
	ipvsadm -C &>/dev/null
	echo 0 > /proc/sys/net/ipv4/conf/all/arp_ignore
	echo 0 > /proc/sys/net/ipv4/conf/lo/arp_ignore
	echo 0 > /proc/sys/net/ipv4/conf/all/arp_announce
	echo 0 > /proc/sys/net/ipv4/conf/lo/arp_announce
    ip addr del ${VirtualService%:*}/32 dev lo
	echo "ipvsadm相关配置清除完成"
	echo "ipvsadm的配置文件保存在/etc/sysconfig/ipvsadm_${DATE}.bak"
}


#根据位置变量来调用函数
echo "这个脚本有默认选择，协议是TCP，工作模式是LVS-DR，调度算法是wrr"
echo "这个脚本的修改都是使用命令临时修改的，如果要永久生效，需要写入文件中"
echo -e  "Usage:\nbash $0 lvs | rs | clean\nlvs：配置LVS服务器\nrs：配置RS服务器\nclean：清除所有配置"
read -p "你要利用这个脚本的什么功能？" Option
case ${Option} in
	lvs)
	read -p "请输入集群的VIP和Port：" VirtualService
	config_lvs
	add_vip
	;;
	rs)
	read -p "请输入集群的VIP和Port：" VirtualService
	config_rs
	add_vip
	;;
	clean)
	read -p "请输入集群的VIP和Port：" VirtualService
	remove_all
	;;
	*)
	echo "请输入正确的参数！"
	exit
	;;
esac

```



在lvs上跑脚本：

```
➜  ~ bash configure_lvs.sh 
这个脚本有默认选择，协议是TCP，工作模式是LVS-DR，调度算法是wrr
这个脚本的修改都是使用命令临时修改的，如果要永久生效，需要写入文件中
Usage:
bash configure_lvs.sh lvs | rs | clean
lvs：配置LVS服务器
rs：配置RS服务器
clean：清除所有配置
你要利用这个脚本的什么功能？lvs
请输入集群的VIP和Port：10.0.0.100:80
请输入要加入集群的RS的IP和端口，格式是IP:Port，有几个RS就写几个，每个RS之间用空格分隔,这个变量是个数组：192.168.16.17:80 92.168.16.27:80
iptables规则已经被清空，备份放在了/etc/sysconfig/iptables_old_version_2020-11-08_11_32_53.bak
原来的ipvsadm已经被清空，备份放在了/etc/sysconfig/ipvsadm_old_version_2020-11-08_11_32_53.bak
lvs已配置完成，下面是当前的配置：
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.0.0.100:80 wrr
  -> 192.168.16.17:80                 Route   1      0          0         
  -> 92.168.16.27:80                 Route   1      0          0    
```

配置成功

在RS上跑脚本

```
[root@node_7 ~]$bash configure_lvs.sh 
这个脚本有默认选择，协议是TCP，工作模式是LVS-DR，调度算法是wrr
这个脚本的修改都是使用命令临时修改的，如果要永久生效，需要写入文件中
Usage:
bash configure_lvs.sh lvs | rs | clean
lvs：配置LVS服务器
rs：配置RS服务器
clean：清除所有配置
你要利用这个脚本的什么功能？rs
请输入集群的VIP和Port：10.0.0.100:80
```

配置成功

4.测试，如果可以实现在客户端访问VIP，可以看到RS1和RS2，那么就是成功

在客户端访问：

```
[root@node_7 ~]$curl 10.0.0.100
This is RS1
[root@node_7 ~]$curl 10.0.0.100
This is RS2
[root@node_7 ~]$curl 10.0.0.100
This is RS1
[root@node_7 ~]$curl 10.0.0.100
This is RS2
```

可以看到客户端访问的时候RS1和RS2都能访问，测试成功