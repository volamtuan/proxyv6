#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

setup_ipv6() {
    echo "Thiết lập IPv6..."
    bash <(curl -s "https://raw.githubusercontent.com/volamtuan/-/main/ip")
}
setup_ipv6

YUM=$(which yum)
#####
if [ "$YUM" ]; then
echo > /etc/sysctl.conf
##
tee -a /etc/sysctl.conf <<EOF
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.disable_ipv6 = 0
EOF
##
sysctl -p
IPC=$(curl -4 -s icanhazip.com | cut -d"." -f3)
IPD=$(curl -4 -s icanhazip.com | cut -d"." -f4)
##
if [ $IPC == 4 ]
then
   tee -a /etc/sysconfig/network-scripts/ifcfg-eth0 <<-EOF
	IPV6INIT=yes
	IPV6_AUTOCONF=no
	IPV6_DEFROUTE=yes
	IPV6_FAILURE_FATAL=no
	IPV6_ADDR_GEN_MODE=stable-privacy
	IPV6ADDR=2403:6a40:0:40::$IPD:0000/64
	IPV6_DEFAULTGW=2403:6a40:0:40::1
	EOF
elif [ $IPC == 5 ]
then
   tee -a /etc/sysconfig/network-scripts/ifcfg-eth0 <<-EOF
	IPV6INIT=yes
	IPV6_AUTOCONF=no
	IPV6_DEFROUTE=yes
	IPV6_FAILURE_FATAL=no
	IPV6_ADDR_GEN_MODE=stable-privacy
	IPV6ADDR=2403:6a40:0:41::$IPD:0000/64
	IPV6_DEFAULTGW=2403:6a40:0:41::1
	EOF
elif [ $IPC == 244 ]
then
   tee -a /etc/sysconfig/network-scripts/ifcfg-eth0 <<-EOF
	IPV6INIT=yes
	IPV6_AUTOCONF=no
	IPV6_DEFROUTE=yes
	IPV6_FAILURE_FATAL=no
	IPV6_ADDR_GEN_MODE=stable-privacy
	IPV6ADDR=2403:6a40:2000:244::$IPD:0000/64
	IPV6_DEFAULTGW=2403:6a40:2000:244::1
	EOF
else
	tee -a /etc/sysconfig/network-scripts/ifcfg-eth0 <<-EOF
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

rm -rf ipv6.sh
### Ubuntu  
 else
	ipv4=$(curl -4 -s icanhazip.com)
	IPC=$(curl -4 -s icanhazip.com | cut -d"." -f3)
	IPD=$(curl -4 -s icanhazip.com | cut -d"." -f4)
	INT=$(ls /sys/class/net | grep e)
	if [ "$IPC" = "4" ]; then
		IPV6_ADDRESS="2403:6a40:0:40::$IPD:0000/64"
		PREFIX_LENGTH="64"
		INTERFACE="$INT"
		GATEWAY="2403:6a40:0:40::1"
	elif [ "$IPC" = "5" ]; then
		IPV6_ADDRESS="2403:6a40:0:41::$IPD:0000/64"
		PREFIX_LENGTH="64"
		INTERFACE="$INT"
		GATEWAY="2403:6a40:0:41::1"
	elif [ "$IPC" = "244" ]; then
		IPV6_ADDRESS="2403:6a40:2000:244::$IPD:0000/64"
		PREFIX_LENGTH="64"
		INTERFACE="$INT"
		GATEWAY="2403:6a40:2000:244::1"
	else
		IPV6_ADDRESS="2403:6a40:0:$IPC::$IPD:0000/64"
		PREFIX_LENGTH="64"
		INTERFACE="$INT"
		GATEWAY="2403:6a40:0:$IPC::1"
	fi
	interface_name="$INTERFACE"  # Thay tháº¿ báº±ng tÃªn giao diá»‡n máº¡ng cá»§a báº¡n
	ipv6_address="$IPV6_ADDRESS"
	gateway6_address="$GATEWAY"
	# kiá»ƒm tra cáº¥u hÃ¬nh card máº¡ng
	if [ "$INT" = "ens160" ]; then
	   netplan_path="/etc/netplan/99-netcfg-vmware.yaml"  # Thay tháº¿ báº±ng Ä‘Æ°á»ng dáº«n tá»‡p cáº¥u hÃ¬nh Netplan cá»§a báº¡n
	   netplan_config=$(cat "$netplan_path")
	   new_netplan_config=$(sed "/gateway4:/i \ \ \ \ \ \ \  - $ipv6_address" <<< "$netplan_config")
	   new_netplan_config=$(sed "/gateway4:.*/a \ \ \ \ \  gateway6: $gateway6_address" <<< "$new_netplan_config")
	elif [ "$INT" = "eth0" ]; then
	   netplan_path="/etc/netplan/50-cloud-init.yaml"
	   netplan_config=$(cat "$netplan_path")
	   # Táº¡o Ä‘oáº¡n cáº¥u hÃ¬nh IPv6 má»›i
       new_netplan_config=$(sed "/gateway4:/i \ \ \ \ \ \ \ \ \ \ \ \ - $ipv6_address" <<< "$netplan_config")
       # cáº­p nháº­t gateway ipv6
       new_netplan_config=$(sed "/gateway4:.*/a \ \ \ \ \ \ \ \ \ \ \ \ gateway6: $gateway6_address" <<< "$new_netplan_config")
	else
	   echo 'Khong co card mang phu hop'
	fi
	# Táº¡o Ä‘oáº¡n cáº¥u hÃ¬nh IPv6 má»›i
	
    # cáº­p nháº­t gateway ipv6
    
	echo "$new_netplan_config" > "$netplan_path"

	# Ãp dá»¥ng cáº¥u hÃ¬nh Netplan
	sudo netplan apply
 fi
 echo 'Da tao IPV6 thanh cong!'
 
# Hàm tạo chuỗi ngẫu nhiên
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Hàm tạo địa chỉ IPv6 ngẫu nhiên
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}
install_3proxy() {
    URL="https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-0.9.4
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,stat}
    cp bin/3proxy /usr/local/etc/3proxy/bin/
    cp ../init.d/3proxy.sh /etc/init.d/3proxy
    chmod +x /etc/init.d/3proxy
    chkconfig 3proxy on
    cd $WORKDIR
    echo "* hard nofile 999999" >> /etc/security/limits.conf
    echo "* soft nofile 999999" >> /etc/security/limits.conf
    echo "net.ipv6.conf.$(ip -o -4 route show to default | awk '{print $5}').proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.ip_nonlocal_bind=1" >> /etc/sysctl.conf
    echo "Cài đặt 3proxy hoàn tất."
}

gen_3proxy() {
    cat <<EOF
daemon
maxconn 2000
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

$(awk -F "/" '{print "\n" \
"" $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4}' ${WORKDATA})
EOF
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "//$IP4/$port/$(gen64 $vPrefix)"
        echo "$IP4:$port" >> "$WORKDIR/ipv4.txt"
        new_ipv6=$(gen64 $vPrefix)
        echo "$new_ipv6" >> "$WORKDIR/ipv6.txt"
    done
}

gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

cat << EOF > /etc/rc.d/rc.local
#!/bin/bash
touch /var/lock/subsys/local
EOF

echo "installing apps"
yum -y install wget gcc net-tools bsdtar zip >/dev/null

install_3proxy

echo "working folder = /home/vlt"
WORKDIR="/home/vlt"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
DEFAULT_PREFIX="${IP6:-2607:f8b0:4001:c2f}"
read -r -p "Nhập IPv6 của bạn (mặc định: $DEFAULT_PREFIX): " vPrefix
vPrefix=${vPrefix:-$DEFAULT_PREFIX}

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = $vPrefix"

FIRST_PORT=25555
LAST_PORT=27777

echo "Cổng proxy: $FIRST_PORT"
echo "Số lượng proxy tạo: $(($LAST_PORT - $FIRST_PORT + 1))"

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x $WORKDIR/boot_*.sh /etc/rc.local

#gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

bash /etc/rc.local

gen_proxy_file_for_user
rm -rf /root/
rm -rf 01
echo "Starting Proxy"

echo "Tổng số IPv6 hiện tại:"
ip -6 addr | grep inet6 | wc -l
download_proxy
