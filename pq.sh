#!/bin/bash

# Paqet Tunnel Installer - نسخه پایدار
# توجه: در Paqet نقش‌ها معکوس هستند!

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
SERVICE_DIR="/etc/systemd/system"

# توابع نمایش
print_step() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

# بررسی root
check_root() {
    [ "$EUID" -eq 0 ] || { print_error "نیاز به sudo دارید"; exit 1; }
}

# منوی اصلی
show_menu() {
    echo -e "${CYAN}Paqet Tunnel Installer${NC}"
    echo "1) سرور (داخل ایران)"
    echo "2) کلاینت (خارج از ایران)"
    echo "3) خروج"
    read -p "انتخاب: " choice
    
    case $choice in
        1) setup_server ;;
        2) setup_client ;;
        3) exit 0 ;;
        *) show_menu ;;
    esac
}

# شناسایی معماری
detect_arch() {
    case $(uname -m) in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l) echo "armv7" ;;
        *) print_error "معماری نامشخص"; exit 1 ;;
    esac
}

# نصب Paqet (تصحیح شده)
install_paqet() {
    print_step "دریافت Paqet"
    
    local arch=$(detect_arch)
    local version="v1.0.0-alpha.14"
    local url="https://github.com/hanselime/paqet/releases/download/${version}/paqet-linux-${arch}-${version}.tar.gz"
    
    # دانلود
    curl -L -o /tmp/paqet.tar.gz "$url" || { print_error "دانلود ناموفق"; return 1; }
    
    # Extract و یافتن فایل صحیح
    tar -xzf /tmp/paqet.tar.gz -C /tmp/
    
    # فایل باینری نامش paqet_linux_amd64 است (بر اساس خروجی شما)
    local binary_name="paqet_linux_${arch}"
    
    if [ ! -f "/tmp/${binary_name}" ]; then
        print_error "فایل ${binary_name} یافت نشد"
        ls -la /tmp/
        return 1
    fi
    
    # کپی و تغییر نام به paqet
    cp "/tmp/${binary_name}" "$INSTALL_DIR/paqet"
    chmod +x "$INSTALL_DIR/paqet"
    
    rm -f /tmp/paqet.tar.gz "/tmp/${binary_name}"
    print_success "Paqet نصب شد"
    return 0
}

# تنظیمات سرور (ایران)
setup_server() {
    clear
    print_step "پیکربندی سرور (داخل ایران)"
    
    install_paqet || exit 1
    
    # تولید کلید
    local key=$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)
    key=$(echo "$key" | tr -dc 'a-zA-Z0-9' | head -c 32)
    
    # دریافت پورت
    read -p "پورت (پیشفرض 443): " port
    port=${port:-443}
    
    # ایجاد کانفیگ
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/config.yaml" << EOF
role: server
listen: 0.0.0.0:$port
encryption_key: $key
kcp:
  mode: fast3
  mtu: 1350
  sndwnd: 1024
  rcvwnd: 1024
EOF
    
    # نمایش اطلاعات
    local ip=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    
    echo ""
    print_success "سرور تنظیم شد!"
    echo -e "آدرس: ${YELLOW}$ip${NC}"
    echo -e "پورت: ${YELLOW}$port${NC}"
    echo -e "کلید: ${YELLOW}$key${NC}"
    echo ""
    echo "این اطلاعات را برای کلاینت (خارج) ذخیره کنید"
    
    create_service "server"
    
    read -p "ادامه..."
    show_menu
}

# تنظیمات کلاینت (خارج)
setup_client() {
    clear
    print_step "پیکربندی کلاینت (خارج از ایران)")
    
    install_paqet || exit 1
    
    # دریافت اطلاعات سرور
    read -p "آدرس سرور (ایران): " server_ip
    read -p "پورت سرور: " server_port
    read -p "کلید رمزنگاری: " key
    
    # ایجاد کانفیگ
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/config.yaml" << EOF
role: client
server: ${server_ip}:${server_port}
encryption_key: ${key}
kcp:
  mode: fast2
  mtu: 1350
  sndwnd: 2048
  rcvwnd: 2048
EOF
    
    print_success "کلاینت تنظیم شد!"
    create_service "client"
    
    read -p "ادامه..."
    show_menu
}

# ایجاد سرویس
create_service() {
    local role=$1
    print_step "ایجاد سرویس systemd"
    
    cat > "$SERVICE_DIR/paqet.service" << EOF
[Unit]
Description=Paqet Tunnel ($role)
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/paqet --config $CONFIG_DIR/config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable paqet
    systemctl start paqet
    
    sleep 2
    if systemctl is-active paqet; then
        print_success "سرویس فعال شد"
    else
        print_error "مشکل در شروع سرویس"
        journalctl -u paqet -n 10 --no-pager
    fi
}

# تابع اصلی
main() {
    check_root
    show_menu
}

main "$@"
