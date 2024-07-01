#!/bin/bash
set -euo pipefail

setup_ipv6() {
    echo "Thiết lập Cấu Hình Mạng.."
    sudo bash <(curl -s "https://raw.githubusercontent.com/volamtuan/-/main/ip")
}

auto_detect_interface() {
    IFCFG=$(ip -o link show | awk -F': ' '$3 !~ /lo|vir|^[^0-9]/ {print $2; exit}')
}

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

install_3proxy() {
    echo "Installing 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.9.4.tar.gz"
    wget -qO- $URL | bsdtar -xvf- >/dev/null 2>&1
    cd 3proxy-0.9.4
    make -f Makefile.Linux >/dev/null 2>&1
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat} >/dev/null 2>&1
    cp src/3proxy /usr/local/etc/3proxy/bin/ >/dev/null 2>&1
    cd /home/vlt  # Sửa đường dẫn tuyệt đối
    systemctl link /usr/lib/systemd/system/3proxy.service
    echo "* hard nofile 999999" | sudo tee -a /etc/security/limits.conf
    echo "* soft nofile 999999" | sudo tee -a /etc/security/limits.conf
    echo "net.ipv6.conf.${IFCFG}.proxy_ndp=1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv6.conf.all.proxy_ndp=1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv6.conf.default.forwarding=1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv6.ip_nonlocal_bind = 1" | sudo tee -a /etc/sysctl.conf
    systemctl stop firewalld
    systemctl disable firewalld
    echo "fs.file-max = 1000000" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.ip_local_port_range = 1024 65000" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_fin_timeout = 30" | sudo tee -a /etc/sysctl.conf
    echo "net.core.somaxconn = 4096" | sudo tee -a /etc/sysctl.conf
    echo "net.core.netdev_max_backlog = 4096" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
}

gen_3proxy() {
    cat <<EOF | sudo tee /usr/local/etc/3proxy/3proxy.cfg
daemon
maxconn 5000
nserver 1.1.1.1
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
nscache6 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456
flush
auth none
allow 14.224.163.75
allow 127.0.0.1

$(awk -F'/' '{print "proxy -6 -n -a -p" $4 " -i" $3 " -e" $5 "\nflush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    awk -F'/' '{print $3 ":" $4}' ${WORKDATA} > /home/vlt/proxy.txt
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        entry="//$IP4/$port/$(gen64 $IP6)"
        echo "$entry"
        echo "$IP4:$port" >> "/home/vlt/ipv4.txt"
        echo "$(gen64 $IP6)" >> "/home/vlt/ipv6.txt"
    done > /home/vlt/data.txt
}

gen_iptables() {
    awk -F'/' '{print "iptables -I INPUT -p tcp --dport " $4 " -m state --state NEW -j ACCEPT"}' ${WORKDATA} > /home/vlt/boot_iptables.sh
}

gen_ifconfig() {
    awk -F'/' '{print "ifconfig ${IFCFG} inet6 add " $5 "/64"}' ${WORKDATA} > /home/vlt/boot_ifconfig.sh
}

rotate_ipv6() {
    echo "Rotating IPv6 addresses..."
    IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
    gen_data
    gen_3proxy
    gen_proxy_file_for_user
    gen_iptables
    gen_ifconfig

    echo "Restarting 3proxy service..."
    systemctl restart 3proxy
    restart_result=$?

    if [ $restart_result -eq 0 ]; then
        echo "IPv6 addresses rotated successfully."
        echo "[OK]: Thành công"
    else
        echo "Failed to rotate IPv6 addresses!"
        echo "[ERROR]: Thất bại!"
        exit 1
    fi
}

echo "Installing apps"
sudo yum -y install curl wget gcc net-tools bsdtar zip >/dev/null

install_3proxy

# Thiết lập thư mục làm việc
WORKDIR="/home/vlt"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $_

# Lấy địa chỉ IP
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "IPv4 = ${IP4}"
echo "IPv6 = ${IP6}"

# Thiết lập cổng proxy và số lượng proxy tạo
FIRST_PORT=10000
LAST_PORT=12444

echo "Cổng proxy: $FIRST_PORT"
echo "Số lượng proxy tạo: $(($LAST_PORT - $FIRST_PORT + 1))"

# Tạo dữ liệu cho proxy
gen_data > $WORKDATA
gen_iptables > $WORKDIR/boot_iptables.sh
gen_ifconfig > $WORKDIR/boot_ifconfig.sh
chmod +x $WORKDIR/boot_*.sh

# Tạo cấu hình 3proxy
gen_3proxy

# Thiết lập /etc/rc.local cho tính chất bền vững
cat <<EOF | sudo tee /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
systemctl start NetworkManager.service
ifup ${IFCFG}
systemctl start 3proxy
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 65535
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg &
EOF

sudo chmod +x /etc/rc.d/rc.local

# Tạo file dịch vụ systemd cho 3proxy
cat <<EOF >/etc/systemd/system/3proxy.service
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -TERM \$MAINPID
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Tạo file dịch vụ systemd cho rc.local nếu chưa có
sudo tee /etc/systemd/system/rc-local.service <<EOF
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd để nhận thấy các thay đổi
sudo systemctl daemon-reload

# Enable và khởi động 3proxy
sudo systemctl enable 3proxy
sudo systemctl start 3proxy

# Tạo tệp proxy cho người dùng
gen_proxy_file_for_user

Xóa thư mục tạm và tệp cài đặt 3proxy

rm -rf /home/vlt/3proxy-0.9.4
rm -rf setup.sh

echo “Starting Proxy”

echo “Tổng số IPv6 hiện tại:”
ip -6 addr | grep inet6 | wc -l

Vòng lặp để xoay vòng IPv6

while true; do
rotate_ipv6
sleep 3600
done
