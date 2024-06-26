#!/bin/bash

# Kiểm tra hệ thống có sử dụng YUM hay không
YUM=$(which yum)

# Nếu hệ thống sử dụng YUM (CentOS, RHEL)
if [ "$YUM" ]; then
    echo > /etc/sysctl.conf
    tee -a /etc/sysctl.conf <<EOF
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.disable_ipv6 = 0
EOF
    sysctl -p

    IPC=$(curl -4 -s icanhazip.com | cut -d"." -f3)
    IPD=$(curl -4 -s icanhazip.com | cut -d"." -f4)
    NETWORK_INTERFACE_NAME=$(ip route get 8.8.8.8 | sed -nr 's/.*dev ([^\ ]+).*/\1/p')

    if [ $IPC == 4 ]; then
        tee -a /etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE_NAME <<-EOF
IPV6INIT=yes
IPV6_AUTOCONF=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
IPV6ADDR=2403:6a40:0:40::$IPD:0000/64
IPV6_DEFAULTGW=2403:6a40:0:40::1
EOF
    elif [ $IPC == 5 ]; then
        tee -a /etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE_NAME <<-EOF
IPV6INIT=yes
IPV6_AUTOCONF=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
IPV6ADDR=2403:6a40:0:41::$IPD:0000/64
IPV6_DEFAULTGW=2403:6a40:0:41::1
EOF
    elif [ $IPC == 244 ]; then
        tee -a /etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE_NAME <<-EOF
IPV6INIT=yes
IPV6_AUTOCONF=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
IPV6ADDR=2403:6a40:2000:244::$IPD:0000/64
IPV6_DEFAULTGW=2403:6a40:2000:244::1
EOF
    else
        tee -a /etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE_NAME <<-EOF
IPV6INIT=yes
IPV6_AUTOCONF=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
IPV6ADDR=2403:6a40:0:$IPC::$IPD:0000/64
IPV6_DEFAULTGW=2403:6a40:0:$IPC::1
EOF
    fi

    service network restart

# Nếu hệ thống sử dụng APT (Ubuntu)
else
    ipv4=$(curl -4 -s icanhazip.com)
    IPC=$(curl -4 -s icanhazip.com | cut -d"." -f3)
    IPD=$(curl -4 -s icanhazip.com | cut -d"." -f4)
    INTERFACE=$(ls /sys/class/net | grep e)
    
    if [ "$IPC" = "4" ]; then
        IPV6_ADDRESS="2403:6a40:0:40::$IPD:0000/64"
        GATEWAY="2403:6a40:0:40::1"
    elif [ "$IPC" = "5" ]; then
        IPV6_ADDRESS="2403:6a40:0:41::$IPD:0000/64"
        GATEWAY="2403:6a40:0:41::1"
    elif [ "$IPC" = "244" ]; then
        IPV6_ADDRESS="2403:6a40:2000:244::$IPD:0000/64"
        GATEWAY="2403:6a40:2000:244::1"
    else
        IPV6_ADDRESS="2403:6a40:0:$IPC::$IPD:0000/64"
        GATEWAY="2403:6a40:0:$IPC::1"
    fi
    
    interface_name="$INTERFACE"
    ipv6_address="$IPV6_ADDRESS"
    gateway6_address="$GATEWAY"

    if [ "$INTERFACE" = "ens33" ]; then
        netplan_path="/etc/netplan/99-netcfg-vmware.yaml"
    elif [ "$INTERFACE" = "eth0" ]; then
        netplan_path="/etc/netplan/50-cloud-init.yaml"
    else
        echo 'Không có card mạng phù hợp'
        exit 1
    fi

    netplan_config=$(cat "$netplan_path")
    new_netplan_config=$(sed "/gateway4:/i \ \ \ \ \ \ \ \ \ \ \ \ - $ipv6_address" <<< "$netplan_config")
    new_netplan_config=$(sed "/gateway4:.*/a \ \ \ \ \ \ \ \ \ \ \ \ gateway6: $gateway6_address" <<< "$new_netplan_config")

    echo "$new_netplan_config" > "$netplan_path"
    
    sudo netplan apply
fi

echo 'Đã tạo IPv6 thành công!'
