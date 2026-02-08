#!/bin/bash

# Paqet Tunnel Installer - نسخه قطعی
# مشکل: فایل باینری نام غیراستاندارد دارد

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

check_root() {
    [ "$EUID" -eq 0 ] || { print_error "نیاز به sudo"; exit 1; }
}

show_menu() {
    clear
    echo -e "${CYAN}=== Paqet Tunnel ===${NC}"
    echo "1) سرور (داخل ایران - ارسال ترافیک به خارج)"
    echo "2) کلاینت (خارج از ایران - دریافت ترافیک)"
    echo "3) خروج"
    echo ""
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
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l) echo "armv7" ;;
        i386|i686) echo "386" ;;
        *) print_error "معماری نامشخص"; exit 1 ;;
    esac
}

# نصب Paqet - روش جدید و مطمئن
install_paqet_binary() {
    print_step "دریافت و نصب Paqet"
    
    local arch=$(detect_arch)
    local version="v1.0.0-alpha.14"
    local url="https://github.com/hanselime/paqet/releases/download/${version}/paqet-linux-${arch}-${version}.tar.gz"
    
    # ایجاد دایرکتوری موقت
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # دانلود
    print_step "دانلود از GitHub..."
    if ! curl -L -o paqet.tar.gz "$url"; then
        print_error "دانلود ناموفق"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # استخراج
    print_step "استخراج آرشیو..."
    tar -xzf paqet.tar.gz 2>/dev/null || true
    
    # جستجوی فایل باینری (با الگوهای مختلف)
    local binary_path=""
    
    # الگوهای ممکن برای نام فایل
    local patterns=(
        "paqet"
        "paqet_linux_*"
        "paqet-linux-*"
        "*/paqet"
        "*paqet*"
    )
    
    for pattern in "${patterns[@]}"; do
        local found=$(find . -type f -name "$pattern" -executable 2>/dev/null | head -1)
        if [ -n "$found" ] && [ -f "$found" ]; then
            binary_path="$found"
            break
        fi
    done
    
    # اگر پیدا نشد، اولین فایل executable را بگیر
    if [ -z "$binary_path" ]; then
        print_warning "فایل باینری با نام استاندارد یافت نشد"
        print_step "جستجوی فایل‌های قابل اجرا..."
        
        # لیست همه فایل‌ها
        find . -type f -executable 2>/dev/null | while read file; do
            echo "  - $file"
            # اگر حاوی paqet باشد
            if [[ "$file" == *"paqet"* ]]; then
                binary_path="$file"
                print_step "فایل پیدا شد: $file"
            fi
        done
    fi
    
    if [ -z "$binary_path" ]; then
        print_error "هیچ فایل executable یافت نشد"
        print_step "محتوای دایرکتوری:"
        ls -la
        rm -rf "$temp_dir"
        return 1
    fi
    
    print_success "فایل باینری پیدا شد: $(basename "$binary_path")"
    
    # کپی به مسیر سیستم
    cp "$binary_path" "$INSTALL_DIR/paqet"
    chmod +x "$INSTALL_DIR/paqet"
    
    # تست اجرا
    if "$INSTALL_DIR/paqet" --help 2>&1 | grep -q "paqet"; then
        print_success "Paqet با موفقیت نصب شد"
    else
        print_warning "Paqet نصب شد اما تست اجرا ناموفق بود"
    fi
    
    # تمیزکاری
    cd /
    rm -rf "$temp_dir"
    return 0
}

# روش جایگزین: دانلود مستقیم باینری
install_paqet_direct() {
    print_step "روش جایگزین: دانلود مستقیم باینری"
    
    local arch=$(detect_arch)
    
    # دانلود مستقیم (اگر لینک مستقیم وجود داشته باشد)
    local direct_url="https://github.com/hanselime/paqet/releases/download/v1.0.0-alpha.14/paqet_linux_${arch}"
    
    if curl -L -o "$INSTALL_DIR/paqet" "$direct_url" 2>/dev/null; then
        chmod +x "$INSTALL_DIR/paqet"
        print_success "دانلود مستقیم موفق"
        return 0
    fi
    
    print_error "دانلود مستقیم ناموفق"
    return 1
}

# تنظیمات سرور (ایران)
setup_server() {
    clear
    print_step "پیکربندی سرور (داخل ایران)")
    
    # تلاش برای نصب Paqet
    if ! install_paqet_binary; then
        print_warning "تلاش با روش جایگزین..."
        if ! install_paqet_direct; then
            print_error "نصب Paqet ناموفق بود. لطفاً دستی نصب کنید."
            exit 1
        fi
    fi
    
    # تولید کلید
    local key=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
    
    # دریافت اطلاعات
    read -p "پورت شنود (پیشفرض 443): " port
    port=${port:-443}
    
    # آدرس IP
    local ip=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' | head -1)
    
    # ایجاد کانفیگ
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/config.yaml" << EOF
# Paqet Server (داخل ایران)
role: server
listen: 0.0.0.0:$port
encryption_key: $key

kcp:
  mode: fast3
  mtu: 1350
  sndwnd: 1024
  rcvwnd: 1024
EOF
    
    print_success "کانفیگ سرور ایجاد شد"
    
    # نمایش اطلاعات
    echo ""
    echo -e "${GREEN}✅ تنظیمات سرور کامل شد!${NC}"
    echo "========================================"
    echo -e "آدرس سرور: ${YELLOW}$ip${NC}"
    echo -e "پورت: ${YELLOW}$port${NC}"
    echo -e "کلید: ${YELLOW}$key${NC}"
    echo "========================================"
    echo ""
    echo "این اطلاعات را برای پیکربندی کلاینت (خارج) ذخیره کنید."
    
    # ایجاد سرویس
    create_service
    
    read -p "برای ادامه Enter بزنید..."
    show_menu
}

# تنظیمات کلاینت (خارج)
setup_client() {
    clear
    print_step "پیکربندی کلاینت (خارج از ایران)")
    
    # نصب Paqet
    if ! install_paqet_binary; then
        print_warning "تلاش با روش جایگزین..."
        if ! install_paqet_direct; then
            print_error "نصب Paqet ناموفق بود"
            exit 1
        fi
    fi
    
    # دریافت اطلاعات سرور
    echo ""
    echo "لطفاً اطلاعات سرور (داخل ایران) را وارد کنید:"
    read -p "آدرس IP سرور: " server_ip
    read -p "پورت سرور: " server_port
    read -p "کلید رمزنگاری: " key
    
    # ایجاد کانفیگ
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/config.yaml" << EOF
# Paqet Client (خارج از ایران)
role: client
server: ${server_ip}:${server_port}
encryption_key: ${key}

kcp:
  mode: fast2
  mtu: 1350
  sndwnd: 2048
  rcvwnd: 2048
EOF
    
    print_success "کانفیگ کلاینت ایجاد شد"
    
    # ایجاد سرویس
    create_service
    
    echo ""
    print_success "✅ کلاینت تنظیم شد!"
    echo "سرور: ${server_ip}:${server_port}"
    
    read -p "برای ادامه Enter بزنید..."
    show_menu
}

# ایجاد سرویس systemd
create_service() {
    print_step "ایجاد سرویس systemd"
    
    cat > "$SERVICE_DIR/paqet.service" << EOF
[Unit]
Description=Paqet Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/paqet --config $CONFIG_DIR/config.yaml
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable paqet.service
    systemctl restart paqet.service
    
    sleep 3
    
    if systemctl is-active paqet.service; then
        print_success "سرویس فعال شد"
        print_step "دستورات مدیریت:"
        echo "  systemctl status paqet"
        echo "  journalctl -u paqet -f"
    else
        print_warning "مشکل در فعال‌سازی سرویس"
        journalctl -u paqet -n 10 --no-pager
    fi
}

# تابع اصلی
main() {
    check_root
    show_menu
}

main "$@"
