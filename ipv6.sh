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
    
    # Cấu hình mạng cho Ubuntu
    cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true
      accept-ra: true
      addresses:
        - "${IP4}/24"
        - "${IPV6ADDR}/64"
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

    # Áp dụng cấu hình mạng
    netplan apply

    # Kiểm tra kết nối IPv6
    if ip -6 route get ${IPV6ADDR}::8888 &> /dev/null; then
        echo "Kết nối IPv6 hoạt động."
    else
        echo "Lỗi: Kết nối IPv6 không hoạt động."
    fi

    # Cấu hình tường lửa để cho phép kết nối từ địa chỉ IP4
    ufw allow from ${IP4} to any

else
    echo "Lỗi: Không tìm thấy card mạng eth0."
fi
rm -fr ipv6.sh
