#!/bin/bash
# =====================================================
# ADVANCED MTPROTO PROXY WITH XRAY INTEGRATION
# Architecture: MTProto → Xray (VLESS/Reality) → VXLAN
# =====================================================

set -e

# Configuration
export DOMAIN="cdn.microsoft.com"
export IRAN_IP="193.151.138.90"
export KHAREJ_IP="162.19.247.8"
export MTPROTO_PORT=443
export XRAY_PORT=8443
export FAKE_TLS_PORT=2053

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =====================================================
# MODULE 1: ADVANCED MTPROTO PROXY SETUP
# =====================================================
setup_mtproto_proxy() {
    echo -e "${BLUE}[*] Setting up Advanced MTProto Proxy...${NC}"
    
    # Install prerequisites
    apt-get update
    apt-get install -y \
        git \
        build-essential \
        zlib1g-dev \
        libssl-dev \
        libevent-dev \
        python3 \
        python3-pip \
        cmake
    
    # Clone and build MTProto proxy
    cd /tmp
    git clone https://github.com/TelegramMessenger/MTProxy
    cd MTProxy
    make
    
    # Generate secret with DD (Fake TLS) mode
    SECRET=$(head -c 16 /dev/urandom | xxd -ps)
    FAKE_TLS_DOMAIN="telegram.org"
    
    # Create configuration
    cat > /etc/mtproxy.conf << EOF
# MTProxy Configuration - Advanced Anti-DPI
port = ${MTPROTO_PORT}
secret = ${SECRET}
proxy_ip = 127.0.0.1
proxy_port = ${XRAY_PORT}
workers = $(nproc)
dd-only = true
tls-only = true
domain = ${FAKE_TLS_DOMAIN}
stats = false
allow-skip-dh = true
aes-pwd = $(openssl rand -hex 32)
user = nobody
group = nogroup

# Performance optimizations
stats-port = 8888
cpu-affinity = 0-$(($(nproc)-1))
nice = -10
tcp-keepalive = 60
tcp-fast-open = 512
tcp-nodelay = true
tcp-tw-reuse = true
tcp-tw-recycle = true

# Obfuscation settings
obfuscation = true
obfuscation-level = 2
obfuscation-secret = $(openssl rand -hex 16)

# Memory optimizations
max-connections = 100000
max-memory = 2048M
msg-buffer-size = 65536
read-buffer-size = 131072
write-buffer-size = 131072

# Logging (minimal)
log-level = 0
log-file = /dev/null
EOF
    
    # Create systemd service
    cat > /etc/systemd/system/mtproxy.service << EOF
[Unit]
Description=Advanced MTProto Proxy
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
LimitNOFILE=1000000
LimitNPROC=1000000
LimitCORE=infinity
WorkingDirectory=/tmp/MTProxy
ExecStart=/tmp/MTProxy/objs/bin/mtproto-proxy -c /etc/mtproxy.conf
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
CPUSchedulingPolicy=rr
CPUSchedulingPriority=99
Nice=-10

# Security
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/tmp

# Performance
OOMScoreAdjust=-1000
IOSchedulingClass=realtime
IOSchedulingPriority=0

[Install]
WantedBy=multi-user.target
EOF
    
    # Generate fake TLS certificate
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -subj "/C=US/ST=California/L=San Francisco/O=Telegram Messenger Inc/CN=${FAKE_TLS_DOMAIN}" \
        -keyout /etc/mtproxy/fake-tls.key \
        -out /etc/mtproxy/fake-tls.crt
    
    # Create wrapper for enhanced obfuscation
    cat > /usr/local/bin/mtproxy-wrapper.sh << 'EOF'
#!/bin/bash
# MTProxy Wrapper with Traffic Randomization

# Randomize packet timing
RANDOM_DELAY=$((RANDOM % 20 + 5))
tc qdisc add dev $INTERFACE root netem delay ${RANDOM_DELAY}ms 5ms 25%

# Start MTProxy with environmental protection
exec /tmp/MTProxy/objs/bin/mtproto-proxy \
    -c /etc/mtproxy.conf \
    --aes-pwd /etc/mtproxy/aes.key \
    --allow-skip-dh \
    --dd-only \
    --tls-only \
    --domain $FAKE_TLS_DOMAIN \
    --tls-cert /etc/mtproxy/fake-tls.crt \
    --tls-key /etc/mtproxy/fake-tls.key \
    --fake-tls \
    --obfuscation-level 2 \
    --stats=false \
    "$@"
EOF
    
    chmod +x /usr/local/bin/mtproxy-wrapper.sh
    
    # Create traffic randomizer
    cat > /usr/local/bin/mtproto-randomizer.sh << 'EOF'
#!/bin/bash
# MTProto Traffic Pattern Randomizer

while true; do
    # Change obfuscation parameters every 10-30 minutes
    SLEEP_TIME=$((600 + RANDOM % 1200))
    
    # Randomize MTProto secret (rotating)
    NEW_SECRET=$(head -c 16 /dev/urandom | xxd -ps)
    sed -i "s/secret = .*/secret = ${NEW_SECRET}/" /etc/mtproxy.conf
    
    # Randomize port between standard ports
    NEW_PORT=$(( RANDOM % 3 ))
    case $NEW_PORT in
        0) PORT=443 ;;
        1) PORT=8443 ;;
        2) PORT=2053 ;;
    esac
    sed -i "s/port = .*/port = ${PORT}/" /etc/mtproxy.conf
    
    # Randomize TCP options
    NEW_TFO=$((512 + RANDOM % 512))
    sed -i "s/tcp-fast-open = .*/tcp-fast-open = ${NEW_TFO}/" /etc/mtproxy.conf
    
    # Restart with new parameters
    systemctl restart mtproxy
    
    sleep $SLEEP_TIME
done
EOF
    
    chmod +x /usr/local/bin/mtproto-randomizer.sh
    
    echo -e "${GREEN}[+] MTProxy setup complete!${NC}"
    echo -e "${YELLOW}[!] Secret: ${SECRET}${NC}"
    echo -e "${YELLOW}[!] Fake-TLS Domain: ${FAKE_TLS_DOMAIN}${NC}"
}

# =====================================================
# MODULE 2: XRAY INTEGRATION WITH MTPROTO
# =====================================================
setup_xray_mtproto() {
    echo -e "${BLUE}[*] Setting up Xray with MTProto Integration...${NC}"
    
    # Install Xray
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    
    # Generate Xray configuration specifically for MTProto
    cat > /usr/local/etc/xray/config_mtproto.json << EOF
{
    "log": {
        "loglevel": "error",
        "error": "/dev/null"
    },
    "inbounds": [
        {
            "port": ${XRAY_PORT},
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$(xray uuid)",
                        "flow": "xtls-rprx-vision",
                        "email": "mtproto-user@telegram.org"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "none",
                "tcpSettings": {
                    "header": {
                        "type": "none"
                    },
                    "acceptProxyProtocol": true
                },
                "sockopt": {
                    "tcpFastOpen": true,
                    "tcpNoDelay": true,
                    "tcpKeepAliveIdle": 60,
                    "tcpKeepAliveInterval": 30,
                    "tcpKeepAliveCount": 3,
                    "tcpCongestion": "bbr",
                    "mark": 255
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": ["http", "tls", "quic"],
                "metadataOnly": false
            }
        },
        {
            "port": ${FAKE_TLS_PORT},
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$(xray uuid)",
                        "flow": ""
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "serverName": "${DOMAIN}",
                    "alpn": ["http/1.1", "h2"],
                    "certificates": [
                        {
                            "certificateFile": "/etc/xray/fake-tls.crt",
                            "keyFile": "/etc/xray/fake-tls.key"
                        }
                    ]
                },
                "tcpSettings": {
                    "acceptProxyProtocol": true,
                    "header": {
                        "type": "http",
                        "request": {
                            "version": "1.1",
                            "method": "GET",
                            "path": ["/cdn-cgi/trace"],
                            "headers": {
                                "Host": ["${DOMAIN}"],
                                "User-Agent": [
                                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                                ],
                                "Accept-Encoding": ["gzip, deflate"],
                                "Connection": ["keep-alive"]
                            }
                        }
                    }
                }
            }
        }
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
            "protocol": "mtproto",
            "tag": "mtproto-out",
            "settings": {
                "users": [
                    {
                        "secret": "$(openssl rand -hex 32)"
                    }
                ]
            }
        }
    ],
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "domainMatcher": "hybrid",
        "rules": [
            {
                "type": "field",
                "inboundTag": ["default"],
                "outboundTag": "direct"
            },
            {
                "type": "field",
                "protocol": ["bittorrent"],
                "outboundTag": "direct"
            },
            {
                "type": "field",
                "ip": ["geoip:telegram"],
                "outboundTag": "mtproto-out"
            },
            {
                "type": "field",
                "domain": ["geosite:telegram"],
                "outboundTag": "mtproto-out"
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
                "bufferSize": 16384
            }
        }
    }
}
EOF
    
    # Generate fake TLS certificates for Xray
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -subj "/C=US/ST=California/L=San Francisco/O=Cloudflare, Inc./CN=${DOMAIN}" \
        -keyout /etc/xray/fake-tls.key \
        -out /etc/xray/fake-tls.crt
    
    # Create Xray wrapper for MTProto optimization
    cat > /usr/local/bin/xray-mtproto-wrapper.sh << 'EOF'
#!/bin/bash
# Xray Wrapper optimized for MTProto

# Enable BBR
echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
sysctl -p

# Increase file descriptors
ulimit -n 1048576

# Set NICQUEUE
ethtool -K $INTERFACE tso on gso on gro on 2>/dev/null || true

# Start Xray with optimized parameters
exec /usr/local/bin/xray run \
    -config /usr/local/etc/xray/config_mtproto.json \
    -format json \
    -loglevel error \
    -stats none \
    -restart 0 \
    "$@"
EOF
    
    chmod +x /usr/local/bin/xray-mtproto-wrapper.sh
    
    # Create systemd service for Xray
    cat > /etc/systemd/system/xray-mtproto.service << EOF
[Unit]
Description=Xray MTProto Proxy
After=network.target mtproxy.service
Requires=mtproxy.service

[Service]
Type=simple
User=nobody
Group=nogroup
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
ExecStart=/usr/local/bin/xray-mtproto-wrapper.sh
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=3

# Security
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes

# Performance
CPUSchedulingPolicy=rr
CPUSchedulingPriority=10
Nice=-5
OOMScoreAdjust=-500
IOSchedulingClass=best-effort
IOSchedulingPriority=0

[Install]
WantedBy=multi-user.target
EOF
}

# =====================================================
# MODULE 3: TRAFFIC SHAPING & ANTI-DPI
# =====================================================
setup_traffic_shaping_mtproto() {
    echo -e "${BLUE}[*] Setting up Traffic Shaping for MTProto...${NC}"
    
    # Install traffic control tools
    apt-get install -y tc iproute2 conntrack
    
    # Create advanced traffic shaping script
    cat > /usr/local/bin/mtproto-traffic-shape.sh << 'EOF'
#!/bin/bash
# Advanced Traffic Shaping for MTProto

INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

# Clear existing rules
tc qdisc del dev $INTERFACE root 2>/dev/null || true

# Create HTB hierarchy
tc qdisc add dev $INTERFACE root handle 1: htb default 30

# Root class
tc class add dev $INTERFACE parent 1: classid 1:1 htb rate 1000mbit ceil 1000mbit

# Sub-classes for different traffic types
# 1: MTProto traffic (priority)
tc class add dev $INTERFACE parent 1:1 classid 1:10 htb rate 800mbit ceil 1000mbit prio 0 burst 15k cburst 15k
# 2: Xray traffic
tc class add dev $INTERFACE parent 1:1 classid 1:20 htb rate 150mbit ceil 300mbit prio 1 burst 10k cburst 10k
# 3: Other traffic
tc class add dev $INTERFACE parent 1:1 classid 1:30 htb rate 50mbit ceil 100mbit prio 2 burst 5k cburst 5k

# Add FQ_CODEL for each class
tc qdisc add dev $INTERFACE parent 1:10 handle 10: fq_codel quantum 300 limit 10240 flows 1024 noecn
tc qdisc add dev $INTERFACE parent 1:20 handle 20: fq_codel quantum 600 limit 20480 flows 2048 ecn
tc qdisc add dev $INTERFACE parent 1:30 handle 30: fq_codel quantum 1500 limit 40960 flows 4096 noecn

# Mark packets (MTProto uses port 443, Xray uses 8443)
iptables -t mangle -A OUTPUT -p tcp --sport 443 -j MARK --set-mark 10
iptables -t mangle -A OUTPUT -p tcp --sport 8443 -j MARK --set-mark 20
iptables -t mangle -A OUTPUT -p tcp --sport 2053 -j MARK --set-mark 20

# Apply marks to classes
tc filter add dev $INTERFACE parent 1: protocol ip prio 1 handle 10 fw flowid 1:10
tc filter add dev $INTERFACE parent 1: protocol ip prio 2 handle 20 fw flowid 1:20

# Add netem for randomization (only for non-MTProto traffic)
tc qdisc add dev $INTERFACE parent 1:20 handle 200: netem delay 10ms 5ms 25% distribution normal
tc qdisc add dev $INTERFACE parent 1:30 handle 300: netem delay 20ms 10ms 50% distribution pareto

echo "Traffic shaping applied to $INTERFACE"
EOF
    
    chmod +x /usr/local/bin/mtproto-traffic-shape.sh
    
    # Create packet randomizer
    cat > /usr/local/bin/packet-randomizer.sh << 'EOF'
#!/bin/bash
# Packet-level Randomization

while true; do
    # Randomize TTL
    NEW_TTL=$((64 + RANDOM % 64))
    iptables -t mangle -A POSTROUTING -j TTL --ttl-set $NEW_TTL 2>/dev/null || \
    iptables -t mangle -C POSTROUTING -j TTL --ttl-set $NEW_TTL 2>/dev/null || \
    iptables -t mangle -R POSTROUTING 1 -j TTL --ttl-set $NEW_TTL
    
    # Randomize TCP timestamp
    if [ $((RANDOM % 2)) -eq 0 ]; then
        iptables -t mangle -A OUTPUT -p tcp -j TCPOPTSTRIP --strip-options timestamp
    else
        iptables -t mangle -D OUTPUT -p tcp -j TCPOPTSTRIP --strip-options timestamp 2>/dev/null || true
    fi
    
    # Randomize MSS
    NEW_MSS=$((1220 + RANDOM % 100 - 50))
    iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss $NEW_MSS 2>/dev/null || \
    iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss $NEW_MSS 2>/dev/null || \
    iptables -t mangle -R FORWARD 1 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss $NEW_MSS
    
    sleep $((300 + RANDOM % 600))  # 5-15 minutes
done
EOF
    
    chmod +x /usr/local/bin/packet-randomizer.sh
}

# =====================================================
# MODULE 4: FAKE TRAFFIC GENERATOR
# =====================================================
setup_fake_traffic() {
    echo -e "${BLUE}[*] Setting up Fake Traffic Generator...${NC}"
    
    cat > /usr/local/bin/fake-telegram-traffic.sh << 'EOF'
#!/bin/bash
# Generate realistic Telegram-like traffic patterns

TELEGRAM_IPS=(
    "91.108.4.0/22"
    "91.108.8.0/22"
    "91.108.12.0/22"
    "91.108.16.0/22"
    "91.108.56.0/22"
    "149.154.160.0/20"
    "2001:67c:4e8::/48"
)

generate_telegram_packets() {
    while true; do
        # Simulate Telegram MTProto handshake
        for ip_range in "${TELEGRAM_IPS[@]}"; do
            # Generate random IP from range
            IP=$(./ipgen.sh $ip_range)
            
            # Send fake MTProto packet (56 bytes like real MTProto)
            echo -ne "\x00\x00\x00\x00\x00\x00\x00\x00" | \
            timeout 0.5 nc -u $IP 443 2>/dev/null &
            
            # Random delay between packets (10-100ms)
            sleep 0.0$((10 + RANDOM % 90))
        done
        
        # Sleep between bursts (1-5 seconds)
        sleep $((1 + RANDOM % 4))
    done
}

generate_http_masquerade() {
    while true; do
        # Generate HTTP/HTTPS traffic to CDN domains
        DOMAINS=(
            "cdn.telegram.org"
            "api.telegram.org"
            "www.google.com"
            "www.cloudflare.com"
            "www.microsoft.com"
        )
        
        for domain in "${DOMAINS[@]}"; do
            # HTTP GET request
            curl -s -H "User-Agent: TelegramBot/1.0" \
                 -H "Accept: */*" \
                 -H "Connection: keep-alive" \
                 "https://$domain/" > /dev/null &
            
            # DNS query
            dig @1.1.1.1 $domain +short > /dev/null &
            
            sleep 0.$((100 + RANDOM % 400))
        done
        
        sleep $((10 + RANDOM % 20))
    done
}

# Start both generators
generate_telegram_packets &
generate_http_masquerade &
EOF
    
    # Create IP generator helper
    cat > /usr/local/bin/ipgen.sh << 'EOF'
#!/bin/bash
# Generate random IP from CIDR

cidr_to_mask() {
    local mask=$((0xffffffff << (32 - $1)))
    echo $(( (mask >> 24) & 0xff )).$(( (mask >> 16) & 0xff )).$(( (mask >> 8) & 0xff )).$(( mask & 0xff ))
}

IFS='/' read -r ip bits <<< "$1"
IFS='.' read -r i1 i2 i3 i4 <<< "$ip"

mask=$(cidr_to_mask $bits)
IFS='.' read -r m1 m2 m3 m4 <<< "$mask"

# Calculate network and broadcast
nw=$(( (i1 & m1) | (i2 & m2) << 8 | (i3 & m3) << 16 | (i4 & m4) << 24 ))
bc=$(( nw | (0xffffffff >> bits) ))

# Generate random IP in range
rand_ip=$(( nw + RANDOM % (bc - nw + 1) ))

# Convert back to dotted decimal
printf "%d.%d.%d.%d\n" \
    $(( (rand_ip >> 24) & 0xff )) \
    $(( (rand_ip >> 16) & 0xff )) \
    $(( (rand_ip >> 8) & 0xff )) \
    $(( rand_ip & 0xff ))
EOF
    
    chmod +x /usr/local/bin/fake-telegram-traffic.sh
    chmod +x /usr/local/bin/ipgen.sh
}

# =====================================================
# MODULE 5: VXLAN TUNNEL FOR MTPROTO
# =====================================================
setup_vxlan_for_mtproto() {
    echo -e "${BLUE}[*] Setting up VXLAN Tunnel for MTProto...${NC}"
    
    # Create VXLAN tunnel
    VXLAN_ID=$((RANDOM % 10000))
    LOCAL_VXLAN_IP="10.100.0.1"
    REMOTE_VXLAN_IP="10.100.0.2"
    
    # Detect main interface
    MAIN_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # Create VXLAN interface
    ip link add vxlan0 type vxlan \
        id $VXLAN_ID \
        dev $MAIN_IFACE \
        dstport 4789 \
        local $IRAN_IP \
        remote $KHAREJ_IP \
        ttl 64
    
    ip addr add $LOCAL_VXLAN_IP/24 dev vxlan0
    ip link set vxlan0 mtu 1450
    ip link set vxlan0 up
    
    # Optimize VXLAN
    echo 1 > /proc/sys/net/ipv4/conf/vxlan0/rp_filter
    echo 0 > /proc/sys/net/ipv4/conf/vxlan0/accept_redirects
    echo 0 > /proc/sys/net/ipv4/conf/vxlan0/send_redirects
    
    # Bridge MTProto through VXLAN
    iptables -t nat -A PREROUTING -i $MAIN_IFACE -p tcp --dport 443 -j DNAT --to-destination $REMOTE_VXLAN_IP:443
    iptables -t nat -A PREROUTING -i $MAIN_IFACE -p tcp --dport 8443 -j DNAT --to-destination $REMOTE_VXLAN_IP:8443
    iptables -t nat -A POSTROUTING -o vxlan0 -j MASQUERADE
    
    # Create VXLAN optimization script
    cat > /usr/local/bin/optimize-vxlan.sh << 'EOF'
#!/bin/bash
# Optimize VXLAN for MTProto

# Increase buffer sizes
echo 16777216 > /proc/sys/net/core/rmem_max
echo 16777216 > /proc/sys/net/core/wmem_max
echo 4096 87380 16777216 > /proc/sys/net/ipv4/tcp_rmem
echo 4096 65536 16777216 > /proc/sys/net/ipv4/tcp_wmem

# Enable TCP timestamps and window scaling
echo 1 > /proc/sys/net/ipv4/tcp_timestamps
echo 1 > /proc/sys/net/ipv4/tcp_window_scaling

# Increase connection tracking
echo 2097152 > /proc/sys/net/netfilter/nf_conntrack_max
echo 120 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established

# Optimize for high throughput
echo 0 > /proc/sys/net/ipv4/tcp_slow_start_after_idle
echo 1 > /proc/sys/net/ipv4/tcp_mtu_probing
echo "bbr" > /proc/sys/net/ipv4/tcp_congestion_control
EOF
    
    chmod +x /usr/local/bin/optimize-vxlan.sh
}

# =====================================================
# MODULE 6: MONITORING & AUTO-HEALING
# =====================================================
setup_monitoring_mtproto() {
    echo -e "${BLUE}[*] Setting up Monitoring System...${NC}"
    
    cat > /usr/local/bin/mtproto-monitor.sh << 'EOF'
#!/bin/bash
# MTProto Health Monitor

check_mtproto() {
    # Check if MTProxy is running
    if ! pgrep -f "mtproto-proxy" > /dev/null; then
        echo "[$(date)] MTProto proxy not running, restarting..."
        systemctl restart mtproxy
        return 1
    fi
    
    # Check port connectivity
    if ! timeout 2 nc -z localhost 443; then
        echo "[$(date)] Port 443 not responding, restarting..."
        systemctl restart mtproxy
        return 1
    fi
    
    # Check Xray integration
    if ! timeout 2 nc -z localhost 8443; then
        echo "[$(date)] Xray port not responding, restarting..."
        systemctl restart xray-mtproto
        return 1
    fi
    
    return 0
}

check_bandwidth() {
    # Monitor bandwidth usage
    BW_THRESHOLD=50000000  # 50 Mbps
    
    CURRENT_BW=$(iftop -i $INTERFACE -t -s 1 2>/dev/null | \
                 grep "Total send rate" | \
                 awk '{print $6}' | \
                 sed 's/Kb//;s/Mb/*1000/;s/Gb/*1000000/' | \
                 bc 2>/dev/null || echo 0)
    
    if [ $CURRENT_BW -gt $BW_THRESHOLD ]; then
        echo "[$(date)] High bandwidth detected ($CURRENT_BW bps), rotating secret..."
        systemctl restart mtproxy
    fi
}

check_dpi() {
    # Check for DPI interference
    if tcpdump -i $INTERFACE -c 10 'tcp[13] & 4 != 0' 2>/dev/null | grep -q "R"; then
        echo "[$(date)] RST packets detected, possible DPI, changing ports..."
        
        # Rotate ports
        PORTS=(443 8443 2053 8080 8888)
        NEW_PORT=${PORTS[$RANDOM % ${#PORTS[@]}]}
        
        sed -i "s/port = .*/port = $NEW_PORT/" /etc/mtproxy.conf
        sed -i "s/\"port\": .*/\"port\": $NEW_PORT,/" /usr/local/etc/xray/config_mtproto.json
        
        systemctl restart mtproxy
        systemctl restart xray-mtproto
    fi
}

# Main monitoring loop
while true; do
    check_mtproto
    check_bandwidth
    check_dpi
    
    # Random sleep to avoid pattern
    sleep $((30 + RANDOM % 60))
done
EOF
    
    chmod +x /usr/local/bin/mtproto-monitor.sh
    
    # Create systemd service for monitor
    cat > /etc/systemd/system/mtproto-monitor.service << EOF
[Unit]
Description=MTProto Health Monitor
After=network.target mtproxy.service

[Service]
Type=simple
ExecStart=/usr/local/bin/mtproto-monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}

# =====================================================
# MODULE 7: CLIENT CONFIGURATION GENERATOR
# =====================================================
generate_client_configs() {
    echo -e "${BLUE}[*] Generating Client Configurations...${NC}"
    
    # Extract secrets
    MTPROTO_SECRET=$(grep "secret = " /etc/mtproxy.conf | awk '{print $3}')
    XRAY_UUID=$(grep -o '"id": "[^"]*"' /usr/local/etc/xray/config_mtproto.json | head -1 | cut -d'"' -f4)
    
    # Generate MTProto client config (for Telegram)
    cat > /root/mtproto-client.conf << EOF
# MTProto Client Configuration
# Server: ${KHAREJ_IP}
# Port: ${MTPROTO_PORT}
# Secret: ${MTPROTO_SECRET}

[proxy]
server = ${KHAREJ_IP}
port = ${MTPROTO_PORT}
secret = ${MTPROTO_SECRET}
enable-ipv6 = true
fast-open = true
tcp-no-delay = true
tcp-keepalive = 60

# Obfuscation
obfuscation = true
obfuscation-level = 2

# Performance
workers = 4
msg-buffer-size = 65536
read-buffer-size = 131072
write-buffer-size = 131072
EOF
    
    # Generate Xray client config
    cat > /root/xray-mtproto-client.json << EOF
{
    "log": {"loglevel": "error"},
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
                        "address": "${KHAREJ_IP}",
                        "port": ${XRAY_PORT},
                        "users": [
                            {
                                "id": "${XRAY_UUID}",
                                "encryption": "none",
                                "flow": "xtls-rprx-vision"
                            }
                        ]
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "none",
                "tcpSettings": {
                    "header": {
                        "type": "none"
                    }
                },
                "sockopt": {
                    "tcpFastOpen": true,
                    "tcpNoDelay": true
                }
            },
            "tag": "proxy"
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "ip": ["geoip:ir"],
                "outboundTag": "proxy"
            },
            {
                "type": "field",
                "domain": ["geosite:telegram"],
                "outboundTag": "proxy"
            }
        ]
    }
}
EOF
    
    # Generate install script for clients
    cat > /root/install-client.sh << 'EOF'
#!/bin/bash
# Client Installation Script

echo "Installing MTProto + Xray Client..."

# Install prerequisites
apt-get update
apt-get install -y curl wget git

# Install Xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Download client config
wget -O /usr/local/etc/xray/config.json https://your-server.com/xray-mtproto-client.json

# Start Xray
systemctl enable xray
systemctl start xray

echo "Installation complete!"
echo "SOCKS5 Proxy: 127.0.0.1:1080"
echo "HTTP Proxy: 127.0.0.1:1081"
EOF
    
    chmod +x /root/install-client.sh
    
    echo -e "${GREEN}[+] Client configurations generated in /root/${NC}"
}

# =====================================================
# MAIN INSTALLATION FUNCTION
# =====================================================
main_installation() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════╗
║   ADVANCED MTPROTO + XRAY INTEGRATION    ║
║        (Anti-DPI & Anti-Throttle)        ║
╚══════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Get configuration
    read -p "Enter Iran Server IP: " IRAN_IP
    read -p "Enter Kharej Server IP: " KHAREJ_IP
    read -p "Enter Domain for Fake-TLS: " DOMAIN
    read -p "Role (iran/kharej): " ROLE
    
    export IRAN_IP
    export KHAREJ_IP
    export DOMAIN
    
    # Update system
    apt-get update && apt-get upgrade -y
    
    # Install common dependencies
    apt-get install -y \
        build-essential \
        libssl-dev \
        zlib1g-dev \
        libevent-dev \
        python3 \
        python3-pip \
        cmake \
        net-tools \
        iptables \
        iproute2 \
        tcptraceroute \
        mtr \
        tcpdump \
        iftop \
        nethogs \
        jq
    
    # Install based on role
    if [ "$ROLE" = "kharej" ]; then
        echo -e "${YELLOW}[*] Installing Kharej (Foreign) Server...${NC}"
        setup_mtproto_proxy
        setup_xray_mtproto
        setup_fake_traffic
        generate_client_configs
    elif [ "$ROLE" = "iran" ]; then
        echo -e "${YELLOW}[*] Installing Iran (Local) Server...${NC}"
        setup_vxlan_for_mtproto
        setup_traffic_shaping_mtproto
    fi
    
    # Common setup
    setup_monitoring_mtproto
    
    # Start services
    systemctl daemon-reload
    
    if [ "$ROLE" = "kharej" ]; then
        systemctl enable mtproxy xray-mtproto mtproto-monitor
        systemctl start mtproxy xray-mtproto mtproto-monitor
    fi
    
    # Start traffic randomizer
    nohup /usr/local/bin/packet-randomizer.sh > /dev/null 2>&1 &
    
    echo -e "${GREEN}"
    cat << "EOF"
╔══════════════════════════════════════════╗
║         INSTALLATION COMPLETE           ║
╠══════════════════════════════════════════╣
║ Layer 1: VXLAN Tunnel                    ║
║ Layer 2: MTProto Proxy (Fake-TLS)       ║
║ Layer 3: Xray (VLESS/Vision)            ║
║ Layer 4: Traffic Randomization          ║
║                                          ║
║ Features:                                ║
║ • Fake-TLS with Telegram domain         ║
║ • Traffic shaping & prioritization      ║
║ • Automatic port rotation               ║
║ • Realistic traffic generation          ║
║ • Health monitoring & auto-healing      ║
╚══════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Show summary
    if [ "$ROLE" = "kharej" ]; then
        echo -e "${YELLOW}[!] Server Information:${NC}"
        echo "MTProto Port: ${MTPROTO_PORT}"
        echo "Xray Port: ${XRAY_PORT}"
        echo "Fake-TLS Port: ${FAKE_TLS_PORT}"
        echo "Secret: $(grep 'secret = ' /etc/mtproxy.conf | awk '{print $3}')"
        echo "Domain: ${DOMAIN}"
    fi
}

# =====================================================
# UNINSTALL FUNCTION
# =====================================================
uninstall_all() {
    echo -e "${RED}[!] Uninstalling MTProto + Xray...${NC}"
    
    # Stop services
    systemctl stop mtproxy xray-mtproto mtproto-monitor 2>/dev/null
    
    # Remove interfaces
    ip link del vxlan0 2>/dev/null || true
    
    # Remove configurations
    rm -rf /etc/mtproxy
    rm -rf /tmp/MTProxy
    rm -f /usr/local/etc/xray/config_mtproto.json
    
    # Remove scripts
    rm -f /usr/local/bin/mtproxy-wrapper.sh
    rm -f /usr/local/bin/xray-mtproto-wrapper.sh
    rm -f /usr/local/bin/mtproto-traffic-shape.sh
    rm -f /usr/local/bin/packet-randomizer.sh
    rm -f /usr/local/bin/fake-telegram-traffic.sh
    rm -f /usr/local/bin/mtproto-monitor.sh
    
    # Remove systemd services
    systemctl disable mtproxy xray-mtproto mtproto-monitor 2>/dev/null
    rm -f /etc/systemd/system/mtproxy.service
    rm -f /etc/systemd/system/xray-mtproto.service
    rm -f /etc/systemd/system/mtproto-monitor.service
    
    echo -e "${GREEN}[✓] Uninstallation complete!${NC}"
}

# =====================================================
# USAGE
# =====================================================
case "$1" in
    install)
        main_installation
        ;;
    uninstall)
        uninstall_all
        ;;
    status)
        echo -e "${BLUE}[*] Service Status:${NC}"
        systemctl status mtproxy xray-mtproto --no-pager 2>/dev/null || echo "Services not running"
        echo -e "\n${BLUE}[*] Network Status:${NC}"
        ip link show vxlan0 2>/dev/null || echo "VXLAN not configured"
        netstat -tulpn | grep -E ':443|:8443|:2053'
        ;;
    optimize)
        /usr/local/bin/optimize-vxlan.sh
        /usr/local/bin/mtproto-traffic-shape.sh
        echo -e "${GREEN}[✓] Optimization applied!${NC}"
        ;;
    client)
        generate_client_configs
        echo -e "${GREEN}[✓] Client configs generated in /root/${NC}"
        ;;
    *)
        echo "Usage: $0 {install|uninstall|status|optimize|client}"
        exit 1
        ;;
esac
