#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
	ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
	echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Hàm kiểm tra và chọn tên giao diện mạng tự động
auto_detect_interface() {
    INTERFACE=$(ip -o link show | awk -F': ' '$3 !~ /lo|vir|^[^0-9]/ {print $2; exit}')
}

# Get IPv6 address
ipv6_address=$(ip addr show eth0 | awk '/inet6/{print $2}' | grep -v '^fe80' | head -n1)

# Check if IPv6 address is obtained
if [ -n "$ipv6_address" ]; then
    echo "IPv6 address obtained: $ipv6_address"

    # Declare associative arrays to store IPv6 addresses and gateways
    declare -A ipv6_addresses=(
        [4]="2600:2d00:$IPD:0000/64"
        [5]="2600:2d00:$IPD:0000/64"
        [244]="2600:2d00:$IPD:0000/64"
        ["default"]="2600:2d00:$IPC::$IPD:0000/64"
    )

    declare -A gateways=(
        [4]="2600:2d00:$IPC::1"
        [5]="2600:2d00:$IPC::1"
        [244]="2600:2d00:$IPC::1"
        ["default"]="2600:2d00:$IPC::1"
    )

    # Get IPv4 third and fourth octets
    IPC=$(echo "$ipv6_address" | cut -d":" -f5)
    IPD=$(echo "$ipv6_address" | cut -d":" -f6)

    # Set IPv6 address and gateway based on IPv4 third octet
    IPV6_ADDRESS="${ipv6_addresses[$IPC]}"
    GATEWAY="${gateways[$IPC]}"

    # Check if interface is available
    INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1)

    if [ -n "$INTERFACE" ]; then
        echo "Configuring interface: $INTERFACE"

        # Configure IPv6 settings
        echo "IPV6_ADDR_GEN_MODE=stable-privacy" >> /etc/network/interfaces
        echo "IPV6ADDR=$ipv6_address/64" >> /etc/network/interfaces
        echo "IPV6_DEFAULTGW=$GATEWAY" >> /etc/network/interfaces

        # Restart networking service
        service networking restart

        ifconfig "$INTERFACE"
        echo "Done!"
    else
        echo "No network interface available."
    fi
else
    echo "No IPv6 address obtained."
fi

# Kiểm tra kết nối IPv6
ping6 -c 4 ipv6.google.com

# Hàm cài đặt 3proxy
install_3proxy() {
    echo "Bắt đầu cài đặt 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    wget -qO- $URL | tar -xzvf- >/dev/null 2>&1
    cd 3proxy-3proxy-0.8.6 || exit 1
    make -f Makefile.Linux >/dev/null 2>&1
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat} >/dev/null 2>&1
    cp src/3proxy /usr/local/etc/3proxy/bin/ >/dev/null 2>&1
    systemctl enable 3proxy
    echo "* hard nofile 999999" >>  /etc/security/limits.conf
    echo "* soft nofile 999999" >>  /etc/security/limits.conf
    echo "net.ipv6.conf.$main_interface.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
    sysctl -p
    systemctl stop firewalld
    systemctl disable firewalld
    cd $WORKDIR || exit 1
    echo "Cài đặt 3proxy hoàn tất."
}

# Hàm tải file proxy.txt
download_proxy() {
    cd $WORKDIR || return
    curl -F "file=@proxy.txt" https://file.io
}

# Hàm cấu hình 3proxy
gen_3proxy() {
    cat <<EOF
daemon
maxconn 10000
nserver 1.1.1.1
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456
flush
auth none

allow 14.224.163.75
allow 127.0.0.1

$(awk -F "/" '{print "auth none\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

# Hàm tạo file proxy.txt cho người dùng
gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4}' ${WORKDATA})
EOF
}

# Hàm tạo dữ liệu
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "//$IP4/$port/$(gen64 $ipv6_address)"
        echo "$IP4:$port" >> "$WORKDIR/ipv4.txt"
        echo "$(gen64 $ipv6_address)" >> "$WORKDIR/ipv6.txt"
    done
}

# Hàm tạo iptables
gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

# Hàm cấu hình ifconfig
gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

install_3proxy
echo "Thiết Lập Thư Mục"
WORKDIR="/home/proxy"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
if [ -z "$IP6" ]; then
    echo "Không lấy được địa chỉ IPv6. Kiểm tra lại kết nối IPv6."
    exit 1
fi
echo "Internal IP = ${IP4}. External sub for IPv6 = ${IP6}"
FIRST_PORT=40000
LAST_PORT=44444

echo "Cổng proxy: $FIRST_PORT"
echo "Số lượng proxy tạo: $(($LAST_PORT - $FIRST_PORT + 1))"

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x $WORKDIR/boot_*.sh /etc/rc.local
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -u unlimited -n 999999 -s 16384
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod +x /etc/rc.local
bash /etc/rc.local

gen_proxy_file_for_user

rm -rf /root/3proxy-3proxy-0.8.6
rm -r install.sh
echo "Starting Proxy"
echo "Tổng số IPv6 hiện tại:"
ip -6 addr | grep inet6 | wc -l
download_proxy
firewall-cmd --zone=public --add-port=40000-44444/tcp --permanent
firewall-cmd --reload
