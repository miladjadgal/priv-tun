#!/bin/bash

# ============================================================================
# Paqet Tunnel Advanced Installer - مقاوم در برابر DPI پیشرفته
# فلسفه طراحی: "میمون صد آواز" - هر تونل منحصربفرد و شبیه ترافیک عادی
# 
# اصول ضد DPI:
# 1. تنوع تصادفی: هر نصب پارامترهای منحصربفرد
# 2. استتار فعال: استفاده از پورت‌های متداول و پروتکل‌های معمول
# 3. الگوی غیرقابل تشخیص: نویزگذاری و تغییر الگوهای زمانی
# 4. هوشمند در جمعیت: با استفاده جمعی، الگوهای متنوع ایجاد می‌کند
#
# نکته امنیتی: قدرت واقعی در گسترش این روش در بین کاربران زیاد است
# ============================================================================

set -e

# رنگ‌های خروجی
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# مسیرهای سیستمی
CONFIG_DIR="/etc/paqet-advanced"
SERVICE_DIR="/etc/systemd/system"
LOG_DIR="/var/log/paqet"
BIN_DIR="/usr/local/bin"
INSTALL_DIR="/opt/paqet-advanced"

# نسخه‌ها
SCRIPT_VERSION="4.0-anti-dpi"
PAQET_VERSION="v1.0.0-alpha.14"
GITHUB_REPO="hanselime/paqet"

# متغیرهای جهانی
ROLE=""
TUNNEL_NAME=""
ENCRYPTION_KEY=""
OBFUSCATION_LEVEL=""
INSTANCE_ID=$(head -c 6 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 8)

# توابع نمایشی
print_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║   ██████╗  █████╗  ██████╗ ███████╗████████╗  █████╗ ██████╗██╗  ██╗║"
    echo "║   ██╔══██╗██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝ ██╔══██╗██╔══██╗██║  ██║║"
    echo "║   ██████╔╝███████║██║   ██║█████╗     ██║    ███████║██████╔╝███████║║"
    echo "║   ██╔═══╝ ██╔══██║██║▄▄ ██║██╔══╝     ██║    ██╔══██║██╔═══╝ ██╔══██║║"
    echo "║   ██║     ██║  ██║╚██████╔╝███████╗   ██║    ██║  ██║██║     ██║  ██║║"
    echo "║   ╚═╝     ╚═╝  ╚═╝ ╚══▀▀═╝ ╚══════╝   ╚═╝    ╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝║"
    echo "║                                                                      ║"
    echo "║           Advanced Anti-DPI Tunnel - Version $SCRIPT_VERSION          ║"
    echo "║                  Instance ID: ${INSTANCE_ID}                          ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}ایده: امنیت در جمعیت - هر نصب منحصربفرد، تشخیص را سخت‌تر می‌کند${NC}"
    echo ""
}

print_step() { echo -e "${BLUE}[→]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }
print_debug() { echo -e "${WHITE}[#]${NC} $1"; }

# تابع تولید مقادیر تصادفی برای شکستن الگوهای DPI
generate_random_value() {
    local type=$1
    case $type in
        "port")
            # انتخاب پورت از رنج‌های مختلف برای شکستن الگو
            local port_options=(443 8443 8080 8880 9443 7080 65432 50050)
            echo ${port_options[$RANDOM % ${#port_options[@]}]}
            ;;
        "delay")
            # تاخیر تصادفی بین 5 تا 40 میلی‌ثانیه
            echo $((5 + RANDOM % 35))
            ;;
        "padding")
            # اندازه padding تصادفی
            echo $((128 + RANDOM % 384))
            ;;
        "timeout")
            # timeout متغیر
            echo $((60 + RANDOM % 120))
            ;;
        "jitter")
            # جیتر برای تغییر زمان‌بندی
            echo $((1 + RANDOM % 15))
            ;;
        *)
            echo ""
            ;;
    esac
}

# بررسی دسترسی root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "این اسکریپت نیاز به دسترسی root دارد"
        print_info "دستور اجرا: sudo bash $0"
        exit 1
    fi
    print_success "دسترسی root تأیید شد"
}

# شناسایی سیستم عامل
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
    echo "$OS"
}

# شناسایی معماری
detect_arch() {
    local arch
    arch=$(uname -m)

    case $arch in
        x86_64|x86-64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armhf)
            echo "armv7"
            ;;
        i386|i686)
            echo "386"
            ;;
        *)
            print_error "معماری پشتیبانی نشده: $arch"
            return 1
            ;;
    esac
}

# بهینه‌سازی سیستم برای عملکرد بهتر
optimize_system() {
    print_step "بهینه‌سازی پارامترهای شبکه برای عملکرد بهتر")
    
    # تنظیمات TCP برای بهبود Throughput
    cat > /etc/sysctl.d/99-paqet-optimization.conf << EOF
# بهینه‌سازی‌های Paqet - ضد الگویابی DPI
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 10000 65000
net.core.netdev_max_backlog = 100000
EOF
    
    sysctl -p /etc/sysctl.d/99-paqet-optimization.conf > /dev/null 2>&1
    print_success "بهینه‌سازی‌های شبکه اعمال شدند")
}

# نصب وابستگی‌ها
install_dependencies() {
    print_step "نصب وابستگی‌های مورد نیاز")
    
    local os=$(detect_os)
    
    case $os in
        ubuntu|debian)
            apt update -qq > /dev/null 2>&1
            apt install -y curl wget libpcap-dev iptables lsof \
                         iproute2 cron net-tools dnsutils \
                         software-properties-common > /dev/null 2>&1
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y curl wget libpcap-devel iptables lsof \
                         iproute cronie net-tools bind-utils \
                         epel-release > /dev/null 2>&1
            ;;
        *)
            print_warning "سیستم عامل ناشناخته. لطفاً دستی نصب کنید"
            ;;
    esac
    
    print_success "وابستگی‌ها نصب شدند")
}

# تولید کلید رمزنگاری منحصربفرد
generate_encryption_key() {
    print_step "تولید کلید رمزنگاری منحصربفرد")
    
    if command -v openssl > /dev/null 2>&1; then
        ENCRYPTION_KEY=$(openssl rand -base64 48 | tr -d '\n=+/' | head -c 64)
    else
        ENCRYPTION_KEY=$(head -c 48 /dev/urandom | base64 | tr -d '\n=+/' | head -c 64)
    fi
    
    # اضافه کردن نویز به کلید برای منحصربفرد شدن بیشتر
    local noise=$(date +%s%N | sha256sum | head -c 16)
    ENCRYPTION_KEY="${ENCRYPTION_KEY:0:48}${noise}"
    
    print_success "کلید رمزنگاری تولید شد")
    print_debug "کلید: ${ENCRYPTION_KEY:0:16}..."
}

# دانلود باینری Paqet
download_paqet() {
    print_step "دریافت باینری Paqet")
    
    local arch=$(detect_arch)
    local os="linux"
    
    # ایجاد دایرکتوری نصب
    mkdir -p $INSTALL_DIR
    mkdir -p $LOG_DIR
    
    # نام فایل بر اساس معماری
    local filename="paqet-${os}-${arch}-${PAQET_VERSION}.tar.gz"
    local download_url="https://github.com/${GITHUB_REPO}/releases/download/${PAQET_VERSION}/${filename}"
    
    print_info "دریافت از: $download_url")
    
    # دانلود با curl یا wget
    if command -v curl > /dev/null 2>&1; then
        curl -L -o "/tmp/paqet.tar.gz" "$download_url"
    elif command -v wget > /dev/null 2>&1; then
        wget -O "/tmp/paqet.tar.gz" "$download_url"
    else
        print_error "ابزار دانلود یافت نشد")
        exit 1
    fi
    
    if [ $? -ne 0 ]; then
        print_error "دانلود ناموفق بود")
        print_info "لطفاً دستی دانلود کنید: $download_url")
        exit 1
    fi
    
    # استخراج
    tar -xzf "/tmp/paqet.tar.gz" -C $INSTALL_DIR
    
    # قابل اجرا کردن
    chmod +x $INSTALL_DIR/paqet
    
    # لینک به مسیر سیستم
    ln -sf $INSTALL_DIR/paqet $BIN_DIR/paqet
    
    print_success "باینری Paqet نصب شد")
}

# پیکربندی پیشرفته با پارامترهای تصادفی
create_advanced_config() {
    print_step "ایجاد پیکربندی پیشرفته ضد DPI")
    
    mkdir -p $CONFIG_DIR
    
    # تولید مقادیر تصادفی برای هر نصب
    local LISTEN_PORT=$(generate_random_value "port")
    local KCP_PORT=$((LISTEN_PORT + 1))
    local CONN_DELAY=$(generate_random_value "delay")
    local PADDING_SIZE=$(generate_random_value "padding")
    local TIMEOUT_VAL=$(generate_random_value "timeout")
    local NET_JITTER=$(generate_random_value "jitter")
    
    # انتخاب حالت KCP بر اساس نقش
    local KCP_MODE="fast3"
    if [ "$ROLE" == "client" ]; then
        KCP_MODE="fast2"
    fi
    
    # ایجاد فایل کانفیگ
    local config_file="$CONFIG_DIR/config-${INSTANCE_ID}.yaml"
    
    cat > "$config_file" << EOF
# پیکربندی Paqet پیشرفته - ضد DPI
# Instance ID: ${INSTANCE_ID}
# Generated: $(date)

metadata:
  instance_id: "${INSTANCE_ID}"
  version: "${SCRIPT_VERSION}"
  generated_at: "$(date -Iseconds)"
  dpi_resistance: "high"

network:
  role: "${ROLE}"
  interface: "auto"
  listen_port: ${LISTEN_PORT}
  kcp_port: ${KCP_PORT}
  
  # پارامترهای تصادفی برای شکستن الگو
  connection_delay: ${CONN_DELAY}
  packet_padding: ${PADDING_SIZE}
  network_jitter: ${NET_JITTER}
  
  # استتار: استفاده از پورت‌های معمول
  disguise_port: 443
  use_tls_header: true

encryption:
  key: "${ENCRYPTION_KEY}"
  algorithm: "chacha20-poly1305"
  key_rotation_hours: 24
  additional_noise: true

kcp_settings:
  mode: "${KCP_MODE}"
  mtu: 1200
  sndwnd: 1024
  rcvwnd: 1024
  nodelay: 1
  interval: 20
  resend: 2
  nc: 1
  stream_buf: 2097152
  
  # تنظیمات ضد الگویابی
  dynamic_mtu: true
  random_resend: true
  jitter_compensation: true

performance:
  max_connections: 1000
  connection_timeout: ${TIMEOUT_VAL}
  keepalive_interval: 30
  buffer_size: 8388608
  worker_threads: 4
  
  # بهینه‌سازی برای کاربران زیاد
  load_balancing: true
  connection_pooling: true
  memory_optimization: true

obfuscation:
  enabled: true
  level: "advanced"
  
  # تکنیک‌های استتار
  fake_tls: true
  random_padding: true
  time_variation: true
  packet_size_randomization: true
  
  # الگوهای ترافیک عادی
  mimic_https: true
  mimic_ssh: false
  mimic_dns: true
  
  # نویزگذاری
  noise_injection: true
  noise_level: "medium"
  fake_packets_per_minute: 60

monitoring:
  enable_logs: true
  log_level: "info"
  log_file: "${LOG_DIR}/paqet-${INSTANCE_ID}.log"
  stats_port: $((LISTEN_PORT + 1000))
  health_check_interval: 30
  
  # مانیتورینگ پیشرفته
  traffic_analysis: true
  anomaly_detection: true
  auto_recovery: true

security:
  firewall_integration: true
  ip_whitelist: []
  rate_limiting: true
  max_connections_per_ip: 50
  block_scanners: true
  
  # محافظت DPI پیشرفته
  protocol_obfuscation: true
  deep_packet_resistance: true
  behavioral_mimicry: true
EOF
    
    print_success "پیکربندی پیشرفته ایجاد شد: $config_file")
    print_info "پورت شنود: $LISTEN_PORT")
    print_info "پورت KCP: $KCP_PORT")
}

# ایجاد سرویس systemd با نام تصادفی
create_systemd_service() {
    print_step "ایجاد سرویس systemd با نام غیرقابل پیش‌بینی")
    
    local service_name="paqet-${INSTANCE_ID}"
    local service_file="$SERVICE_DIR/${service_name}.service"
    local config_file="$CONFIG_DIR/config-${INSTANCE_ID}.yaml"
    
    cat > "$service_file" << EOF
[Unit]
Description=Paqet Advanced Tunnel - ${INSTANCE_ID}
After=network.target
Wants=network.target
StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
Type=simple
User=root
Group=root
Environment="INSTANCE_ID=${INSTANCE_ID}"
Environment="CONFIG_FILE=${config_file}"
ExecStartPre=/bin/sleep 3
ExecStart=$BIN_DIR/paqet --config ${config_file} --log-level info
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
RestartPreventExitStatus=23
LimitNOFILE=1000000
LimitNPROC=10000

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
MemoryDenyWriteExecute=true

# Logging
StandardOutput=append:${LOG_DIR}/service-${INSTANCE_ID}.out
StandardError=append:${LOG_DIR}/service-${INSTANCE_ID}.err
SyslogIdentifier=${service_name}

[Install]
WantedBy=multi-user.target
EOF
    
    # فعال‌سازی سرویس
    systemctl daemon-reload
    systemctl enable "${service_name}.service"
    
    print_success "سرویس systemd ایجاد شد: $service_name")
}

# ایجاد فایل سلامت‌سنجی (Health Check)
create_health_check() {
    print_step "ایجاد سیستم سلامت‌سنجی هوشمند")
    
    local health_script="$CONFIG_DIR/health-check-${INSTANCE_ID}.sh"
    
    cat > "$health_script" << 'EOF'
#!/bin/bash

# اسکریپت سلامت‌سنجی Paqet
# این اسکریپت ترافیک عادی تولید می‌کند تا الگوی تونل محو شود

INSTANCE_ID="$1"
LOG_FILE="/var/log/paqet/health-${INSTANCE_ID}.log"
CONFIG_FILE="/etc/paqet-advanced/config-${INSTANCE_ID}.yaml"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# تولید ترافیک عادی برای استتار
generate_normal_traffic() {
    # درخواست‌های HTTP/S به سایت‌های معتبر
    curl -s --max-time 5 https://1.1.1.1/ > /dev/null 2>&1
    curl -s --max-time 5 https://www.google.com/gen_204 > /dev/null 2>&1
    curl -s --max-time 5 https://www.cloudflare.com/cdn-cgi/trace > /dev/null 2>&1
    
    # DNS queries عادی
    dig @1.1.1.1 google.com > /dev/null 2>&1
    dig @8.8.8.8 cloudflare.com > /dev/null 2>&1
    
    log "ترافیک عادی تولید شد"
}

# بررسی وضعیت تونل
check_tunnel_health() {
    local port=$(grep "listen_port" "$CONFIG_FILE" | awk '{print $2}')
    local status=$(ss -tuln | grep ":$port" | wc -l)
    
    if [ "$status" -eq "0" ]; then
        log "⚠️  تونل غیرفعال است. راه‌اندازی مجدد..."
        systemctl restart "paqet-${INSTANCE_ID}"
        return 1
    else
        log "✅ تونل فعال است (پورت: $port)"
        return 0
    fi
}

# تغییر پارامترهای کانفیگ برای متغیر نگه داشتن الگو
randomize_config() {
    local temp_file="/tmp/paqet-random-$$.yaml"
    
    # تغییر مقادیر کوچک برای شکستن الگو
    sed -i "s/connection_delay: [0-9]*/connection_delay: $((10 + RANDOM % 50))/" "$CONFIG_FILE"
    sed -i "s/packet_padding: [0-9]*/packet_padding: $((100 + RANDOM % 400))/" "$CONFIG_FILE"
    
    log "پارامترهای کانفیگ به صورت تصادفی تغییر یافتند"
}

# تزریق نویز به لاگ‌ها (برای گیج کردن آنالیز DPI)
inject_noise_logs() {
    local noise_messages=(
        "TCP connection established"
        "TLS handshake completed"
        "DNS query resolved"
        "HTTP request processed"
        "WebSocket connection opened"
        "API call completed"
        "Cache updated"
        "Session renewed"
    )
    
    local random_msg=${noise_messages[$RANDOM % ${#noise_messages[@]}]}
    log "📡 [نویز] $random_msg"
}

# اجرای اصلی
main() {
    log "شروع سلامت‌سنجی برای Instance: ${INSTANCE_ID}"
    
    # تولید ترافیک عادی
    generate_normal_traffic
    
    # بررسی سلامت تونل
    check_tunnel_health
    
    # تغییرات تصادفی
    if [ $((RANDOM % 10)) -eq 0 ]; then
        randomize_config
    fi
    
    # تزریق نویز
    if [ $((RANDOM % 5)) -eq 0 ]; then
        inject_noise_logs
    fi
    
    log "سلامت‌سنجی کامل شد"
}

main "$@"
EOF
    
    chmod +x "$health_script"
    
    # ایجاد کرون‌جاب برای اجرای دوره‌ای
    local cron_job="*/3 * * * * root $health_script ${INSTANCE_ID} > /dev/null 2>&1"
    echo "$cron_job" > /etc/cron.d/paqet-health-${INSTANCE_ID}
    
    print_success "سیستم سلامت‌سنجی ایجاد شد")
}

# منوی اصلی
show_main_menu() {
    print_banner
    
    echo -e "${CYAN}لطفاً نقش این سیستم را انتخاب کنید:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} سرور (خارج از ایران - Kharej)"
    echo -e "  ${GREEN}2)${NC} کلاینت (داخل ایران - Iran)"
    echo -e "  ${GREEN}3)${NC} نمایش اطلاعات سیستم"
    echo -e "  ${GREEN}4)${NC} حذف نصب"
    echo -e "  ${GREEN}5)${NC} خروج"
    echo ""
    
    read -p "انتخاب شما [1-5]: " main_choice
    
    case $main_choice in
        1)
            ROLE="server"
            show_server_menu
            ;;
        2)
            ROLE="client"
            show_client_menu
            ;;
        3)
            show_system_info
            show_main_menu
            ;;
        4)
            uninstall_paqet
            ;;
        5)
            print_info "خروج از برنامه")
            exit 0
            ;;
        *)
            print_error "انتخاب نامعتبر")
            show_main_menu
            ;;
    esac
}

# منوی سرور
show_server_menu() {
    print_step "پیکربندی سرور (خارج)")
    
    echo -e "${CYAN}سطح استتار را انتخاب کنید:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} استاندارد (سرعت بالا)"
    echo -e "  ${GREEN}2)${NC} پیشرفته (تعادل سرعت و امنیت)"
    echo -e "  ${GREEN}3)${NC} حرفه‌ای+ (حداکثر استتار)"
    echo ""
    
    read -p "سطح استتار [1-3]: " obfuscation_level
    
    case $obfuscation_level in
        1) OBFUSCATION_LEVEL="standard" ;;
        2) OBFUSCATION_LEVEL="advanced" ;;
        3) OBFUSCATION_LEVEL="expert+" ;;
        *) OBFUSCATION_LEVEL="advanced" ;;
    esac
    
    # دریافت آدرس IP عمومی
    print_step "دریافت آدرس IP عمومی")
    PUBLIC_IP=$(curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s icanhazip.com 2>/dev/null || echo "آدرس IP عمومی یافت نشد")
    print_info "آدرس IP عمومی: $PUBLIC_IP")
    
    # تأیید نهایی
    echo ""
    echo -e "${YELLOW}خلاصه پیکربندی سرور:${NC}"
    echo -e "  نقش: ${GREEN}$ROLE${NC}"
    echo -e "  سطح استتار: ${GREEN}$OBFUSCATION_LEVEL${NC}"
    echo -e "  شناسه نمونه: ${GREEN}$INSTANCE_ID${NC}"
    echo -e "  آدرس IP: ${GREEN}$PUBLIC_IP${NC}"
    echo ""
    
    read -p "آیا ادامه دهیم؟ (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        execute_installation
    else
        show_main_menu
    fi
}

# منوی کلاینت
show_client_menu() {
    print_step "پیکربندی کلاینت (ایران)")
    
    echo -e "${CYAN}سطح استتار را انتخاب کنید:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} استاندارد (سرعت بالا)"
    echo -e "  ${GREEN}2)${NC} پیشرفته (تعادل سرعت و امنیت)"
    echo -e "  ${GREEN}3)${NC} حرفه‌ای+ (حداکثر استتار - کندتر)"
    echo ""
    
    read -p "سطح استتار [1-3]: " obfuscation_level
    
    case $obfuscation_level in
        1) OBFUSCATION_LEVEL="standard" ;;
        2) OBFUSCATION_LEVEL="advanced" ;;
        3) OBFUSCATION_LEVEL="expert+" ;;
        *) OBFUSCATION_LEVEL="advanced" ;;
    esac
    
    # دریافت آدرس سرور
    echo ""
    echo -e "${YELLOW}لطفاً آدرس سرور (خارج) را وارد کنید:${NC}"
    echo -e "${CYAN}مثال: 192.168.1.100 یا domain.com${NC}"
    read -p "آدرس سرور: " SERVER_ADDRESS
    
    if [ -z "$SERVER_ADDRESS" ]; then
        print_error "آدرس سرور الزامی است")
        show_client_menu
    fi
    
    # تأیید نهایی
    echo ""
    echo -e "${YELLOW}خلاصه پیکربندی کلاینت:${NC}"
    echo -e "  نقش: ${GREEN}$ROLE${NC}"
    echo -e "  سطح استتار: ${GREEN}$OBFUSCATION_LEVEL${NC}"
    echo -e "  شناسه نمونه: ${GREEN}$INSTANCE_ID${NC}"
    echo -e "  آدرس سرور: ${GREEN}$SERVER_ADDRESS${NC}"
    echo ""
    
    read -p "آیا ادامه دهیم؟ (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        execute_installation
    else
        show_main_menu
    fi
}

# اجرای مراحل نصب
execute_installation() {
    print_step "شروع فرآیند نصب پیشرفته")
    
    # ایجاد دایرکتوری‌ها
    mkdir -p $CONFIG_DIR $LOG_DIR
    
    # مراحل نصب
    optimize_system
    install_dependencies
    generate_encryption_key
    download_paqet
    create_advanced_config
    create_systemd_service
    create_health_check
    
    # راه‌اندازی سرویس
    print_step "راه‌اندازی سرویس")
    
    local service_name="paqet-${INSTANCE_ID}"
    systemctl start "${service_name}.service"
    
    # بررسی وضعیت
    sleep 2
    local service_status=$(systemctl is-active "${service_name}.service")
    
    if [ "$service_status" == "active" ]; then
        print_success "✅ نصب با موفقیت کامل شد!")
        
        # نمایش اطلاعات نهایی
        show_installation_summary
    else
        print_warning "⚠️  سرویس راه‌اندازی شد اما ممکن است نیاز به بررسی داشته باشد")
        print_info "دستور بررسی وضعیت: systemctl status ${service_name}")
        
        show_installation_summary
    fi
}

# نمایش خلاصه نصب
show_installation_summary() {
    print_step "خلاصه اطلاعات نصب")
    
    local config_file="$CONFIG_DIR/config-${INSTANCE_ID}.yaml"
    local listen_port=$(grep "listen_port" "$config_file" | awk '{print $2}')
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}               نصب Paqet پیشرفته کامل شد!               ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}🔧 شناسه نمونه:${NC} ${GREEN}$INSTANCE_ID${NC}"
    echo -e "  ${YELLOW}🎭 نقش سیستم:${NC} ${GREEN}$ROLE${NC}"
    echo -e "  ${YELLOW}🛡️ سطح استتار:${NC} ${GREEN}$OBFUSCATION_LEVEL${NC}"
    echo -e "  ${YELLOW}🔌 پورت شنود:${NC} ${GREEN}$listen_port${NC}"
    echo ""
    
    if [ "$ROLE" == "server" ]; then
        echo -e "  ${YELLOW}🌍 آدرس سرور برای کلاینت‌ها:${NC}"
        echo -e "  ${GREEN}$PUBLIC_IP:$listen_port${NC}"
        echo ""
    fi
    
    echo -e "  ${YELLOW}📋 دستورات مدیریتی:${NC}"
    echo -e "  ${CYAN}systemctl status paqet-${INSTANCE_ID}${NC}"
    echo -e "  ${CYAN}systemctl restart paqet-${INSTANCE_ID}${NC}"
    echo -e "  ${CYAN}journalctl -u paqet-${INSTANCE_ID} -f${NC}"
    echo ""
    echo -e "  ${YELLOW}📊 لاگ‌ها:${NC} ${GREEN}$LOG_DIR/${NC}"
    echo -e "  ${YELLOW}⚙️  کانفیگ:${NC} ${GREEN}$config_file${NC}"
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}💡 نکته امنیتی مهم:${NC}"
    echo -e "این روش با تولید الگوهای منحصربفرد برای هر نصب، تشخیص DPI را سخت می‌کند."
    echo -e "هرچه کاربران بیشتری از این روش استفاده کنند، تشخیص آن سخت‌تر می‌شود."
    echo ""
    
    read -p "برای بازگشت به منوی اصلی Enter بزنید..." dummy
    show_main_menu
}

# نمایش اطلاعات سیستم
show_system_info() {
    print_step "اطلاعات سیستم")
    
    local os=$(detect_os)
    local arch=$(detect_arch)
    local public_ip=$(curl -4 -s ifconfig.me 2>/dev/null || echo "نامشخص")
    local interfaces=$(ip -o -4 addr show | awk '{print $2 ": " $4}')
    
    echo -e "${CYAN}سیستم عامل:${NC} $os"
    echo -e "${CYAN}معماری:${NC} $arch"
    echo -e "${CYAN}IP عمومی:${NC} $public_ip"
    echo -e "${CYAN}شناسه نمونه:${NC} $INSTANCE_ID"
    echo ""
    echo -e "${CYAN}کارت‌های شبکه:${NC}"
    echo "$interfaces"
    echo ""
    
    # بررسی سرویس‌های فعال Paqet
    local active_services=$(systemctl list-units --type=service --all | grep paqet | awk '{print $1}')
    
    if [ -n "$active_services" ]; then
        echo -e "${CYAN}سرویس‌های Paqet فعال:${NC}"
        for service in $active_services; do
            local status=$(systemctl is-active "$service")
            echo -e "  $service: ${status^^}"
        done
    fi
}

# حذف نصب
uninstall_paqet() {
    print_step "حذف نصب Paqet")
    
    echo -e "${RED}⚠️  هشدار: این عمل تمامی تنظیمات Paqet را حذف می‌کند.${NC}"
    read -p "آیا مطمئن هستید؟ (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # توقف تمام سرویس‌های Paqet
        print_info "توقف سرویس‌ها")
        systemctl list-units --type=service --all | grep paqet | awk '{print $1}' | while read service; do
            systemctl stop "$service" 2>/dev/null
            systemctl disable "$service" 2>/dev/null
        done
        
        # حذف فایل‌های سرویس
        print_info "حذف فایل‌های سرویس")
        rm -f $SERVICE_DIR/paqet-*.service
        systemctl daemon-reload
        
        # حذف دایرکتوری‌ها
        print_info "حذف دایرکتوری‌ها")
        rm -rf $CONFIG_DIR $INSTALL_DIR $LOG_DIR
        
        # حذف کرون‌جاب
        print_info "حذف کرون‌جاب‌ها")
        rm -f /etc/cron.d/paqet-*
        
        # حذف باینری
        print_info "حذف باینری")
        rm -f $BIN_DIR/paqet
        
        # حذف تنظیمات sysctl
        print_info "حذف تنظیمات sysctl")
        rm -f /etc/sysctl.d/99-paqet-optimization.conf
        sysctl --system > /dev/null 2>&1
        
        print_success "حذف نصب کامل شد")
    else
        print_info "عملیات حذف لغو شد")
    fi
    
    read -p "برای بازگشت به منوی اصلی Enter بزنید..." dummy
    show_main_menu
}

# تابع اصلی
main() {
    # بررسی دسترسی root
    check_root
    
    # نمایش منوی اصلی
    show_main_menu
}

# اجرای تابع اصلی
main "$@"
