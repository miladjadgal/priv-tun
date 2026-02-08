#!/bin/bash

# Paqet Tunnel Installer - نسخه پایدار
# توجه: در Paqet نقش‌ها معکوس هستند!
# خارج (خارج): client | داخل (ایران): server

set -e

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# مسیرها
CONFIG_DIR="/etc/paqet"
INSTALL_DIR="/usr/local/bin"
LOG_DIR="/var/log/paqet"
SERVICE_DIR="/etc/systemd/system"

# توابع نمایش
print_step() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# بررسی root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "نیاز به دسترسی root دارید"
        exit 1
    fi
}

# منوی اصلی با توضیح نقش‌ها
show_main_menu() {
    clear
    echo -e "${CYAN}====== Paqet Tunnel Installer ======${NC}"
    echo -e "${YELLOW}توجه: نقش‌ها در Paqet معکوس هستند!${NC}"
    echo ""
    echo -e "نقش سیستم را انتخاب کنید:"
    echo -e "  ${GREEN}1) سرور (داخل ایران)${NC}"
    echo -e "     - این سیستم ترافیک را به خارج ارسال می‌کند"
    echo -e "  ${GREEN}2) کلاینت (خارج از ایران)${NC}"
    echo -e "     - این سیستم ترافیک را از ایران دریافت می‌کند"
    echo -e "  ${GREEN}3) خروج${NC}"
    echo ""
    
    read -p "انتخاب شما [1-3]: " choice
    
    case $choice in
        1)
            setup_server_iran
            ;;
        2)
            setup_client_kharej
            ;;
        3)
            exit 0
            ;;
        *)
            print_error "انتخاب نامعتبر"
            sleep 2
            show_main_menu
            ;;
    esac
}

# شناسایی معماری
detect_arch() {
    arch=$(uname -m)
    case $arch in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l) echo "armv7" ;;
        i386|i686) echo "386" ;;
        *) 
            print_error "معماری پشتیبانی نشده: $arch"
            exit 1
            ;;
    esac
}

# نصب وابستگی‌ها
install_dependencies() {
    print_step "نصب وابستگی‌ها"
    
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y curl wget tar iptables iproute2 libpcap-dev
    elif [ -f /etc/redhat-release ]; then
        yum install -y curl wget tar iptables iproute libpcap-devel
    else
        print_warning "سیستم عامل نامشخص، وابستگی‌ها ممکن است نصب نشوند"
    fi
    
    print_success "وابستگی‌ها نصب شدند"
}

# دانلود و نصب Paqet با حل مشکل extract
install_paqet_binary() {
    print_step "دریافت و نصب Paqet"
    
    local arch=$(detect_arch)
    local version="v1.0.0-alpha.14"
    local url="https://github.com/hanselime/paqet/releases/download/${version}/paqet-linux-${arch}-${version}.tar.gz"
    
    # دانلود
    if ! curl -L -o /tmp/paqet.tar.gz "$url"; then
        print_error "دانلود ناموفق بود"
        return 1
    fi
    
    # ایجاد دایرکتوری موقت برای extract
    local temp_dir=$(mktemp -d)
    tar -xzf /tmp/paqet.tar.gz -C "$temp_dir"
    
    # یافتن فایل باینری (ممکن است در مسیرهای مختلف باشد)
    local binary_path=""
    
    # جستجو در مسیرهای ممکن
    for path in "$temp_dir/paqet" "$temp_dir/paqet-linux-${arch}/paqet" "$temp_dir/bin/paqet"; do
        if [ -f "$path" ]; then
            binary_path="$path"
            break
        fi
    done
    
    if [ -z "$binary_path" ]; then
        # لیست محتوای آرشیو برای دیباگ
        print_warning "محتوای آرشیو:"
        tar -tzf /tmp/paqet.tar.gz | head -10
        print_error "فایل باینری Paqet یافت نشد"
        return 1
    fi
    
    # کپی باینری به مسیر سیستم
    cp "$binary_path" "$INSTALL_DIR/paqet"
    chmod +x "$INSTALL_DIR/paqet"
    
    # تمیزکاری
    rm -rf "$temp_dir" /tmp/paqet.tar.gz
    
    print_success "Paqet نصب شد در $INSTALL_DIR/paqet"
    return 0
}

# تولید کلید امنیتی
generate_key() {
    print_step "تولید کلید رمزنگاری"
    
    if command -v openssl >/dev/null 2>&1; then
        key=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
    else
        key=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
    fi
    
    echo "$key"
    print_success "کلید تولید شد"
}

# تنظیمات سرور (داخل ایران)
setup_server_iran() {
    clear
    echo -e "${CYAN}====== پیکربندی سرور (داخل ایران) ======${NC}"
    echo -e "${YELLOW}این سیستم ترافیک را به خارج ارسال می‌کند${NC}"
    echo ""
    
    # نصب وابستگی‌ها
    install_dependencies
    
    # نصب Paqet
    if ! install_paqet_binary; then
        print_error "نصب Paqet ناموفق بود"
        exit 1
    fi
    
    # تولید کلید
    local key=$(generate_key)
    
    # دریافت پورت
    read -p "پورت شنود (پیشفرض: 443): " port
    port=${port:-443}
    
    # ایجاد کانفیگ
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/config.yaml" << EOF
# پیکربندی سرور Paqet (داخل ایران)
role: server
listen: 0.0.0.0:${port}
encryption_key: ${key}
kcp:
  mode: fast3
  mtu: 1350
  sndwnd: 1024
  rcvwnd: 1024
EOF
    
    print_success "کانفیگ سرور ایجاد شد"
    
    # نمایش اطلاعات
    local ip=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}✅ پیکربندی سرور کامل شد!${NC}"
    echo -e "آدرس سرور: ${YELLOW}$ip${NC}"
    echo -e "پورت: ${YELLOW}$port${NC}"
    echo -e "کلید: ${YELLOW}${key:0:16}...${NC}"
    echo ""
    echo -e "برای اتصال کلاینت (خارج) از اطلاعات بالا استفاده کنید"
    echo ""
    
    # ایجاد سرویس
    create_systemd_service "server"
    
    read -p "برای بازگشت به منو Enter بزنید..." dummy
    show_main_menu
}

# تنظیمات کلاینت (خارج از ایران)
setup_client_kharej() {
    clear
    echo -e "${CYAN}====== پیکربندی کلاینت (خارج از ایران) ======${NC}"
    echo -e "${YELLOW}این سیستم ترافیک را از ایران دریافت می‌کند${NC}"
    echo ""
    
    # نصب وابستگی‌ها
    install_dependencies
    
    # نصب Paqet
    if ! install_paqet_binary; then
        print_error "نصب Paqet ناموفق بود"
        exit 1
    fi
    
    # دریافت اطلاعات سرور
    read -p "آدرس IP سرور (داخل ایران): " server_ip
    read -p "پورت سرور (پیشفرض: 443): " server_port
    server_port=${server_port:-443}
    read -p "کلید رمزنگاری: " encryption_key
    
    # ایجاد کانفیگ
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/config.yaml" << EOF
# پیکربندی کلاینت Paqet (خارج از ایران)
role: client
server: ${server_ip}:${server_port}
encryption_key: ${encryption_key}
kcp:
  mode: fast2
  mtu: 1350
  sndwnd: 2048
  rcvwnd: 2048
EOF
    
    print_success "کانفیگ کلاینت ایجاد شد"
    
    # ایجاد سرویس
    create_systemd_service "client"
    
    echo ""
    echo -e "${GREEN}✅ پیکربندی کلاینت کامل شد!${NC}"
    echo -e "سرور: ${YELLOW}${server_ip}:${server_port}${NC}"
    echo ""
    
    read -p "برای بازگشت به منو Enter بزنید..." dummy
    show_main_menu
}

# ایجاد سرویس systemd
create_systemd_service() {
    local role=$1
    print_step "ایجاد سرویس systemd"
    
    cat > "$SERVICE_DIR/paqet.service" << EOF
[Unit]
Description=Paqet Tunnel (${role})
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/paqet --config $CONFIG_DIR/config.yaml
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable paqet
    systemctl start paqet
    
    # بررسی وضعیت
    sleep 2
    if systemctl is-active --quiet paqet; then
        print_success "سرویس Paqet راه‌اندازی شد"
        print_step "دستورات مدیریت:"
        echo "  systemctl status paqet"
        echo "  journalctl -u paqet -f"
    else
        print_warning "سرویس شروع نشد، بررسی دستی نیاز است"
    fi
}

# تابع اصلی
main() {
    check_root
    show_main_menu
}

# شروع اسکریپت
main "$@"
