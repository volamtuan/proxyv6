#!/bin/bash

# Hàm để lấy địa chỉ IPv6
get_ipv6_address() {
    local id=$1
    ip -6 addr show | grep -oP '(?<=inet6\s)[\da-fA-F:]+(?=/64)' | head -n $id | tail -n 1
}

# Tự động lấy địa chỉ IPv4 từ thiết bị
IP4=$(ip addr show | grep -oP '(?<=inet\s)192(\.\d+){2}\.\d+' | head -n 1)

# Tự động lấy địa chỉ IPv6
IPV6ADDR=$(get_ipv6_address 1)

if ip link show eth0 &> /dev/null; then
    echo "Card mạng eth0 đã được tìm thấy."
    
cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
TYPE=Ethernet
NAME=eth0
DEVICE=eth0
ONBOOT=yes
BOOTPROTO=dhcp
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=eui64
IPADDR="${IP4}"
NETMASK=255.255.255.0
GATEWAY=192.168.1.1
DNS1=8.8.8.8
DNS2=8.8.4.4
IPV6ADDR="${IPV6ADDR}/64"
IPV6_DEFAULTGW="${IPV6ADDR}::1"
EOF

    # Khởi động lại dịch vụ mạng
    systemctl restart network

    # Kiểm tra kết nối IPv6
    if ip -6 route get ${IPV6ADDR}::8888 &> /dev/null; then
        echo "Kết nối IPv6 hoạt động."
    else
        echo "Lỗi: Kết nối IPv6 không hoạt động."
    fi

    # Cấu hình tường lửa để cho phép kết nối từ địa chỉ IP4
    firewall-cmd --zone=public --add-source="${IP4}" --permanent
    firewall-cmd --reload
else
    echo "Lỗi: Không tìm thấy card mạng eth0."
fi
