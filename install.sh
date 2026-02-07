#!/bin/bash
# ==============================================
# FIXED TUNNEL SETUP SCRIPT - No Errors
# ==============================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==============================================
# MAIN MENU
# ==============================================
show_menu() {
    clear
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════╗"
    echo "║   Advanced Tunnel Installer   ║"
    echo "╚═══════════════════════════════╝"
    echo -e "${NC}"
    
    echo "1) Install Iran Server (GRE Tunnel)"
    echo "2) Install Kharej Server (Xray)"
    echo "3) Install Xray only"
    echo "4) Install MTProto Proxy"
    echo "5) Check status"
    echo "6) Optimize network"
    echo "7) Clean/Uninstall"
    echo "8) Exit"
    echo ""
}

# ==============================================
# INSTALL IRAN SERVER (SIMPLE)
# ==============================================
install_iran() {
    echo -e "${YELLOW}[*] Installing Iran Server...${NC}"
    
    # Update system
    apt-get update && apt-get upgrade -y
    
    # Install essentials
    apt-get install -y \
        iptables \
        iptables-persistent \
        iproute2 \
        net-tools \
        curl \
        wget \
        openssl \
        socat \
        conntrack \
        dnsutils \
        iftop
    
    # Get IP addresses
    IRAN_IP=$(curl -s ifconfig.me)
    echo -e "${BLUE}Your Iran server IP: ${IRAN_IP}${NC}"
    read -p "Enter Kharej server IP: " KHAREJ_IP
    
    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    
    # Clean existing tunnels
    echo -e "${YELLOW}[*] Cleaning old tunnels...${NC}"
    ip link del gre0 2>/dev/null || true
    ip link del gre1 2>/dev/null || true
    ip link del gre-tunnel 2>/dev/null || true
    ip link del vxlan0 2>/dev/null || true
    
    # Create GRE tunnel (SIMPLE VERSION)
    echo -e "${YELLOW}[*] Creating GRE tunnel...${NC}"
    ip tunnel add mytunnel mode gre remote $KHAREJ_IP local $IRAN_IP ttl 255
    ip addr add 10.100.100.1/30 dev mytunnel
    ip link set mytunnel mtu 1476
    ip link set mytunnel up
    
    # Get network interface
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # Configure iptables
    echo -e "${YELLOW}[*] Configuring iptables...${NC}"
    iptables -F
    iptables -t nat -F
    iptables -X
    
    # Forward ports
    iptables -t nat -A PREROUTING -i $INTERFACE -p tcp --dport 443 -j DNAT --to-destination 10.100.100.2:443
    iptables -t nat -A PREROUTING -i $INTERFACE -p udp --dport 443 -j DNAT --to-destination 10.100.100.2:443
    iptables -t nat -A PREROUTING -i $INTERFACE -p tcp --dport 8443 -j DNAT --to-destination 10.100.100.2:8443
    iptables -t nat -A PREROUTING -i $INTERFACE -p tcp --dport 2053 -j DNAT --to-destination 10.100.100.2:2053
    
    # Masquerade
    iptables -t nat -A POSTROUTING -o mytunnel -j MASQUERADE
    
    # Save rules
    netfilter-persistent save 2>/dev/null || iptables-save > /etc/iptables/rules.v4
    
    # Optimize network
    optimize_network
    
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════╗"
    echo "║      Iran Server Installed!        ║"
    echo "╠════════════════════════════════════╣"
    echo "║ GRE Tunnel: 10.100.100.1/30       ║"
    echo "║ Remote GRE: 10.100.100.2          ║"
    echo "║                                    ║"
    echo "║ On Kharej server, run:            ║"
    echo "║ ip tunnel add mytunnel mode gre   ║"
    echo "║   remote $IRAN_IP                ║"
    echo "║   local $KHAREJ_IP               ║"
    echo "║ ip addr add 10.100.100.2/30      ║"
    echo "║ ip link set mytunnel up          ║"
    echo "╚════════════════════════════════════╝"
    echo -e "${NC}"
}

# ==============================================
# INSTALL KHAREJ SERVER
# ==============================================
install_kharej() {
    echo -e "${YELLOW}[*] Installing Kharej Server...${NC}"
    
    # Update system
    apt-get update && apt-get upgrade -y
    
    # Install Xray
    install_xray
    
    # Install MTProto
    install_mtproto
    
    # Get IP addresses
    KHAREJ_IP=$(curl -s ifconfig.me)
    echo -e "${BLUE}Your Kharej server IP: ${KHAREJ_IP}${NC}"
    read -p "Enter Iran server IP: " IRAN_IP
    
    # Create GRE tunnel on Kharej
    echo -e "${YELLOW}[*] Creating GRE tunnel...${NC}"
    ip link del mytunnel 2>/dev/null || true
    ip tunnel add mytunnel mode gre remote $IRAN_IP local $KHAREJ_IP ttl 255
    ip addr add 10.100.100.2/30 dev mytunnel
    ip link set mytunnel mtu 1476
    ip link set mytunnel up
    
    # Add routes
    ip route add 192.168.0.0/16 via 10.100.100.1 dev mytunnel
    ip route add 10.0.0.0/8 via 10.100.100.1 dev mytunnel
    
    # Enable forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    
    # Masquerade
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
    
    optimize_network
    
    echo -e "${GREEN}[✓] Kharej server installed!${NC}"
}

# ==============================================
# INSTALL XRAY (FIXED)
# ==============================================
install_xray() {
    echo -e "${YELLOW}[*] Installing Xray...${NC}"
    
    # Download and install Xray
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    
    # Create simple config
    cat > /usr/local/etc/xray/config.json << 'EOF'
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "00000000-0000-0000-0000-000000000000",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "serverName": "www.microsoft.com",
                    "alpn": ["http/1.1", "h2"],
                    "certificates": [
                        {
                            "certificateFile": "/etc/xray/cert.pem",
                            "keyFile": "/etc/xray/key.pem"
                        }
                    ]
                }
            }
        },
        {
            "port": 8443,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "00000000-0000-0000-0000-000000000000",
                        "alterId": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/cdn-cgi/trace"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        }
    ]
}
EOF
    
    # Generate UUID
    XRAY_UUID=$(xray uuid)
    sed -i "s/00000000-0000-0000-0000-000000000000/$XRAY_UUID/g" /usr/local/etc/xray/config.json
    
    # Generate certificate
    mkdir -p /etc/xray
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -subj "/C=US/ST=California/L=San Francisco/O=Microsoft Corporation/CN=www.microsoft.com" \
        -keyout /etc/xray/key.pem \
        -out /etc/xray/cert.pem
    
    # Start Xray
    systemctl enable xray
    systemctl start xray
    
    echo -e "${GREEN}[✓] Xray installed!${NC}"
    echo -e "${YELLOW}UUID: $XRAY_UUID${NC}"
}

# ==============================================
# INSTALL MTPROTO (FIXED)
# ==============================================
install_mtproto() {
    echo -e "${YELLOW}[*] Installing MTProto Proxy...${NC}"
    
    # Install dependencies
    apt-get install -y git build-essential zlib1g-dev libssl-dev
    
    # Clone and build
    cd /tmp
    rm -rf MTProxy
    git clone https://github.com/TelegramMessenger/MTProxy
    cd MTProxy
    make
    
    # Generate secret
    SECRET=$(head -c 16 /dev/urandom | xxd -ps)
    
    # Create config
    mkdir -p /etc/mtproxy
    cat > /etc/mtproxy/config << EOF
port = 443
secret = $SECRET
workers = $(nproc)
proxy_ip = 0.0.0.0
dd-only = true
domain = telegram.org
EOF
    
    # Copy binary
    cp objs/bin/mtproto-proxy /usr/local/bin/
    
    # Create service
    cat > /etc/systemd/system/mtproxy.service << EOF
[Unit]
Description=MTProto Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mtproto-proxy -c /etc/mtproxy/config
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable mtproxy
    systemctl start mtproxy
    
    echo -e "${GREEN}[✓] MTProto installed!${NC}"
    echo -e "${YELLOW}Secret: $SECRET${NC}"
}

# ==============================================
# OPTIMIZE NETWORK (FIXED)
# ==============================================
optimize_network() {
    echo -e "${YELLOW}[*] Optimizing network...${NC}"
    
    # Apply safe optimizations
    cat > /etc/sysctl.d/99-network-optimize.conf << 'EOF'
# Safe network optimizations
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fastopen = 3
EOF
    
    # Try to enable BBR
    if modprobe tcp_bbr 2>/dev/null; then
        echo "net.core.default_qdisc = fq" >> /etc/sysctl.d/99-network-optimize.conf
        echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.d/99-network-optimize.conf
        echo -e "${GREEN}[✓] BBR enabled${NC}"
    else
        echo -e "${YELLOW}[!] BBR not available, using default${NC}"
    fi
    
    sysctl -p /etc/sysctl.d/99-network-optimize.conf
    
    # Safe traffic control (optional)
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    tc qdisc del dev $INTERFACE root 2>/dev/null || true
    tc qdisc add dev $INTERFACE root fq_codel limit 10240 flows 1024 2>/dev/null || true
    
    echo -e "${GREEN}[✓] Network optimized${NC}"
}

# ==============================================
# CHECK STATUS
# ==============================================
check_status() {
    echo -e "${YELLOW}[*] System Status${NC}"
    echo "========================"
    
    # Network
    echo -e "\n${BLUE}Network Interfaces:${NC}"
    ip addr show | grep -E "inet.*(eth|ens|gre|tun)" | head -10
    
    # Tunnels
    echo -e "\n${BLUE}GRE Tunnels:${NC}"
    ip tunnel show 2>/dev/null || echo "No tunnels found"
    
    # Services
    echo -e "\n${BLUE}Services:${NC}"
    for service in xray mtproxy; do
        if systemctl is-active --quiet $service; then
            echo "✓ $service is running"
        else
            echo "✗ $service is not running"
        fi
    done
    
    # Ports
    echo -e "\n${BLUE}Listening Ports:${NC}"
    ss -tulpn | grep -E ':443|:8443|:2053' | head -5 || echo "No relevant ports listening"
    
    # Connections
    echo -e "\n${BLUE}Active Connections:${NC}"
    ss -tn | grep -E 'ESTAB.*:443|ESTAB.*:8443' | head -3 || echo "No active connections"
}

# ==============================================
# CLEAN/UNINSTALL
# ==============================================
clean_all() {
    echo -e "${RED}[!] Cleaning everything...${NC}"
    
    # Stop services
    systemctl stop xray 2>/dev/null || true
    systemctl stop mtproxy 2>/dev/null || true
    
    # Remove tunnels
    ip link del mytunnel 2>/dev/null || true
    ip link del gre0 2>/dev/null || true
    ip link del gre1 2>/dev/null || true
    ip link del vxlan0 2>/dev/null || true
    
    # Clear iptables
    iptables -F
    iptables -t nat -F
    iptables -X
    
    # Remove configs
    rm -rf /etc/xray
    rm -rf /etc/mtproxy
    
    echo -e "${GREEN}[✓] Cleanup complete!${NC}"
}

# ==============================================
# MAIN EXECUTION
# ==============================================

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Show menu
while true; do
    show_menu
    read -p "Select option [1-8]: " choice
    
    case $choice in
        1)
            install_iran
            ;;
        2)
            install_kharej
            ;;
        3)
            install_xray
            ;;
        4)
            install_mtproto
            ;;
        5)
            check_status
            ;;
        6)
            optimize_network
            ;;
        7)
            clean_all
            ;;
        8)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
