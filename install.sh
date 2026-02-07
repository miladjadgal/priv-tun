#!/bin/bash
# =====================================================
# COMPLETE ADVANCED TUNNEL SCRIPT
# Features: GRE + Xray + WireGuard + Anti-DPI
# =====================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# =====================================================
# CONFIGURATION
# =====================================================
TUNNEL_VERSION="3.0"
DOMAIN="cdn.microsoft.com"
FAKE_TLS_DOMAIN="telegram.org"

# =====================================================
# UTILITY FUNCTIONS
# =====================================================

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Please run as root${NC}"
        exit 1
    fi
}

# Get public IP with multiple fallbacks
get_public_ip() {
    echo -e "${YELLOW}[*] Detecting public IP...${NC}"
    
    # List of IP detection services
    local services=(
        "https://api.ipify.org"
        "https://icanhazip.com"
        "https://checkip.amazonaws.com"
        "https://ifconfig.co"
        "https://ipecho.net/plain"
        "https://myexternalip.com/raw"
        "https://wtfismyip.com/text"
        "https://ipinfo.io/ip"
    )
    
    for service in "${services[@]}"; do
        local ip=$(curl -s --connect-timeout 3 "$service" 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo -e "${GREEN}[✓] IP detected via ${service##*/}: $ip${NC}"
            echo "$ip"
            return 0
        fi
    done
    
    # Fallback to local IP
    local local_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+')
    if [[ $local_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${YELLOW}[!] Using local IP: $local_ip${NC}"
        echo "$local_ip"
        return 0
    fi
    
    echo -e "${RED}[!] Could not detect IP${NC}"
    echo "0.0.0.0"
    return 1
}

# Install prerequisites
install_prerequisites() {
    echo -e "${YELLOW}[*] Installing prerequisites...${NC}"
    
    apt-get update
    apt-get upgrade -y
    
    # Essential packages
    apt-get install -y \
        curl \
        wget \
        git \
        build-essential \
        libssl-dev \
        zlib1g-dev \
        libpcre3-dev \
        libevent-dev \
        cmake \
        iptables \
        iptables-persistent \
        iproute2 \
        net-tools \
        dnsutils \
        conntrack \
        ethtool \
        iftop \
        nethogs \
        htop \
        tmux \
        jq \
        bc \
        python3 \
        python3-pip \
        openssl \
        ca-certificates \
        socat \
        netcat \
        telnet \
        mtr \
        tcptraceroute \
        dnsmasq \
        resolvconf
    
    # Install latest curl with http3 support
    apt-get install -y libnghttp2-dev libssl-dev
    pip3 install --upgrade curl
}

# =====================================================
# NETWORK OPTIMIZATION
# =====================================================
optimize_network() {
    echo -e "${YELLOW}[*] Optimizing network settings...${NC}"
    
    # Kernel optimization
    cat > /etc/sysctl.d/99-advanced-tunnel.conf << EOF
# Network optimizations
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_fin_timeout = 10
net.ipv4.ip_local_port_range = 1024 65535
EOF
    
    # Enable BBR if available
    if modprobe tcp_bbr 2>/dev/null; then
        echo "net.core.default_qdisc = fq" >> /etc/sysctl.d/99-advanced-tunnel.conf
        echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.d/99-advanced-tunnel.conf
        echo -e "${GREEN}[✓] BBR congestion control enabled${NC}"
    fi
    
    sysctl -p /etc/sysctl.d/99-advanced-tunnel.conf
    
    # Traffic control
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    tc qdisc del dev $INTERFACE root 2>/dev/null || true
    tc qdisc add dev $INTERFACE root fq_codel limit 10240 flows 1024 noecn 2>/dev/null || true
    
    echo -e "${GREEN}[✓] Network optimization complete${NC}"
}

# =====================================================
# DPI DETECTION & ANALYSIS
# =====================================================
analyze_dpi() {
    echo -e "${YELLOW}[*] Analyzing DPI and network conditions...${NC}"
    
    # Check internet connectivity
    if ! ping -c 2 -W 2 8.8.8.8 &> /dev/null; then
        echo -e "${RED}[!] No internet connectivity${NC}"
    else
        echo -e "${GREEN}[✓] Internet connectivity OK${NC}"
    fi
    
    # Check DNS
    if ! nslookup google.com 8.8.8.8 &> /dev/null; then
        echo -e "${RED}[!] DNS issues detected${NC}"
    else
        echo -e "${GREEN}[✓] DNS working${NC}"
    fi
    
    # Check for common DPI ports
    echo -e "${YELLOW}[!] Checking common DPI patterns...${NC}"
    if ss -tulpn | grep -E ':443|:80|:53' | wc -l -gt 5; then
        echo -e "${RED}[!] Multiple services detected - possible DPI target${NC}"
    fi
    
    # Check MTU
    MTU=$(ip link show $(ip route | grep default | awk '{print $5}') | grep mtu | awk '{print $5}')
    echo -e "${BLUE}[*] Interface MTU: $MTU${NC}"
    
    if [ $MTU -lt 1400 ]; then
        echo -e "${RED}[!] Low MTU detected - may affect tunnel performance${NC}"
    fi
}

# =====================================================
# GRE TUNNEL SETUP
# =====================================================
setup_gre_tunnel() {
    echo -e "${YELLOW}[*] Setting up GRE tunnel...${NC}"
    
    read -p "Enter local server IP (this server): " LOCAL_IP
    read -p "Enter remote server IP: " REMOTE_IP
    read -p "Enter GRE tunnel name [gre1]: " GRE_NAME
    GRE_NAME=${GRE_NAME:-gre1}
    
    # Validate IPs
    if ! [[ $LOCAL_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || ! [[ $REMOTE_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}[!] Invalid IP address format${NC}"
        return 1
    fi
    
    # Remove existing tunnel
    ip link del $GRE_NAME 2>/dev/null || true
    
    # Create GRE tunnel
    if ip tunnel add $GRE_NAME mode gre remote $REMOTE_IP local $LOCAL_IP ttl 255; then
        echo -e "${GREEN}[✓] GRE tunnel created${NC}"
    else
        echo -e "${RED}[!] Failed to create GRE tunnel${NC}"
        echo -e "${YELLOW}Trying alternative method...${NC}"
        # Try alternative
        ip link add $GRE_NAME type gretap remote $REMOTE_IP local $LOCAL_IP ttl 255
    fi
    
    # Configure tunnel
    ip addr add 10.200.0.1/30 dev $GRE_NAME
    ip link set $GRE_NAME mtu 1450
    ip link set $GRE_NAME up
    
    # Enable forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p
    
    # Save configuration
    cat > /etc/gre-tunnel.conf << EOF
LOCAL_IP=$LOCAL_IP
REMOTE_IP=$REMOTE_IP
GRE_NAME=$GRE_NAME
GRE_LOCAL_IP=10.200.0.1
GRE_REMOTE_IP=10.200.0.2
CREATED=$(date)
EOF
    
    echo -e "${GREEN}[✓] GRE tunnel configuration saved to /etc/gre-tunnel.conf${NC}"
}

# =====================================================
# XRAY INSTALLATION & CONFIGURATION
# =====================================================
install_xray() {
    echo -e "${YELLOW}[*] Installing Xray...${NC}"
    
    # Remove existing Xray
    systemctl stop xray 2>/dev/null || true
    rm -rf /usr/local/bin/xray /usr/local/etc/xray
    
    # Install from official script
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    
    # Generate UUID
    if command -v xray >/dev/null 2>&1; then
        XRAY_UUID=$(xray uuid)
    else
        XRAY_UUID=$(cat /proc/sys/kernel/random/uuid)
    fi
    
    # Generate X25519 key for Reality
    if command -v xray >/dev/null 2>&1; then
        XRAY_KEY=$(xray x25519)
        PRIVATE_KEY=$(echo "$XRAY_KEY" | grep "Private key:" | awk '{print $3}')
        PUBLIC_KEY=$(echo "$XRAY_KEY" | grep "Public key:" | awk '{print $3}')
    else
        PRIVATE_KEY=""
        PUBLIC_KEY=""
    fi
    
    # Create advanced Xray config
    cat > /usr/local/etc/xray/config.json << EOF
{
    "log": {
        "loglevel": "warning",
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log"
    },
    "dns": {
        "servers": [
            "https://1.1.1.1/dns-query",
            "https://dns.google/dns-query"
        ]
    },
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "domain": ["geosite:category-ads-all"],
                "outboundTag": "block"
            },
            {
                "type": "field",
                "ip": ["geoip:private"],
                "outboundTag": "block"
            }
        ]
    },
    "policy": {
        "levels": {
            "0": {
                "handshake": 2,
                "connIdle": 120,
                "uplinkOnly": 0,
                "downlinkOnly": 0,
                "bufferSize": 4096
            }
        }
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "tag": "vless-tls",
            "settings": {
                "clients": [
                    {
                        "id": "$XRAY_UUID",
                        "flow": "xtls-rprx-vision",
                        "email": "user@vless"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "serverName": "$DOMAIN",
                    "alpn": ["h2", "http/1.1"],
                    "certificates": [
                        {
                            "certificateFile": "/etc/xray/cert.pem",
                            "keyFile": "/etc/xray/key.pem"
                        }
                    ]
                },
                "tcpSettings": {
                    "header": {
                        "type": "http",
                        "request": {
                            "version": "1.1",
                            "method": "GET",
                            "path": ["/"],
                            "headers": {
                                "Host": ["$DOMAIN", "www.$DOMAIN"],
                                "User-Agent": [
                                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                                    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
                                ],
                                "Accept-Encoding": ["gzip, deflate"],
                                "Connection": ["keep-alive"],
                                "Pragma": "no-cache"
                            }
                        }
                    }
                },
                "sockopt": {
                    "tcpFastOpen": true,
                    "tcpNoDelay": true,
                    "tcpKeepAliveIdle": 300,
                    "tcpKeepAliveInterval": 30,
                    "tcpKeepAliveCount": 3,
                    "tcpCongestion": "bbr"
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": ["http", "tls", "quic"]
            }
        },
        {
            "port": 8443,
            "protocol": "vmess",
            "tag": "vmess-ws",
            "settings": {
                "clients": [
                    {
                        "id": "$XRAY_UUID",
                        "alterId": 0,
                        "email": "user@vmess"
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "/cdn-cgi/trace",
                    "headers": {
                        "Host": "$DOMAIN"
                    }
                },
                "sockopt": {
                    "tcpFastOpen": true,
                    "tcpNoDelay": true
                }
            }
        }
EOF
    
    # Add Reality config if keys are available
    if [ -n "$PRIVATE_KEY" ]; then
        cat >> /usr/local/etc/xray/config.json << EOF
        ,
        {
            "port": 2053,
            "protocol": "vless",
            "tag": "vless-reality",
            "settings": {
                "clients": [
                    {
                        "id": "$XRAY_UUID",
                        "flow": "xtls-rprx-vision",
                        "email": "user@reality"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "www.google.com:443",
                    "serverNames": ["www.google.com", "www.cloudflare.com", "$DOMAIN"],
                    "privateKey": "$PRIVATE_KEY",
                    "shortIds": ["", "0123456789abcdef"],
                    "fingerprint": "chrome",
                    "spiderX": "/"
                },
                "sockopt": {
                    "tcpFastOpen": true,
                    "tcpNoDelay": true
                }
            }
        }
EOF
    fi
    
    # Complete config
    cat >> /usr/local/etc/xray/config.json << EOF
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct",
            "settings": {
                "domainStrategy": "UseIPv4"
            },
            "streamSettings": {
                "sockopt": {
                    "mark": 255
                }
            }
        },
        {
            "protocol": "blackhole",
            "tag": "block",
            "settings": {}
        }
    ]
}
EOF
    
    # Generate certificates
    mkdir -p /etc/xray
    openssl ecparam -genkey -name prime256v1 -out /etc/xray/key.pem
    openssl req -new -key /etc/xray/key.pem -x509 -days 365 \
        -subj "/C=US/ST=California/L=San Francisco/O=Cloudflare, Inc./CN=$DOMAIN" \
        -out /etc/xray/cert.pem
    
    # Create log directory
    mkdir -p /var/log/xray
    
    # Create systemd service with optimizations
    cat > /etc/systemd/system/xray.service << EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
User=nobody
Group=nogroup
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_RESOURCE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
LimitCORE=infinity
LimitMEMLOCK=infinity

# Security
PrivateTmp=true
PrivateDevices=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/xray /etc/xray

# Performance
CPUSchedulingPolicy=rr
CPUSchedulingPriority=10
Nice=-5
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and start Xray
    systemctl daemon-reload
    systemctl enable xray
    systemctl start xray
    
    echo -e "${GREEN}[✓] Xray installed and configured${NC}"
    echo -e "${BLUE}[*] Xray UUID: $XRAY_UUID${NC}"
    if [ -n "$PUBLIC_KEY" ]; then
        echo -e "${BLUE}[*] Reality Public Key: $PUBLIC_KEY${NC}"
    fi
}

# =====================================================
# WIREGUARD SETUP
# =====================================================
setup_wireguard() {
    echo -e "${YELLOW}[*] Setting up WireGuard...${NC}"
    
    apt-get install -y wireguard-tools
    
    # Generate keys
    mkdir -p /etc/wireguard
    cd /etc/wireguard
    wg genkey | tee privatekey | wg pubkey > publickey
    
    PRIVATE_KEY=$(cat privatekey)
    PUBLIC_KEY=$(cat publickey)
    
    # Create WireGuard config
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.10.10.1/24
PrivateKey = $PRIVATE_KEY
ListenPort = 51820
MTU = 1420
DNS = 1.1.1.1, 8.8.8.8

# Packet obfuscation
PostUp = iptables -t mangle -A POSTROUTING -p udp --dport 51820 -j TTL --ttl-set 64
PostUp = iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
PreDown = iptables -t mangle -D POSTROUTING -p udp --dport 51820 -j TTL --ttl-set 64
PreDown = iptables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

[Peer]
# Add peer configuration here
# PublicKey = <peer-public-key>
# AllowedIPs = 10.10.10.2/32
# Endpoint = <peer-ip>:51820
# PersistentKeepalive = 25
EOF
    
    # Enable WireGuard
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0
    
    echo -e "${GREEN}[✓] WireGuard configured${NC}"
    echo -e "${BLUE}[*] WireGuard Public Key: $PUBLIC_KEY${NC}"
    echo -e "${BLUE}[*] WireGuard IP: 10.10.10.1${NC}"
}

# =====================================================
# SHADOWSOCKS WITH OBFS
# =====================================================
setup_shadowsocks() {
    echo -e "${YELLOW}[*] Setting up Shadowsocks with obfuscation...${NC}"
    
    # Install Shadowsocks
    apt-get install -y shadowsocks-libev simple-obfs
    
    # Generate random password
    SS_PASSWORD=$(openssl rand -base64 32)
    
    # Create config
    cat > /etc/shadowsocks-libev/config.json << EOF
{
    "server": "0.0.0.0",
    "server_port": 8388,
    "password": "$SS_PASSWORD",
    "method": "chacha20-ietf-poly1305",
    "mode": "tcp_and_udp",
    "fast_open": true,
    "no_delay": true,
    "plugin": "obfs-server",
    "plugin_opts": "obfs=http;obfs-host=www.cloudflare.com",
    "timeout": 300,
    "udp_timeout": 300,
    "nameserver": "1.1.1.1"
}
EOF
    
    # Create systemd service
    cat > /etc/systemd/system/shadowsocks.service << EOF
[Unit]
Description=Shadowsocks-libev
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
LimitNOFILE=32768
ExecStart=/usr/bin/ss-server -c /etc/shadowsocks-libev/config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable shadowsocks
    systemctl start shadowsocks
    
    echo -e "${GREEN}[✓] Shadowsocks configured${NC}"
    echo -e "${BLUE}[*] Port: 8388${NC}"
    echo -e "${BLUE}[*] Password: $SS_PASSWORD${NC}"
}

# =====================================================
# TRAFFIC RANDOMIZATION & ANTI-DPI
# =====================================================
setup_anti_dpi() {
    echo -e "${YELLOW}[*] Setting up anti-DPI measures...${NC}"
    
    # Create traffic randomization script
    cat > /usr/local/bin/traffic-randomizer.sh << 'EOF'
#!/bin/bash
# Traffic Randomization Script

INTERFACE=$(ip route | grep default | awk '{print $5}')

while true; do
    # Randomize packet timing
    DELAY=$((5 + RANDOM % 20))
    JITTER=$((1 + RANDOM % 10))
    
    # Apply netem to randomize traffic
    tc qdisc change dev $INTERFACE root netem \
        delay ${DELAY}ms ${JITTER}ms \
        loss $((RANDOM % 2))% \
        duplicate $((RANDOM % 1))% \
        corrupt $((RANDOM % 1))% \
        reorder $((RANDOM % 5))% 50%
    
    # Change TTL randomly
    NEW_TTL=$((64 + RANDOM % 64))
    iptables -t mangle -D POSTROUTING -j TTL --ttl-set $NEW_TTL 2>/dev/null || true
    iptables -t mangle -A POSTROUTING -j TTL --ttl-set $NEW_TTL
    
    # Randomize MSS
    NEW_MSS=$((1200 + RANDOM % 200))
    iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss $NEW_MSS 2>/dev/null || true
    iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss $NEW_MSS
    
    # Sleep for random interval (5-15 minutes)
    sleep $((300 + RANDOM % 600))
done
EOF
    
    chmod +x /usr/local/bin/traffic-randomizer.sh
    
    # Create service for traffic randomizer
    cat > /etc/systemd/system/traffic-randomizer.service << EOF
[Unit]
Description=Traffic Randomization Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/traffic-randomizer.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Apply initial iptables rules
    iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64
    iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    
    # Disable TCP timestamps
    echo 0 > /proc/sys/net/ipv4/tcp_timestamps
    
    # Start service
    systemctl daemon-reload
    systemctl enable traffic-randomizer
    systemctl start traffic-randomizer
    
    echo -e "${GREEN}[✓] Anti-DPI measures configured${NC}"
}

# =====================================================
# MONITORING & AUTO-RECOVERY
# =====================================================
setup_monitoring() {
    echo -e "${YELLOW}[*] Setting up monitoring system...${NC}"
    
    # Create monitoring script
    cat > /usr/local/bin/tunnel-monitor.sh << 'EOF'
#!/bin/bash
# Tunnel Monitoring and Auto-Recovery

LOG_FILE="/var/log/tunnel-monitor.log"
MAX_FAILURES=3
FAILURE_COUNT=0

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

check_service() {
    local service=$1
    if systemctl is-active --quiet $service; then
        return 0
    else
        log_message "Service $service is not running"
        return 1
    fi
}

check_port() {
    local port=$1
    if nc -z localhost $port 2>/dev/null; then
        return 0
    else
        log_message "Port $port is not listening"
        return 1
    fi
}

check_gre_tunnel() {
    if ip link show gre1 >/dev/null 2>&1; then
        if ping -c 2 -W 1 10.200.0.2 >/dev/null 2>&1; then
            return 0
        else
            log_message "GRE tunnel is up but cannot ping remote"
            return 1
        fi
    else
        log_message "GRE tunnel is down"
        return 1
    fi
}

recover_tunnel() {
    log_message "Attempting to recover tunnel..."
    
    # Restart services
    systemctl restart xray 2>/dev/null
    systemctl restart shadowsocks 2>/dev/null
    systemctl restart wg-quick@wg0 2>/dev/null
    
    # Restart GRE tunnel
    ip link set gre1 down 2>/dev/null
    sleep 1
    ip link set gre1 up 2>/dev/null
    
    # Flush conntrack
    conntrack -F 2>/dev/null || true
    
    log_message "Recovery attempt completed"
}

# Main monitoring loop
while true; do
    FAILURES=0
    
    # Check services
    check_service xray || FAILURES=$((FAILURES + 1))
    check_service shadowsocks || FAILURES=$((FAILURES + 1))
    
    # Check ports
    check_port 443 || FAILURES=$((FAILURES + 1))
    check_port 8443 || FAILURES=$((FAILURES + 1))
    
    # Check GRE tunnel
    check_gre_tunnel || FAILURES=$((FAILURES + 1))
    
    # Take action if too many failures
    if [ $FAILURES -ge $MAX_FAILURES ]; then
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        log_message "High failure count: $FAILURES failures (total: $FAILURE_COUNT)"
        
        if [ $FAILURE_COUNT -ge 3 ]; then
            log_message "Critical failure threshold reached, recovering..."
            recover_tunnel
            FAILURE_COUNT=0
        fi
    else
        FAILURE_COUNT=0
        log_message "All systems normal"
    fi
    
    # Sleep before next check
    sleep 60
done
EOF
    
    chmod +x /usr/local/bin/tunnel-monitor.sh
    
    # Create systemd service
    cat > /etc/systemd/system/tunnel-monitor.service << EOF
[Unit]
Description=Tunnel Monitoring Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/tunnel-monitor.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Create log rotation
    cat > /etc/logrotate.d/tunnel-monitor << EOF
/var/log/tunnel-monitor.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
}
EOF
    
    # Start monitoring
    systemctl daemon-reload
    systemctl enable tunnel-monitor
    systemctl start tunnel-monitor
    
    echo -e "${GREEN}[✓] Monitoring system configured${NC}"
}

# =====================================================
# FORWARDING RULES
# =====================================================
setup_forwarding() {
    echo -e "${YELLOW}[*] Setting up port forwarding...${NC}"
    
    # Get interface
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # Clear existing rules
    iptables -F
    iptables -t nat -F
    iptables -X
    
    # Set default policies
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Allow established connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Allow SSH (change port if needed)
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # Allow tunnel ports
    for port in 443 8443 8388 51820 2053; do
        iptables -A INPUT -p tcp --dport $port -j ACCEPT
        iptables -A INPUT -p udp --dport $port -j ACCEPT
    done
    
    # Forward GRE tunnel traffic
    if [ -f "/etc/gre-tunnel.conf" ]; then
        source /etc/gre-tunnel.conf
        iptables -A FORWARD -i $INTERFACE -o $GRE_NAME -j ACCEPT
        iptables -A FORWARD -i $GRE_NAME -o $INTERFACE -j ACCEPT
        iptables -t nat -A POSTROUTING -o $GRE_NAME -j MASQUERADE
    fi
    
    # Save rules
    iptables-save > /etc/iptables/rules.v4
    
    echo -e "${GREEN}[✓] Forwarding rules configured${NC}"
}

# =====================================================
# CLIENT CONFIG GENERATOR
# =====================================================
generate_client_config() {
    echo -e "${YELLOW}[*] Generating client configurations...${NC}"
    
    # Read Xray UUID from config
    XRAY_UUID=$(grep -o '"id": "[^"]*"' /usr/local/etc/xray/config.json | head -1 | cut -d'"' -f4)
    
    # Get server IP
    SERVER_IP=$(get_public_ip)
    
    # Generate Xray client config
    cat > /root/xray-client.json << EOF
{
    "log": {"loglevel": "warning"},
    "inbounds": [
        {
            "port": 1080,
            "listen": "127.0.0.1",
            "protocol": "socks",
            "settings": {
                "auth": "noauth",
                "udp": true
            }
        },
        {
            "port": 1081,
            "listen": "127.0.0.1",
            "protocol": "http",
            "settings": {
                "allowTransparent": false
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "vless",
            "settings": {
                "vnext": [
                    {
                        "address": "$SERVER_IP",
                        "port": 443,
                        "users": [
                            {
                                "id": "$XRAY_UUID",
                                "encryption": "none",
                                "flow": "xtls-rprx-vision"
                            }
                        ]
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "serverName": "$DOMAIN",
                    "alpn": ["h2", "http/1.1"]
                }
            },
            "tag": "proxy"
        }
    ],
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "ip": ["geoip:ir"],
                "outboundTag": "proxy"
            },
            {
                "type": "field",
                "domain": ["geosite:category-ads-all"],
                "outboundTag": "direct"
            }
        ]
    }
}
EOF
    
    # Generate QR code for easy sharing
    if command -v qrencode >/dev/null 2>&1; then
        apt-get install -y qrencode
        CONFIG_URL="vless://$XRAY_UUID@$SERVER_IP:443?security=tls&sni=$DOMAIN&flow=xtls-rprx-vision&type=tcp#Advanced-Tunnel"
        echo "$CONFIG_URL" | qrencode -o /root/xray-config.png
        echo -e "${GREEN}[✓] QR code generated: /root/xray-config.png${NC}"
    fi
    
    echo -e "${GREEN}[✓] Client config generated: /root/xray-client.json${NC}"
    echo -e "${BLUE}[*] Server IP: $SERVER_IP${NC}"
    echo -e "${BLUE}[*] Xray UUID: $XRAY_UUID${NC}"
}

# =====================================================
# MAIN INSTALLATION FUNCTION
# =====================================================
install_complete() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║         ADVANCED TUNNEL SYSTEM - COMPLETE INSTALL        ║
║                  Multi-Layer Anti-DPI                    ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    check_root
    
    # Get server role
    echo -e "${YELLOW}Select server role:${NC}"
    echo "1) Iran Server (Local - For forwarding traffic)"
    echo "2) Kharej Server (Foreign - Main proxy server)"
    echo "3) Both (Advanced setup)"
    read -p "Choice [1-3]: " ROLE_CHOICE
    
    case $ROLE_CHOICE in
        1)
            echo -e "${GREEN}[*] Installing Iran Server...${NC}"
            SERVER_ROLE="iran"
            ;;
        2)
            echo -e "${GREEN}[*] Installing Kharej Server...${NC}"
            SERVER_ROLE="kharej"
            ;;
        3)
            echo -e "${GREEN}[*] Installing Complete Setup...${NC}"
            SERVER_ROLE="both"
            ;;
        *)
            echo -e "${RED}[!] Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    # Analyze network
    analyze_dpi
    
    # Install prerequisites
    install_prerequisites
    
    # Optimize network
    optimize_network
    
    if [ "$SERVER_ROLE" = "iran" ] || [ "$SERVER_ROLE" = "both" ]; then
        # Iran server setup
        echo -e "${YELLOW}[*] Setting up Iran server components...${NC}"
        setup_gre_tunnel
        setup_forwarding
    fi
    
    if [ "$SERVER_ROLE" = "kharej" ] || [ "$SERVER_ROLE" = "both" ]; then
        # Kharej server setup
        echo -e "${YELLOW}[*] Setting up Kharej server components...${NC}"
        install_xray
        setup_wireguard
        setup_shadowsocks
        setup_anti_dpi
        setup_monitoring
        generate_client_config
    fi
    
    # Final optimization
    echo -e "${YELLOW}[*] Performing final optimizations...${NC}"
    
    # Increase file descriptors
    echo "* soft nofile 512000" >> /etc/security/limits.conf
    echo "* hard nofile 512000" >> /etc/security/limits.conf
    
    # Enable BBR Fast
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    
    # Disable IPv6 if not needed
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
    
    sysctl -p
    
    # Display completion message
    echo -e "${GREEN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                   INSTALLATION COMPLETE!                 ║
╠══════════════════════════════════════════════════════════╣
║ ✅ Prerequisites installed                               ║
║ ✅ Network optimized                                     ║
║ ✅ GRE Tunnel configured                                 ║
║ ✅ Xray installed with multiple protocols                ║
║ ✅ WireGuard configured                                  ║
║ ✅ Shadowsocks with obfuscation                          ║
║ ✅ Anti-DPI measures applied                             ║
║ ✅ Monitoring system active                              ║
║ ✅ Forwarding rules configured                           ║
║ ✅ Client configurations generated                       ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Show summary
    echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}[*] Service Status:${NC}"
    systemctl status xray --no-pager | head -10
    echo ""
    
    echo -e "${CYAN}[*] Active Ports:${NC}"
    ss -tulpn | grep -E ':443|:8443|:8388|:51820|:2053'
    echo ""
    
    echo -e "${CYAN}[*] Network Interfaces:${NC}"
    ip addr show | grep -E "inet.*(eth|ens|gre|wg)" | head -10
    echo ""
    
    echo -e "${CYAN}[*] Configuration Files:${NC}"
    echo "/usr/local/etc/xray/config.json"
    echo "/etc/wireguard/wg0.conf"
    echo "/etc/shadowsocks-libev/config.json"
    echo "/etc/gre-tunnel.conf"
    echo ""
    
    echo -e "${CYAN}[*] Client Config:${NC}"
    echo "Located at: /root/xray-client.json"
    
    if [ -f "/root/xray-config.png" ]; then
        echo "QR Code: /root/xray-config.png"
    fi
    
    echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}[✓] Installation completed successfully!${NC}"
    echo -e "${YELLOW}[!] Please reboot the server for all changes to take effect.${NC}"
}

# =====================================================
# UNINSTALL FUNCTION
# =====================================================
uninstall_all() {
    echo -e "${RED}[!] Uninstalling everything...${NC}"
    
    # Stop all services
    systemctl stop xray 2>/dev/null || true
    systemctl stop shadowsocks 2>/dev/null || true
    systemctl stop wg-quick@wg0 2>/dev/null || true
    systemctl stop tunnel-monitor 2>/dev/null || true
    systemctl stop traffic-randomizer 2>/dev/null || true
    
    # Remove tunnels
    ip link del gre1 2>/dev/null || true
    ip link del wg0 2>/dev/null || true
    
    # Remove configurations
    rm -rf /usr/local/etc/xray
    rm -rf /etc/wireguard
    rm -rf /etc/shadowsocks-libev
    rm -f /etc/gre-tunnel.conf
    
    # Remove scripts
    rm -f /usr/local/bin/traffic-randomizer.sh
    rm -f /usr/local/bin/tunnel-monitor.sh
    
    # Remove systemd services
    systemctl disable xray 2>/dev/null || true
    systemctl disable shadowsocks 2>/dev/null || true
    systemctl disable wg-quick@wg0 2>/dev/null || true
    systemctl disable tunnel-monitor 2>/dev/null || true
    systemctl disable traffic-randomizer 2>/dev/null || true
    
    rm -f /etc/systemd/system/xray.service
    rm -f /etc/systemd/system/shadowsocks.service
    rm -f /etc/systemd/system/tunnel-monitor.service
    rm -f /etc/systemd/system/traffic-randomizer.service
    
    # Clear iptables
    iptables -F
    iptables -t nat -F
    iptables -X
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    # Remove log files
    rm -rf /var/log/xray
    rm -f /var/log/tunnel-monitor.log
    
    # Remove client configs
    rm -f /root/xray-client.json
    rm -f /root/xray-config.png
    
    echo -e "${GREEN}[✓] Uninstallation complete!${NC}"
}

# =====================================================
# STATUS CHECK
# =====================================================
check_status() {
    echo -e "${CYAN}[*] System Status Check${NC}"
    echo "══════════════════════════════════════════════════════════"
    
    # Check services
    echo -e "${YELLOW}Services:${NC}"
    for service in xray shadowsocks wg-quick@wg0 tunnel-monitor traffic-randomizer; do
        if systemctl is-active --quiet $service; then
            echo -e "  ${GREEN}✓ $service${NC}"
        else
            echo -e "  ${RED}✗ $service${NC}"
        fi
    done
    
    # Check tunnels
    echo -e "\n${YELLOW}Tunnels:${NC}"
    if ip link show gre1 &>/dev/null; then
        echo -e "  ${GREEN}✓ GRE tunnel (gre1)${NC}"
        ip addr show gre1 | grep inet
    else
        echo -e "  ${RED}✗ GRE tunnel${NC}"
    fi
    
    if ip link show wg0 &>/dev/null; then
        echo -e "  ${GREEN}✓ WireGuard (wg0)${NC}"
    else
        echo -e "  ${RED}✗ WireGuard${NC}"
    fi
    
    # Check ports
    echo -e "\n${YELLOW}Listening Ports:${NC}"
    for port in 443 8443 8388 51820 2053; do
        if ss -tulpn | grep ":$port" &>/dev/null; then
            echo -e "  ${GREEN}✓ Port $port${NC}"
        else
            echo -e "  ${RED}✗ Port $port${NC}"
        fi
    done
    
    # Check connectivity
    echo -e "\n${YELLOW}Connectivity:${NC}"
    if ping -c 2 -W 1 8.8.8.8 &>/dev/null; then
        echo -e "  ${GREEN}✓ Internet${NC}"
    else
        echo -e "  ${RED}✗ Internet${NC}"
    fi
    
    # Check IP
    IP=$(get_public_ip)
    echo -e "  ${BLUE}● Public IP: $IP${NC}"
    
    # Check resource usage
    echo -e "\n${YELLOW}Resource Usage:${NC}"
    echo "  CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
    echo "  Memory: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
    
    echo "══════════════════════════════════════════════════════════"
}

# =====================================================
# MAIN MENU
# =====================================================
main_menu() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║         ADVANCED TUNNEL SYSTEM - CONTROL PANEL           ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo "1) Complete Installation (Recommended)"
    echo "2) Install Iran Server only"
    echo "3) Install Kharej Server only"
    echo "4) Check System Status"
    echo "5) Generate Client Config"
    echo "6) Optimize Network"
    echo "7) Uninstall Everything"
    echo "8) Exit"
    echo ""
    
    read -p "Select option [1-8]: " choice
    
    case $choice in
        1)
            install_complete
            ;;
        2)
            SERVER_ROLE="iran"
            check_root
            install_prerequisites
            optimize_network
            setup_gre_tunnel
            setup_forwarding
            setup_monitoring
            ;;
        3)
            SERVER_ROLE="kharej"
            check_root
            install_prerequisites
            optimize_network
            install_xray
            setup_wireguard
            setup_shadowsocks
            setup_anti_dpi
            setup_monitoring
            generate_client_config
            ;;
        4)
            check_status
            ;;
        5)
            generate_client_config
            ;;
        6)
            optimize_network
            ;;
        7)
            uninstall_all
            ;;
        8)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${RED}[!] Invalid option${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# =====================================================
# SCRIPT ENTRY POINT
# =====================================================
if [ $# -eq 0 ]; then
    # Interactive mode
    while true; do
        main_menu
    done
else
    # Command line mode
    case $1 in
        install)
            install_complete
            ;;
        iran)
            SERVER_ROLE="iran"
            check_root
            install_prerequisites
            optimize_network
            setup_gre_tunnel
            setup_forwarding
            setup_monitoring
            ;;
        kharej)
            SERVER_ROLE="kharej"
            check_root
            install_prerequisites
            optimize_network
            install_xray
            setup_wireguard
            setup_shadowsocks
            setup_anti_dpi
            setup_monitoring
            generate_client_config
            ;;
        status)
            check_status
            ;;
        optimize)
            optimize_network
            ;;
        uninstall)
            uninstall_all
            ;;
        *)
            echo "Usage: $0 {install|iran|kharej|status|optimize|uninstall}"
            echo "Or run without arguments for interactive menu"
            exit 1
            ;;
    esac
fi
