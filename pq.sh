
#!/bin/bash

# Paqet Tunnel Installer - نسخه ساده و بدون خطا
# با قابلیت ضد DPI

set -e

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# مسیرها
CONFIG_DIR="/etc/paqet"
INSTALL_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"
LOG_DIR="/var/log/paqet"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "لطفا با sudo اجرا کنید: sudo bash $0"
        exit 1
    fi
}

show_menu() {
    clear
    echo -e "${CYAN}=== نصب کننده Paqet Tunnel ===${NC}"
    echo ""
    echo "1) سرور (داخل ایران)"
    echo "   - ترافیک را به خارج ارسال می‌کند"
    echo "2) کلاینت (خارج از ایران)"
    echo "   - ترافیک را از ایران دریافت می‌کند"
    echo "3) تست سیستم"
    echo "4) خروج"
    echo ""
    read -p "انتخاب شما: " choice
    
    case $choice in
        1) setup_server ;;
        2) setup_client ;;
        3) test_system ;;
        4) exit 0 ;;
        *) show_menu ;;
    esac
}

detect_arch() {
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l) echo "armv7" ;;
        i386|i686) echo "386" ;;
        *) 
            print_error "معماری $arch پشتیبانی نمی‌شود"
            exit 1
            ;;
    esac
}

install_dependencies() {
    print_step "نصب پیش‌نیازها"
    
    if [ -f /etc/debian_version ]; then
        apt update -qq
        apt install -y curl tar iptables iproute2 libpcap-dev >/dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        yum install -y curl tar iptables iproute libpcap-devel >/dev/null 2>&1
    else
        print_warning "سیستم عامل ناشناخته - نصب دستی مورد نیاز"
    fi
    
    print_success "پیش‌نیازها نصب شدند"
}

# نصب Paqet - روش مستقیم و بدون آرایه
install_paqet() {
    print_step "نصب Paqet"
    
    local arch=$(detect_arch)
    local version="v1.0.0-alpha.14"
    local temp_dir=$(mktemp -d)
    
    cd "$temp_dir"
    
    # دانلود
    print_step "دانلود باینری Paqet"
    curl -L -o paqet.tar.gz "https://github.com/hanselime/paqet/releases/download/$version/paqet-linux-$arch-$version.tar.gz"
    
    # استخراج
    tar -xzf paqet.tar.gz
    
    # یافتن فایل باینری (روش ساده)
    local binary_found=""
    
    # الگوهای جستجو (هر کدام را امتحان می‌کنیم)
    if [ -f "paqet_linux_$arch" ]; then
        binary_found="paqet_linux_$arch"
    elif [ -f "paqet" ]; then
        binary_found="paqet"
    elif [ -f "paqet-linux-$arch" ]; then
        binary_found="paqet-linux-$arch"
    else
        # جستجو برای هر فایلی که paqet در نامش باشد
        for file in *; do
            if [[ "$file" == *"paqet"* ]] && [ -f "$file" ]; then
                binary_found="$file"
                break
            fi
        done
    fi
    
    if [ -z "$binary_found" ]; then
        print_error "فایل باینری Paqet یافت نشد"
        print_step "فایل‌های موجود:"
        ls -la
        cd /
        rm -rf "$temp_dir"
        return 1
    fi
    
    print_success "فایل باینری پیدا شد: $binary_found"
    
    # کپی به مسیر سیستم
    cp "$binary_found" "$INSTALL_DIR/paqet"
    chmod +x "$INSTALL_DIR/paqet"
    
    # تست
    if [ -x "$INSTALL_DIR/paqet" ]; then
        print_success "Paqet با موفقیت نصب شد"
    else
        print_error "مشکل در نصب Paqet"
        cd /
        rm -rf "$temp_dir"
        return 1
    fi
    
    cd /
    rm -rf "$temp_dir"
    return 0
}

# تنظیمات سرور (ایران)
setup_server() {
    clear
    print_step "پیکربندی سرور (داخل ایران)")
    
    install_dependencies
    
    if ! install_paqet; then
        print_error "نصب Paqet ناموفق بود"
        exit 1
    fi
    
    # تولید کلید امنیتی
    print_step "تولید کلید رمزنگاری")
    local key=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
    
    # دریافت پورت
    echo ""
    echo -e "${YELLOW}پورت را انتخاب کنید:${NC}"
    echo "443 - (پیشنهادی، شبیه HTTPS)"
    echo "8443 - (پیشنهادی، شبیه HTTPS جایگزین)"
    echo "8080 - (پیشنهادی، شبیه HTTP پروکسی)"
    echo "یا هر پورت دلخواه دیگر"
    read -p "پورت (پیشفرض 443): " port
    port=${port:-443}
    
    # آدرس IP عمومی
    local ip=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    
    # ایجاد کانفیگ با تنظیمات ضد DPI
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    
    cat > "$CONFIG_DIR/config.yaml" << EOF
# Paqet Server - Anti-DPI Configuration
role: server
listen: 0.0.0.0:$port
encryption_key: $key

# تنظیمات شبکه
tcp_timeout: 300
udp_timeout: 60

# تنظیمات KCP برای عملکرد بهتر
kcp:
  mode: fast3
  mtu: 1200
  sndwnd: 1024
  rcvwnd: 1024
  nodelay: 1
  interval: 20
  resend: 2
  nc: 1

# بهینه‌سازی‌های ضد DPI
obfuscation:
  enabled: true
  fake_tls: true
  random_padding: true
  traffic_masking: true

# لاگ‌گیری
log:
  level: info
  file: $LOG_DIR/paqet-server.log
EOF
    
    # نمایش اطلاعات
    echo ""
    echo -e "${GREEN}✅ سرور با موفقیت پیکربندی شد!${NC}"
    echo "========================================"
    echo -e "آدرس سرور: ${YELLOW}$ip${NC}"
    echo -e "پورت: ${YELLOW}$port${NC}"
    echo -e "کلید: ${YELLOW}$key${NC}"
    echo "========================================"
    echo ""
    echo -e "${CYAN}⚠️ این اطلاعات را برای پیکربندی کلاینت ذخیره کنید!${NC}"
    echo ""
    
    # ایجاد سرویس
    create_service
    
    read -p "برای بازگشت به منو Enter بزنید..."
    show_menu
}

# تنظیمات کلاینت (خارج)
setup_client() {
    clear
    print_step "پیکربندی کلاینت (خارج از ایران)")
    
    install_dependencies
    
    if ! install_paqet; then
        print_error "نصب Paqet ناموفق بود"
        exit 1
    fi
    
    echo ""
    echo -e "${YELLOW}لطفاً اطلاعات سرور (داخل ایران) را وارد کنید:${NC}"
    echo ""
    
    read -p "آدرس IP یا دامنه سرور: " server_ip
    read -p "پورت سرور: " server_port
    read -p "کلید رمزنگاری: " key
    
    # ایجاد کانفیگ کلاینت
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    
    cat > "$CONFIG_DIR/config.yaml" << EOF
# Paqet Client - Anti-DPI Configuration
role: client
server: $server_ip:$server_port
encryption_key: $key

# تنظیمات شبکه
tcp_timeout: 300
udp_timeout: 60

# تنظیمات KCP برای عملکرد بهتر
kcp:
  mode: fast2
  mtu: 1200
  sndwnd: 2048
  rcvwnd: 2048
  nodelay: 1
  interval: 10
  resend: 2
  nc: 1

# بهینه‌سازی‌های ضد DPI
obfuscation:
  enabled: true
  fake_tls: true
  random_padding: true
  traffic_masking: true

# لاگ‌گیری
log:
  level: info
  file: $LOG_DIR/paqet-client.log
EOF
    
    print_success "پیکربندی کلاینت ایجاد شد"
    
    # ایجاد سرویس
    create_service
    
    echo ""
    echo -e "${GREEN}✅ کلاینت با موفقیت پیکربندی شد!${NC}"
    echo -e "اتصال به: ${YELLOW}$server_ip:$server_port${NC}"
    echo ""
    
    read -p "برای بازگشت به منو Enter بزنید..."
    show_menu
}

# ایجاد سرویس systemd
create_service() {
    print_step "ایجاد سرویس systemd")
    
    cat > "$SERVICE_DIR/paqet.service" << EOF
[Unit]
Description=Paqet Tunnel Service
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/paqet --config $CONFIG_DIR/config.yaml
Restart=always
RestartSec=5
User=root
LimitNOFILE=65536

# لاگ‌گیری
StandardOutput=append:$LOG_DIR/service.log
StandardError=append:$LOG_DIR/error.log

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable paqet.service
    systemctl start paqet.service
    
    sleep 2
    
    if systemctl is-active paqet.service >/dev/null 2>&1; then
        print_success "سرویس فعال شد"
        echo ""
        echo -e "${CYAN}دستورات مدیریت:${NC}"
        echo "  systemctl status paqet"
        echo "  journalctl -u paqet -f"
        echo "  tail -f $LOG_DIR/service.log"
    else
        print_warning "سرویس شروع نشد. بررسی خطاها:"
        journalctl -u paqet -n 20 --no-pager
    fi
}

# تست سیستم
test_system() {
    clear
    print_step "تست سیستم")
    
    echo "1. معماری سیستم: $(detect_arch)"
    echo "2. دسترسی root: $(if [ $EUID -eq 0 ]; then echo "✓"; else echo "✗"; fi)"
    echo "3. دسترسی curl: $(if command -v curl >/dev/null; then echo "✓"; else echo "✗"; fi)"
    echo "4. دسترسی tar: $(if command -v tar >/dev/null; then echo "✓"; else echo "✗"; fi)"
    echo "5. IP عمومی: $(curl -4 -s ifconfig.me 2>/dev/null || echo "نامشخص")"
    echo "6. وضعیت فایروال: $(if command -v iptables >/dev/null; then echo "فعال"; else echo "غیرفعال"; fi)"
    
    echo ""
    
    # تست دسترسی به GitHub
    print_step "تست اتصال به GitHub")
    if curl -I https://github.com 2>/dev/null | head -1 | grep -q "200"; then
        print_success "اتصال به GitHub برقرار است"
    else
        print_warning "اتصال به GitHub مشکل دارد"
    fi
    
    echo ""
    read -p "برای بازگشت به منو Enter بزنید..."
    show_menu
}

# تابع اصلی
main() {
    check_root
    show_menu
}

# شروع اسکریپت
main "$@"
