#!/bin/bash
# ==========================================
# Advanced Tunnel - Fixed IP Detection Issue
# ==========================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==========================================
# FIXED IP DETECTION FUNCTION
# ==========================================
get_public_ip() {
    echo -e "${YELLOW}[*] Detecting public IP...${NC}"
    
    # Try multiple methods to get public IP
    local ip_methods=(
        "curl -s https://api.ipify.org"
        "curl -s https://icanhazip.com"
        "curl -s https://checkip.amazonaws.com"
        "curl -s https://ifconfig.me"
        "curl -s https://ipinfo.io/ip"
        "wget -qO- https://ipecho.net/plain"
    )
    
    for method in "${ip_methods[@]}"; do
        local ip=$($method 2>/dev/null)
        # Check if result is a valid IP
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo -e "${GREEN}[✓] IP detected: $ip${NC}"
            echo "$ip"
            return 0
        fi
    done
    
    # If all methods fail, use local IP
    local local_ip=$(ip route get 8.8.8.8 | grep -oP 'src \K\S+' | head -1)
    if [[ $local_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${YELLOW}[!] Using local IP: $local_ip${NC}"
        echo "$local_ip"
        return 0
    fi
    
    # Last resort
    echo -e "${RED}[!] Could not detect IP automatically${NC}"
    echo "0.0.0.0"
    return 1
}

# ==========================================
# SIMPLE IRAN SERVER SETUP (FIXED)
# ==========================================
install_iran_simple() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════╗"
    echo "║   Iran Server Setup (Fixed)   ║"
    echo "╚═══════════════════════════════╝"
    echo -e "${NC}"
    
    # Get Iran server IP
    IRAN_IP=$(get_public_ip)
    if [ "$IRAN_IP" = "0.0.0.0" ]; then
        read -p "Enter Iran Server Public IP: " IRAN_IP
    fi
    
    # Get Kharej server IP
    read -p "Enter Kharej Server Public IP: " KHAREJ_IP
    
    # Get network interface
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    echo -e "${BLUE}Using interface: $INTERFACE${NC}"
    
    # Update system
    echo -e "${YELLOW}[*] Updating system...${NC}"
    apt-get update && apt-get upgrade -y
    
    # Install essentials
    echo -e "${YELLOW}[*] Installing dependencies...${NC}"
    apt-get install -y \
        iptables \
        iptables-persistent \
        iproute2 \
        net-tools \
        curl \
        wget \
        openssl
    
    # Clean old tunnels
    echo -e "${YELLOW}[*] Cleaning old tunnels...${NC}"
    ip link del gre0 2>/dev/null || true
    ip link del gre1 2>/dev/null || true
    ip link del mytunnel 2>/dev/null || true
    
    # Create GRE tunnel (SIMPLE AND RELIABLE)
    echo -e "${YELLOW}[*] Creating GRE tunnel...${NC}"
    
    # First, verify IPs are valid
    if [[ ! $IRAN_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ ! $KHAREJ_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}[!] Invalid IP address format${NC}"
        echo "Iran IP: $IRAN_IP"
        echo "Kharej IP: $KHAREJ_IP"
        exit 1
    fi
    
    # Create tunnel
    ip tunnel add mytunnel mode gre remote $KHAREJ_IP local $IRAN_IP ttl 255
    ip addr add 10.100.100.1/30 dev mytunnel
    ip link set mytunnel mtu 1476
    ip link set mytunnel up
    
    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p
    
    # Configure iptables
    echo -e "${YELLOW}[*] Configuring iptables...${NC}"
    
    # Clear existing rules
    iptables -F
    iptables -t nat -F
    iptables -X
    
    # Set default policies
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    # Forward ports to GRE tunnel
    iptables -t nat -A PREROUTING -i $INTERFACE -p tcp --dport 443 -j DNAT --to-destination 10.100.100.2
    iptables -t nat -A PREROUTING -i $INTERFACE -p udp --dport 443 -j DNAT --to-destination 10.100.100.2
    iptables -t nat -A PREROUTING -i $INTERFACE -p tcp --dport 8443 -j DNAT --to-destination 10.100.100.2
    iptables -t nat -A PREROUTING -i $INTERFACE -p tcp --dport 2053 -j DNAT --to-destination 10.100.100.2
    
    # Masquerade outgoing traffic
    iptables -t nat -A POSTROUTING -o mytunnel -j MASQUERADE
    
    # Save rules
    apt-get install -y iptables-persistent
    netfilter-persistent save 2>/dev/null || iptables-save > /etc/iptables/rules.v4
    
    # Optimize network
    echo -e "${YELLOW}[*] Optimizing network...${NC}"
    cat > /etc/sysctl.d/99-tunnel-optimize.conf << EOF
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
    sysctl -p /etc/sysctl.d/99-tunnel-optimize.conf
    
    # Create monitoring script
    echo -e "${YELLOW}[*] Creating monitoring script...${NC}"
    cat > /usr/local/bin/tunnel-monitor.sh << 'EOF'
#!/bin/bash
while true; do
    echo "=== Tunnel Status $(date) ==="
    
    # Check tunnel
    if ip link show mytunnel > /dev/null 2>&1; then
        echo "✓ GRE tunnel is up"
    else
        echo "✗ GRE tunnel is down"
    fi
    
    # Check connectivity
    if ping -c 2 -W 1 10.100.100.2 > /dev/null 2>&1; then
        echo "✓ Connected to remote"
    else
        echo "✗ Cannot reach remote"
    fi
    
    echo "============================="
    echo ""
    sleep 60
done
EOF
    
    chmod +x /usr/local/bin/tunnel-monitor.sh
    
    # Display configuration
    echo -e "${GREEN}"
    cat << "EOF"
╔══════════════════════════════════════════╗
║        Iran Server Setup Complete!       ║
╠══════════════════════════════════════════╣
║ Configuration:                           ║
║ • GRE Tunnel: 10.100.100.1/30           ║
║ • Remote GRE: 10.100.100.2              ║
║ • Interface: $INTERFACE                 ║
║                                          ║
║ Ports Forwarded:                         ║
║ • TCP/UDP 443 → Kharej                  ║
║ • TCP 8443 → Kharej                     ║
║ • TCP 2053 → Kharej                     ║
╚══════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${YELLOW}[!] On Kharej server, run these commands:${NC}"
    echo "=========================================="
    echo "ip tunnel add mytunnel mode gre remote $IRAN_IP local $KHAREJ_IP ttl 255"
    echo "ip addr add 10.100.100.2/30 dev mytunnel"
    echo "ip link set mytunnel mtu 1476"
    echo "ip link set mytunnel up"
    echo "echo 1 > /proc/sys/net/ipv4/ip_forward"
    echo "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
    echo "=========================================="
    
    # Start monitoring in background
    nohup /usr/local/bin/tunnel-monitor.sh > /var/log/tunnel-monitor.log 2>&1 &
    
    echo -e "${GREEN}[✓] Iran server setup complete!${NC}"
    echo -e "${YELLOW}Monitor logs: tail -f /var/log/tunnel-monitor.log${NC}"
}

# ==========================================
# KHAREJ SERVER SETUP
# ==========================================
install_kharej_simple() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════╗"
    echo "║   Kharej Server Setup         ║"
    echo "╚═══════════════════════════════╝"
    echo -e "${NC}"
    
    # Get Kharej server IP
    KHAREJ_IP=$(get_public_ip)
    if [ "$KHAREJ_IP" = "0.0.0.0" ]; then
        read -p "Enter Kharej Server Public IP: " KHAREJ_IP
    fi
    
    # Get Iran server IP
    read -p "Enter Iran Server Public IP: " IRAN_IP
    
    # Get network interface
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    echo -e "${BLUE}Using interface: $INTERFACE${NC}"
    
    # Update system
    apt-get update && apt-get upgrade -y
    
    # Install Xray
    echo -e "${YELLOW}[*] Installing Xray...${NC}"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    
    # Generate UUID
    UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16)
    
    # Create Xray config
    cat > /usr/local/etc/xray/config.json << EOF
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
                        "id": "$UUID",
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
                        "id": "$UUID"
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
            "settings": {}
        }
    ]
}
EOF
    
    # Generate certificate
    mkdir -p /etc/xray
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -subj "/C=US/ST=California/L=San Francisco/O=Microsoft Corporation/CN=www.microsoft.com" \
        -keyout /etc/xray/key.pem \
        -out /etc/xray/cert.pem
    
    # Create GRE tunnel
    echo -e "${YELLOW}[*] Creating GRE tunnel...${NC}"
    ip link del mytunnel 2>/dev/null || true
    ip tunnel add mytunnel mode gre remote $IRAN_IP local $KHAREJ_IP ttl 255
    ip addr add 10.100.100.2/30 dev mytunnel
    ip link set mytunnel mtu 1476
    ip link set mytunnel up
    
    # Enable forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    
    # Add routes for Iranian IP ranges (optional)
    ip route add 192.168.0.0/16 via 10.100.100.1 dev mytunnel 2>/dev/null || true
    ip route add 10.0.0.0/8 via 10.100.100.1 dev mytunnel 2>/dev/null || true
    
    # Masquerade
    iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
    
    # Start Xray
    systemctl enable xray
    systemctl start xray
    
    echo -e "${GREEN}"
    cat << "EOF"
╔══════════════════════════════════════════╗
║     Kharej Server Setup Complete!        ║
╠══════════════════════════════════════════╣
║ Services:                                ║
║ • Xray on port 443 (VLESS+TLS)          ║
║ • Xray on port 8443 (VMESS+WS)          ║
║ • GRE Tunnel: 10.100.100.2/30           ║
║                                          ║
║ Connection Info:                         ║
║ • Server: your-domain.com               ║
║ • Port: 443                             ║
║ • UUID: [see below]                     ║
╚══════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${YELLOW}UUID: $UUID${NC}"
    echo -e "${YELLOW}Test connection: curl -I https://localhost:443${NC}"
}

# ==========================================
# MANUAL IP ENTRY VERSION
# ==========================================
install_manual() {
    echo -e "${YELLOW}[*] Manual Installation Mode${NC}"
    
    echo "Since automatic IP detection failed, please enter manually:"
    read -p "Iran Server Public IP: " IRAN_IP
    read -p "Kharej Server Public IP: " KHAREJ_IP
    
    # Validate IPs
    if [[ ! $IRAN_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ ! $KHAREJ_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}[!] Invalid IP format${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Iran IP: $IRAN_IP${NC}"
    echo -e "${GREEN}Kharej IP: $KHAREJ_IP${NC}"
    
    read -p "Install which server? (iran/kharej): " SERVER_TYPE
    
    if [ "$SERVER_TYPE" = "iran" ]; then
        export IRAN_IP KHAREJ_IP
        install_iran_simple
    elif [ "$SERVER_TYPE" = "kharej" ]; then
        export KHAREJ_IP IRAN_IP
        install_kharej_simple
    else
        echo "Invalid choice"
        exit 1
    fi
}

# ==========================================
# TROUBLESHOOTING FUNCTIONS
# ==========================================
fix_ip_issue() {
    echo -e "${YELLOW}[*] Fixing IP detection issue...${NC}"
    
    # Method 1: Try different DNS
    echo "8.8.8.8" > /etc/resolv.conf
    
    # Method 2: Use local IP detection
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo -e "${BLUE}Local IP: $LOCAL_IP${NC}"
    
    # Method 3: Ask user
    read -p "Is this your public IP? [$LOCAL_IP] (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        echo "$LOCAL_IP"
    else
        read -p "Please enter your public IP: " MANUAL_IP
        echo "$MANUAL_IP"
    fi
}

check_connectivity() {
    echo -e "${YELLOW}[*] Checking connectivity...${NC}"
    
    # Test DNS
    echo "1. Testing DNS..."
    nslookup google.com 8.8.8.8 2>&1 | grep -q "Name" && echo "✓ DNS working" || echo "✗ DNS failed"
    
    # Test external connectivity
    echo "2. Testing external connectivity..."
    curl -s --connect-timeout 5 https://google.com > /dev/null && echo "✓ External access" || echo "✗ No external access"
    
    # Test IP services
    echo "3. Testing IP detection services..."
    SERVICES=("ipify.org" "icanhazip.com" "checkip.amazonaws.com")
    for service in "${SERVICES[@]}"; do
        echo -n "  $service: "
        curl -s --connect-timeout 3 "https://$service" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' && echo "✓" || echo "✗"
    done
}

# ==========================================
# MAIN MENU
# ==========================================
main_menu() {
    clear
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════╗"
    echo "║   Advanced Tunnel Installer   ║"
    echo "╚═══════════════════════════════╝"
    echo -e "${NC}"
    
    echo "1) Install Iran Server (Fixed)"
    echo "2) Install Kharej Server"
    echo "3) Manual IP Entry"
    echo "4) Check Connectivity"
    echo "5) Fix IP Detection"
    echo "6) Exit"
    echo ""
    read -p "Select option [1-6]: " choice
    
    case $choice in
        1)
            install_iran_simple
            ;;
        2)
            install_kharej_simple
            ;;
        3)
            install_manual
            ;;
        4)
            check_connectivity
            ;;
        5)
            fix_ip_issue
            ;;
        6)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# ==========================================
# DIRECT COMMAND EXECUTION
# ==========================================
if [ $# -eq 0 ]; then
    # No arguments, show menu
    while true; do
        main_menu
    done
else
    # With arguments
    case $1 in
        iran)
            install_iran_simple
            ;;
        kharej)
            install_kharej_simple
            ;;
        manual)
            install_manual
            ;;
        fix)
            fix_ip_issue
            ;;
        check)
            check_connectivity
            ;;
        *)
            echo "Usage: $0 {iran|kharej|manual|fix|check}"
            echo "Or run without arguments for menu"
            exit 1
            ;;
    esac
fi
