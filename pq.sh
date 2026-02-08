#!/bin/bash

# ============================================================================
# Paqet Tunnel Advanced Installer - ضد DPI پیشرفته
# Version: 4.1-stable
# ============================================================================

set -e

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# مسیرها
CONFIG_DIR="/etc/paqet-advanced"
SERVICE_DIR="/etc/systemd/system"
LOG_DIR="/var/log/paqet"
BIN_DIR="/usr/local/bin"
INSTALL_DIR="/opt/paqet-advanced"

# نسخه
SCRIPT_VERSION="4.1-stable"
PAQET_VERSION="v1.0.0-alpha.14"
GITHUB_REPO="hanselime/paqet"

# متغیرها
ROLE=""
ENCRYPTION_KEY=""
OBFUSCATION_LEVEL=""
INSTANCE_ID=$(date +%s%N | sha256sum | head -c 8)
PUBLIC_IP=""
SERVER_ADDRESS=""

# توابع نمایش - بدون پرانتز مشکل‌دار
print_banner() {
    clear
    echo -e "${MAGENTA}"
    echo "================================================================"
    echo "   ██████╗  █████╗  ██████╗ ███████╗████████╗"
    echo "   ██╔══██╗██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝"
    echo "   ██████╔╝███████║██║   ██║█████╗     ██║"
    echo "   ██╔═══╝ ██╔══██║██║▄▄ ██║██╔══╝     ██║"
    echo "   ██║     ██║  ██║╚██████╔╝███████╗   ██║"
    echo "   ╚═╝     ╚═╝  ╚═╝ ╚══▀▀═╝ ╚══════╝   ╚═╝"
    echo "          Advanced Anti-DPI Tunnel v${SCRIPT_VERSION}"
    echo "                Instance: ${INSTANCE_ID}"
    echo "================================================================"
    echo -e "${NC}"
    echo -e "${YELLOW}فلسفه: امنیت در جمعیت - هر نصب منحصربفرد${NC}"
    echo ""
}

print_step() { 
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() { 
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() { 
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() { 
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() { 
    echo -e "${CYAN}[i]${NC} $1"
}

# ============================================================================
# توابع اصلی
# ============================================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "این اسکریپت نیاز به دسترسی root دارد"
        exit 1
    fi
    print_success "دسترسی root تایید شد"
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    fi
    echo "$OS"
}

detect_arch() {
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l)
            echo "armv7"
            ;;
        i386|i686)
            echo "386"
            ;;
        *)
            print_error "معماری نامشخص: $arch"
            exit 1
            ;;
    esac
}

optimize_system() {
    print_step "بهینه‌سازی سیستم برای عملکرد بهتر"
    
    cat > /etc/sysctl.d/99-paqet.conf << EOF
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
EOF
    
    sysctl -p /etc/sysctl.d/99-paqet.conf >/dev/null 2>&1
    print_success "بهینه‌سازی اعمال شد"
}

install_dependencies() {
    print_step "نصب پیش‌نیازها"
    
    os=$(detect_os)
    
    case "$os" in
        ubuntu|debian)
            apt update -qq
            apt install -y curl wget libpcap-dev iptables iproute2 >/dev/null 2>&1
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y curl wget libpcap-devel iptables iproute >/dev/null 2>&1
            ;;
        *)
            print_warning "سیستم عامل ناشناخته - نصب دستی مورد نیاز"
            ;;
    esac
    
    print_success "پیش‌نیازها نصب شدند"
}

generate_encryption_key() {
    print_step "تولید کلید رمزنگاری"
    
    if command -v openssl >/dev/null 2>&1; then
        ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
    else
        ENCRYPTION_KEY=$(date +%s%N | sha256sum | base64 | head -c 32)
    fi
    
    print_success "کلید تولید شد: ${ENCRYPTION_KEY:0:8}..."
}

download_paqet() {
    print_step "دریافت باینری Paqet"
    
    arch=$(detect_arch)
    filename="paqet-linux-${arch}-${PAQET_VERSION}.tar.gz"
    url="https://github.com/${GITHUB_REPO}/releases/download/${PAQET_VERSION}/${filename}"
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$LOG_DIR"
    
    if ! curl -L -o /tmp/paqet.tar.gz "$url"; then
        print_error "دانلود ناموفق"
        exit 1
    fi
    
    tar -xzf /tmp/paqet.tar.gz -C "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/paqet"
    ln -sf "$INSTALL_DIR/paqet" "$BIN_DIR/paqet"
    
    print_success "Paqet نصب شد"
}

generate_random_port() {
    ports=(443 8443 8080 8880 9443 7080 65432 50050)
    index=$((RANDOM % ${#ports[@]}))
    echo "${ports[$index]}"
}

create_advanced_config() {
    print_step "ایجاد کانفیگ پیشرفته"
    
    mkdir -p "$CONFIG_DIR"
    
    LISTEN_PORT=$(generate_random_port)
    CONFIG_FILE="$CONFIG_DIR/config-${INSTANCE_ID}.yaml"
    
    cat > "$CONFIG_FILE" << EOF
metadata:
  instance_id: "${INSTANCE_ID}"
  version: "${SCRIPT_VERSION}"

network:
  role: "${ROLE}"
  listen_port: ${LISTEN_PORT}
  interface: "auto"

encryption:
  key: "${ENCRYPTION_KEY}"
  algorithm: "chacha20-poly1305"

kcp_settings:
  mode: "fast3"
  mtu: 1200
  sndwnd: 1024
  rcvwnd: 1024
  nodelay: 1
  interval: 20

performance:
  max_connections: 1000
  buffer_size: 8388608

obfuscation:
  enabled: true
  fake_tls: true
  random_padding: true
EOF
    
    if [ "$ROLE" = "client" ] && [ -n "$SERVER_ADDRESS" ]; then
        echo "  server_address: \"${SERVER_ADDRESS}\"" >> "$CONFIG_FILE"
    fi
    
    print_success "کانفیگ ایجاد شد: $CONFIG_FILE"
    print_info "پورت: $LISTEN_PORT"
}

create_systemd_service() {
    print_step "ایجاد سرویس systemd"
    
    SERVICE_NAME="paqet-${INSTANCE_ID}"
    SERVICE_FILE="$SERVICE_DIR/${SERVICE_NAME}.service"
    CONFIG_FILE="$CONFIG_DIR/config-${INSTANCE_ID}.yaml"
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Paqet Tunnel ${INSTANCE_ID}
After=network.target

[Service]
Type=simple
ExecStart=$BIN_DIR/paqet --config $CONFIG_FILE
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    
    print_success "سرویس ایجاد و راه‌اندازی شد: $SERVICE_NAME"
}

create_health_check() {
    print_step "ایجاد سیستم نظارت"
    
    HEALTH_SCRIPT="$CONFIG_DIR/health-${INSTANCE_ID}.sh"
    
    cat > "$HEALTH_SCRIPT" << 'EOF'
#!/bin/bash
INSTANCE="$1"
LOG="/var/log/paqet/health.log"
echo "$(date) - سلامت‌سنجی نمونه $INSTANCE" >> "$LOG"
if systemctl is-active --quiet "paqet-$INSTANCE"; then
    echo "سرویس فعال" >> "$LOG"
else
    echo "سرویس غیرفعال - راه‌اندازی مجدد" >> "$LOG"
    systemctl restart "paqet-$INSTANCE"
fi
curl -s --max-time 5 https://1.1.1.1/ >/dev/null 2>&1
EOF
    
    chmod +x "$HEALTH_SCRIPT"
    echo "*/5 * * * * root $HEALTH_SCRIPT $INSTANCE_ID" > /etc/cron.d/paqet-health
    print_success "سیستم نظارت ایجاد شد"
}

# ============================================================================
# منوها
# ============================================================================

show_main_menu() {
    print_banner
    echo -e "${CYAN}نقش سیستم را انتخاب کنید:${NC}"
    echo "1) سرور (خارج از ایران)"
    echo "2) کلاینت (داخل ایران)"
    echo "3) اطلاعات سیستم"
    echo "4) حذف نصب"
    echo "5) خروج"
    echo ""
    
    read -p "انتخاب [1-5]: " choice
    
    case $choice in
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
            ;;
        4) 
            uninstall_paqet
            ;;
        5) 
            exit 0
            ;;
        *) 
            print_error "انتخاب نامعتبر"
            show_main_menu
            ;;
    esac
}

show_server_menu() {
    print_step "پیکربندی سرور"
    
    echo -e "${CYAN}سطح استتار:${NC}"
    echo "1) استاندارد (سرعت بالا)"
    echo "2) پیشرفته (تعادل)"
    echo "3) حرفه‌ای (حداکثر امنیت)"
    echo ""
    
    read -p "انتخاب [1-3]: " level
    
    case $level in
        1) OBFUSCATION_LEVEL="standard" ;;
        2) OBFUSCATION_LEVEL="advanced" ;;
        3) OBFUSCATION_LEVEL="expert" ;;
        *) OBFUSCATION_LEVEL="advanced" ;;
    esac
    
    PUBLIC_IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "نامشخص")
    print_info "IP عمومی: $PUBLIC_IP"
    
    echo ""
    read -p "آیا ادامه دهیم؟ (y/N): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        execute_installation
    else
        show_main_menu
    fi
}

show_client_menu() {
    print_step "پیکربندی کلاینت"
    
    echo -e "${CYAN}سطح استتار:${NC}"
    echo "1) استاندارد (سرعت بالا)"
    echo "2) پیشرفته (تعادل)"
    echo "3) حرفه‌ای (حداکثر امنیت)"
    echo ""
    
    read -p "انتخاب [1-3]: " level
    
    case $level in
        1) OBFUSCATION_LEVEL="standard" ;;
        2) OBFUSCATION_LEVEL="advanced" ;;
        3) OBFUSCATION_LEVEL="expert" ;;
        *) OBFUSCATION_LEVEL="advanced" ;;
    esac
    
    echo ""
    read -p "آدرس سرور (IP یا دامنه): " SERVER_ADDRESS
    
    if [ -z "$SERVER_ADDRESS" ]; then
        print_error "آدرس سرور ضروری است"
        show_client_menu
        return
    fi
    
    read -p "آیا ادامه دهیم؟ (y/N): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        execute_installation
    else
        show_main_menu
    fi
}

execute_installation() {
    print_step "شروع نصب پیشرفته"
    
    optimize_system
    install_dependencies
    generate_encryption_key
    download_paqet
    create_advanced_config
    create_systemd_service
    create_health_check
    
    print_success "✅ نصب کامل شد!"
    show_installation_summary
}

show_installation_summary() {
    print_step "خلاصه نصب"
    
    CONFIG_FILE="$CONFIG_DIR/config-${INSTANCE_ID}.yaml"
    PORT=$(grep "listen_port" "$CONFIG_FILE" | awk '{print $2}')
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}               نصب Paqet پیشرفته کامل شد!               ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  شناسه نمونه: ${GREEN}$INSTANCE_ID${NC}"
    echo -e "  نقش: ${GREEN}$ROLE${NC}"
    echo -e "  سطح استتار: ${GREEN}$OBFUSCATION_LEVEL${NC}"
    echo -e "  پورت: ${GREEN}$PORT${NC}"
    echo ""
    
    if [ "$ROLE" = "server" ]; then
        echo -e "  آدرس سرور برای کلاینت‌ها:"
        echo -e "  ${GREEN}$PUBLIC_IP:$PORT${NC}"
        echo ""
    fi
    
    echo -e "  دستورات مدیریت:"
    echo -e "  ${CYAN}systemctl status paqet-$INSTANCE_ID${NC}"
    echo -e "  ${CYAN}journalctl -u paqet-$INSTANCE_ID -f${NC}"
    echo ""
    echo -e "  کانفیگ: ${GREEN}$CONFIG_FILE${NC}"
    echo -e "  لاگ‌ها: ${GREEN}$LOG_DIR/${NC}"
    echo ""
    
    read -p "برای ادامه Enter بزنید..."
    show_main_menu
}

show_system_info() {
    print_step "اطلاعات سیستم"
    
    echo -e "سیستم عامل: $(detect_os)"
    echo -e "معماری: $(detect_arch)"
    echo -e "شناسه نمونه: $INSTANCE_ID"
    echo ""
    
    read -p "برای ادامه Enter بزنید..."
    show_main_menu
}

uninstall_paqet() {
    print_step "حذف نصب"
    
    read -p "آیا مطمئن هستید؟ (y/N): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        show_main_menu
        return
    fi
    
    systemctl list-units --type=service 2>/dev/null | grep paqet | awk '{print $1}' | while read -r service; do
        systemctl stop "$service" 2>/dev/null
        systemctl disable "$service" 2>/dev/null
    done
    
    rm -f $SERVICE_DIR/paqet-*.service 2>/dev/null
    rm -rf "$CONFIG_DIR" "$INSTALL_DIR" "$LOG_DIR" 2>/dev/null
    rm -f /etc/cron.d/paqet-health 2>/dev/null
    rm -f "$BIN_DIR/paqet" 2>/dev/null
    
    systemctl daemon-reload
    
    print_success "حذف کامل شد"
    show_main_menu
}

# ============================================================================
# اجرای اصلی
# ============================================================================

main() {
    check_root
    show_main_menu
}

main "$@"
