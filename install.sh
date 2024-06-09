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

# Hàm để kiểm tra phiên bản hệ điều hành
check_os_version() {
    local os=$(grep -oP '(?<=^ID=)\w+' /etc/os-release)
    local version=$(grep -oP '(?<=^VERSION_ID=")\d+' /etc/os-release)
    echo "$os $version"
}

# Kiểm tra phiên bản hệ điều hành
os_info=$(check_os_version)
os=$(echo "$os_info" | awk '{print $1}')
version=$(echo "$os_info" | awk '{print $2}')

if [ "$os" == "centos" ]; then
    echo "Thiết lập ipv6 và cài đặt apps cho CentOS"
    yum -y install curl wget nano gcc net-tools bsdtar zip >/dev/null 2>&1
    # Tải script ipv6.sh và thực thi
    wget https://raw.githubusercontent.com/volamtuan/proxyv6/main/ip.sh && chmod +x ip.sh && bash ip.sh
elif [ "$os" == "ubuntu" ]; then
    echo "Thiết lập ipv6 và cài đặt apps cho Ubuntu"
    apt-get -y install wget nano gcc net-tools bsdtar zip >/dev/null 2>&1
    # Tải script ipv6.sh và thực thi
    wget https://raw.githubusercontent.com/volamtuan/proxyv6/main/ipv6.sh && chmod +x ipv6.sh && bash ipv6.sh
else
    echo "Phiên bản hệ điều hành không được hỗ trợ."
    exit 1
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
