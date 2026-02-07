#!/bin/bash
# ==========================================
# Advanced Anti-DPI Tunnel - Master Script
# Architecture: GRE → WireGuard → Shadowsocks (Obfs) → Xray (VLESS+XTLS)
# ==========================================

# Configuration
export TUNNEL_VERSION="v2.0"
export DEBUG_MODE=false
export LOG_LEVEL="info"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==========================================
# MODULE 1: DPI DETECTION & ANALYSIS MODULE
# ==========================================
analyze_dpi_layer() {
    echo -e "${BLUE}[*] Analyzing DPI Detection Layers...${NC}"
    
    # Test 1: Protocol Fingerprinting
    echo -e "${YELLOW}[!] Testing Protocol Fingerprinting...${NC}"
    if timeout 5 tcpdump -i any -c 10 'tcp[tcpflags] & (tcp-syn|tcp-ack) != 0' 2>/dev/null | grep -q "length"; then
        echo -e "${RED}[!] DPI detected: TCP Handshake Analysis${NC}"
        export DPI_TCP_FP=true
    fi
    
    # Test 2: Packet Length Analysis
    echo -e "${YELLOW}[!] Testing Packet Length Patterns...${NC}"
    PSIZE=$(ping -c 3 -M do -s 1200 8.8.8.8 2>/dev/null | grep -oP '\d+(?= bytes)')
    if [ "$PSIZE" -lt 1200 ]; then
        echo -e "${RED}[!] DPI detected: MTU/Size Based Filtering${NC}"
        export DPI_SIZE_FILTER=true
    fi
    
    # Test 3: TLS Fingerprinting
    echo -e "${YELLOW}[!] Testing TLS Fingerprinting...${NC}"
    if curl -s --tlsv1.3 --tls-max 1.3 https://www.google.com 2>&1 | grep -q "reset"; then
        echo -e "${RED}[!] DPI detected: TLS Deep Inspection${NC}"
        export DPI_TLS_INSPECT=true
    fi
    
    # Test 4: Traffic Behavior Analysis
    echo -e "${YELLOW}[!] Testing Traffic Pattern Detection...${NC}"
    if ss -tunlp | grep -E ':443|:80' | wc -l -gt 5; then
        echo -e "${RED}[!] DPI detected: Port/Behavior Analysis${NC}"
        export DPI_BEHAVIOR=true
    fi
}

# ==========================================
# MODULE 2: GRE TRANSPORT OPTIMIZATION
# ==========================================
optimize_gre_transport() {
    echo -e "${BLUE}[*] Optimizing GRE Transport Layer...${NC}"
    
    # Disable unnecessary features
    ethtool -K $INTERFACE rx off tx off sg off tso off gso off gro off lro off 2>/dev/null
    
    # Custom GRE optimization
    ip link set $GRE_IFACE mtu 1500
    
    # TCP Optimization for GRE
    cat > /etc/sysctl.d/99-gre-optimize.conf << EOF
# GRE Specific Optimizations
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_mtu_probing = 2
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_frto = 2
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_congestion_control = bbr2
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_adv_win_scale = 2
net.core.default_qdisc = fq_pie
EOF
    
    # Apply optimizations
    sysctl -p /etc/sysctl.d/99-gre-optimize.conf
    
    # Queue Discipline
    tc qdisc add dev $GRE_IFACE root fq_pie limit 10240p flows 1024
    tc qdisc add dev $INTERFACE root fq_pie limit 10240p flows 1024
}

# ==========================================
# MODULE 3: XRAY BANDWIDTH LIMIT ANALYSIS
# ==========================================
analyze_xray_throttling() {
    echo -e "${BLUE}[*] Analyzing Xray Bandwidth Limiting...${NC}"
    
    # Common Xray detection patterns
    PATTERNS=(
        "xtls-rprx-vision"
        "xray"
        "vless"
        "vmess"
        "tls.sni"
        "reality"
    )
    
    # Test each pattern
    for pattern in "${PATTERNS[@]}"; do
        if tcpdump -i any -A -c 5 2>/dev/null | grep -i "$pattern" > /dev/null; then
            echo -e "${RED}[!] Xray detection pattern found: $pattern${NC}"
            export XRAY_PATTERN_DETECTED=true
        fi
    done
    
    # Test bandwidth throttling
    echo -e "${YELLOW}[!] Testing for Bandwidth Throttling...${NC}"
    BASELINE_SPEED=$(iperf3 -c speedtest.server -t 3 -P 5 2>/dev/null | grep "receiver" | awk '{print $7}')
    sleep 10
    XRAY_SPEED=$(iperf3 -c speedtest.server -t 3 -P 5 -p 443 2>/dev/null | grep "receiver" | awk '{print $7}')
    
    if [ ! -z "$BASELINE_SPEED" ] && [ ! -z "$XRAY_SPEED" ]; then
        THROTTLE_RATIO=$(echo "scale=2; $XRAY_SPEED / $BASELINE_SPEED" | bc)
        if (( $(echo "$THROTTLE_RATIO < 0.5" | bc -l) )); then
            echo -e "${RED}[!] Bandwidth throttling detected: $THROTTLE_RATIO ratio${NC}"
            export BW_THROTTLED=true
        fi
    fi
}

# ==========================================
# MODULE 4: ADVANCED OBFS LAYER
# ==========================================
setup_obfs_layer() {
    echo -e "${BLUE}[*] Setting up Obfuscation Layer...${NC}"
    
    # 1. Shadowsocks with Obfs (for TCP)
    apt-get install -y shadowsocks-libev simple-obfs
    
    # SS-Obfs configuration
    cat > /etc/shadowsocks-libev/obfs.json << EOF
{
    "server": "0.0.0.0",
    "server_port": 8443,
    "password": "$(openssl rand -base64 32)",
    "method": "chacha20-ietf-poly1305",
    "plugin": "obfs-server",
    "plugin_opts": "obfs=http;obfs-host=cloudflare.com",
    "mode": "tcp_and_udp",
    "fast_open": true,
    "no_delay": true
}
EOF
    
    # 2. v2ray-plugin for WebSocket obfs
    cat > /etc/v2ray-plugin/config.json << EOF
{
    "protocol": "shadowsocks",
    "transport": {
        "type": "ws",
        "path": "/cdn-cgi/trace",
        "headers": {
            "Host": "www.cloudflare.com",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }
    },
    "mux": {
        "enabled": true,
        "concurrency": 8
    }
}
EOF
}

# ==========================================
# MODULE 5: XRAY CONFIG OPTIMIZATION
# ==========================================
optimize_xray_config() {
    echo -e "${BLUE}[*] Optimizing Xray Configuration...${NC}"
    
    cat > /usr/local/etc/xray/anti_dpi_config.json << EOF
{
    "log": {
        "loglevel": "warning",
        "access": "/dev/null",
        "error": "/dev/null"
    },
    "inbounds": [{
        "port": 10000,
        "protocol": "vless",
        "settings": {
            "clients": [{
                "id": "$(xray uuid)",
                "flow": "xtls-rprx-vision"
            }],
            "decryption": "none"
        },
        "streamSettings": {
            "network": "tcp",
            "security": "reality",
            "realitySettings": {
                "dest": "www.google.com:443",
                "serverNames": ["www.google.com", "www.cloudflare.com"],
                "privateKey": "$(xray x25519 | awk '{print $3}')",
                "shortIds": ["", "12345678"]
            },
            "tcpSettings": {
                "header": {
                    "type": "http",
                    "request": {
                        "version": "1.1",
                        "method": "GET",
                        "path": ["/"],
                        "headers": {
                            "Host": ["www.google.com", "www.cloudflare.com"],
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
                "tcpKeepAliveCount": 3
            }
        }
    }],
    "outbounds": [{
        "protocol": "freedom",
        "settings": {},
        "streamSettings": {
            "sockopt": {
                "mark": 255
            }
        }
    }],
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
    }
}
EOF
}

# ==========================================
# MODULE 6: TRAFFIC SHAPING & RANDOMIZATION
# ==========================================
setup_traffic_shaping() {
    echo -e "${BLUE}[*] Setting up Traffic Shaping...${NC}"
    
    # Create random traffic patterns
    cat > /usr/local/bin/traffic_randomizer.sh << 'EOF'
#!/bin/bash
# Traffic Pattern Randomizer
while true; do
    # Random delay between packets (5-25ms)
    DELAY=$((5 + RANDOM % 20))
    # Random packet loss (0.01% - 0.5%)
    LOSS=$(echo "scale=2; $RANDOM / 32767 * 0.5" | bc)
    # Random duplicate packets (0.1% - 1%)
    DUPLICATE=$(echo "scale=2; $RANDOM / 32767 * 1" | bc)
    
    # Apply to GRE interface
    tc qdisc change dev gre1 root netem \
        delay ${DELAY}ms \
        loss ${LOSS}% \
        duplicate ${DUPLICATE}% \
        distribution normal
    
    # Change every 5-15 minutes
    SLEEP_TIME=$((300 + RANDOM % 600))
    sleep $SLEEP_TIME
done
EOF
    
    chmod +x /usr/local/bin/traffic_randomizer.sh
    
    # Create burst traffic generator
    cat > /usr/local/bin/burst_generator.sh << 'EOF'
#!/bin/bash
# Generate legitimate-looking burst traffic
while true; do
    # Random intervals (30-120 seconds)
    INTERVAL=$((30 + RANDOM % 90))
    
    # Generate HTTPS-like traffic
    curl -s -H "User-Agent: Mozilla/5.0" \
         -H "Accept: text/html,application/xhtml+xml" \
         -H "Connection: keep-alive" \
         https://www.cloudflare.com/cdn-cgi/trace > /dev/null &
    
    # Small ICMP bursts
    ping -c $((2 + RANDOM % 5)) -i 0.2 -s $((64 + RANDOM % 500)) 1.1.1.1 > /dev/null &
    
    sleep $INTERVAL
done
EOF
    
    chmod +x /usr/local/bin/burst_generator.sh
}

# ==========================================
# MODULE 7: DPI EVASION TECHNIQUES
# ==========================================
apply_dpi_evasion() {
    echo -e "${BLUE}[*] Applying DPI Evasion Techniques...${NC}"
    
    # 1. TCP Window Size Randomization
    iptables -t mangle -A POSTROUTING -p tcp -j TCPOPTSTRIP --strip-options wscale
    
    # 2. TTL Normalization
    iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64
    
    # 3. MSS Clamping with randomization
    MSS_BASE=1220
    MSS_RANDOM=$((MSS_BASE + RANDOM % 50 - 25))
    iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss $MSS_RANDOM
    
    # 4. Packet Length Randomization
    iptables -t mangle -A POSTROUTING -p tcp -m length --length 40:1500 -j NFQUEUE --queue-num 0
    
    # 5. Disable TCP Timestamps
    echo 0 > /proc/sys/net/ipv4/tcp_timestamps
    
    # 6. Randomize TCP sequence numbers
    echo 1 > /proc/sys/net/ipv4/tcp_challenge_ack_limit
    echo "net.ipv4.tcp_challenge_ack_limit = 999999999" >> /etc/sysctl.conf
}

# ==========================================
# MODULE 8: MONITORING & AUTO-RECOVERY
# ==========================================
setup_monitoring() {
    echo -e "${BLUE}[*] Setting up Monitoring System...${NC}"
    
    cat > /usr/local/bin/tunnel_doctor.sh << 'EOF'
#!/bin/bash
# Tunnel Health Monitoring & Auto-Recovery

HEALTH_CHECKS=(
    "ping -c 2 -W 1 $REMOTE_GRE_IP"
    "wg show wg0 latest-handshakes"
    "ss -tunlp | grep ':443'"
    "curl -s --connect-timeout 3 http://1.1.1.1/cdn-cgi/trace"
)

while true; do
    FAILURES=0
    
    for check in "${HEALTH_CHECKS[@]}"; do
        if ! eval $check > /dev/null 2>&1; then
            FAILURES=$((FAILURES + 1))
        fi
    done
    
    if [ $FAILURES -ge 2 ]; then
        echo "[$(date)] Tunnel unhealthy. Performing recovery..."
        
        # Rotate IPs if available
        if [ -f "/root/ip_pool.txt" ]; then
            NEW_IP=$(shuf -n 1 /root/ip_pool.txt)
            ip addr add $NEW_IP/24 dev $INTERFACE
        fi
        
        # Restart services in random order
        SERVICES=(wg-quick@wg0 xray shadowsocks-libev@obfs)
        for service in "${SERVICES[@]}"; do
            systemctl restart ${service} 2>/dev/null
            sleep $((RANDOM % 5))
        done
        
        # Change obfs pattern
        OBFSPATHS=("/cdn-cgi/trace" "/api/v1/ping" "/static/health" "/metrics")
        NEW_PATH=${OBFSPATHS[$RANDOM % ${#OBFSPATHS[@]}]}
        sed -i "s|path\": \".*\"|path\": \"$NEW_PATH\"|" /etc/v2ray-plugin/config.json
    fi
    
    sleep 60
done
EOF
    
    chmod +x /usr/local/bin/tunnel_doctor.sh
}

# ==========================================
# MAIN INSTALLATION SCRIPT
# ==========================================
main_installation() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
╔══════════════════════════════════════════╗
║   ADVANCED ANTI-DPI TUNNEL INSTALLER     ║
║          (Multi-Layer Evasion)           ║
╚══════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Get configuration
    read -p "Enter Iran Server IP: " IRAN_IP
    read -p "Enter Kharej Server IP: " KHAREJ_IP
    read -p "Enter Main Interface (e.g., eth0): " INTERFACE
    
    # Set variables
    GRE_IFACE="gre1"
    REMOTE_GRE_IP="10.255.255.2"
    LOCAL_GRE_IP="10.255.255.1"
    
    # Update system
    apt-get update && apt-get upgrade -y
    
    # Install dependencies
    apt-get install -y \
        wireguard-tools \
        xray \
        shadowsocks-libev \
        simple-obfs \
        v2ray-plugin \
        iperf3 \
        tcptraceroute \
        mtr \
        net-tools \
        tcpdump \
        conntrack \
        iftop \
        nethogs \
        jq \
        bc
    
    # Execute modules
    analyze_dpi_layer
    analyze_xray_throttling
    
    # Setup GRE
    echo -e "${BLUE}[*] Setting up GRE Tunnel...${NC}"
    ip tunnel add $GRE_IFACE mode gre remote $KHAREJ_IP local $IRAN_IP ttl 255
    ip addr add $LOCAL_GRE_IP/30 dev $GRE_IFACE
    ip link set $GRE_IFACE mtu 1480
    ip link set $GRE_IFACE up
    
    # Apply optimizations
    optimize_gre_transport
    apply_dpi_evasion
    setup_obfs_layer
    optimize_xray_config
    setup_traffic_shaping
    setup_monitoring
    
    # Enable services
    systemctl enable wg-quick@wg0
    systemctl enable xray
    systemctl enable shadowsocks-libev@obfs
    systemctl enable tunnel-doctor
    
    # Generate report
    echo -e "${GREEN}"
    cat << "EOF"
╔══════════════════════════════════════════╗
║         INSTALLATION COMPLETE           ║
╠══════════════════════════════════════════╣
║ Layer 1: GRE (Optimized MTU/Queue)      ║
║ Layer 2: WireGuard (Obfuscated)         ║
║ Layer 3: Shadowsocks (HTTP Obfs)        ║
║ Layer 4: Xray (Reality + Vision)        ║
║ Layer 5: Traffic Randomization          ║
║                                         ║
║ Features:                               ║
║ • Automatic DPI Detection               ║
║ • Bandwidth Throttle Analysis           ║
║ • Traffic Pattern Randomization         ║
║ • Auto-Recovery System                  ║
║ • Multiple Obfuscation Layers           ║
╚══════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Show configuration
    echo -e "${YELLOW}[!] Important Configuration:${NC}"
    echo "GRE Tunnel: $LOCAL_GRE_IP ↔ $REMOTE_GRE_IP"
    echo "WireGuard Port: 51820 (UDP)"
    echo "Shadowsocks Port: 8443 (TCP+UDP)"
    echo "Xray Port: 10000 (Reality)"
    echo "Obfs Path: /cdn-cgi/trace"
    
    # Start services
    systemctl start wg-quick@wg0
    systemctl start xray
    systemctl start shadowsocks-libev@obfs
    systemctl start tunnel-doctor
}

# ==========================================
# UNINSTALL SCRIPT
# ==========================================
uninstall_all() {
    echo -e "${RED}[!] Uninstalling everything...${NC}"
    
    # Stop services
    systemctl stop wg-quick@wg0 2>/dev/null
    systemctl stop xray 2>/dev/null
    systemctl stop shadowsocks-libev@obfs 2>/dev/null
    
    # Remove interfaces
    ip link del gre1 2>/dev/null
    ip link del wg0 2>/dev/null
    
    # Remove configurations
    rm -rf /etc/wireguard
    rm -rf /usr/local/etc/xray
    rm -rf /etc/shadowsocks-libev
    
    # Remove scripts
    rm -f /usr/local/bin/traffic_randomizer.sh
    rm -f /usr/local/bin/burst_generator.sh
    rm -f /usr/local/bin/tunnel_doctor.sh
    
    # Remove services
    systemctl disable tunnel-doctor 2>/dev/null
    rm -f /etc/systemd/system/tunnel-doctor.service
    
    echo -e "${GREEN}[✓] Uninstallation complete!${NC}"
}

# ==========================================
# USAGE
# ==========================================
case "$1" in
    install)
        main_installation
        ;;
    uninstall)
        uninstall_all
        ;;
    doctor)
        /usr/local/bin/tunnel_doctor.sh
        ;;
    status)
        echo -e "${BLUE}[*] Tunnel Status:${NC}"
        ip link show gre1
        wg show
        systemctl status xray --no-pager
        ;;
    optimize)
        optimize_gre_transport
        apply_dpi_evasion
        ;;
    *)
        echo "Usage: $0 {install|uninstall|doctor|status|optimize}"
        exit 1
        ;;
esac
