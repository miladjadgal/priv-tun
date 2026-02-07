#!/bin/bash
# ============================================
# Simple GRE Tunnel Setup for Iran & Kharej
# No Xray installation - Only GRE Tunnel
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# تابع نمایش منو
show_menu() {
    clear
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════╗"
    echo "║   GRE Tunnel Setup Menu       ║"
    echo "╚═══════════════════════════════╝"
    echo -e "${NC}"
    
    echo "1) Setup Iran Server"
    echo "2) Setup Kharej Server"
    echo "3) Setup GRE Tunnel manually"
    echo "4) Check tunnel status"
    echo "5) Remove all tunnels"
    echo "6) Test connection"
    echo "7) Exit"
    echo ""
}

# تنظیم سرور ایران
setup_iran() {
    echo -e "${YELLOW}[*] Setting up Iran Server...${NC}"
    
    echo "Enter IP addresses:"
    read -p "Iran server public IP: " IRAN_IP
    read -p "Kharej server public IP: " KHAREJ_IP
    
    # اعتبارسنجی IP
    validate_ip $IRAN_IP
    validate_ip $KHAREJ_IP
    
    # حذف تونل‌های قدیمی
    clean_tunnels
    
    # ایجاد تونل GRE
    echo -e "${BLUE}[*] Creating GRE tunnel...${NC}"
    ip tunnel add gre1 mode gre remote $KHAREJ_IP local $IRAN_IP ttl 255
    ip addr add 10.10.10.1/30 dev gre1
    ip link set gre1 mtu 1476
    ip link set gre1 up
    
    # فعال‌سازی IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p 2>/dev/null || true
    
    # پیکربندی iptables
    setup_iptables_iran
    
    echo -e "${GREEN}[✓] Iran server setup complete!${NC}"
    echo ""
    echo "Iran GRE IP: 10.10.10.1"
    echo "Kharej GRE IP should be: 10.10.10.2"
    echo ""
    echo "On Kharej server run:"
    echo "ip tunnel add gre1 mode gre remote $IRAN_IP local $KHAREJ_IP ttl 255"
    echo "ip addr add 10.10.10.2/30 dev gre1"
    echo "ip link set gre1 up"
}

# تنظیم سرور خارج
setup_kharej() {
    echo -e "${YELLOW}[*] Setting up Kharej Server...${NC}"
    
    echo "Enter IP addresses:"
    read -p "Kharej server public IP: " KHAREJ_IP
    read -p "Iran server public IP: " IRAN_IP
    
    # اعتبارسنجی IP
    validate_ip $KHAREJ_IP
    validate_ip $IRAN_IP
    
    # حذف تونل‌های قدیمی
    clean_tunnels
    
    # ایجاد تونل GRE
    echo -e "${BLUE}[*] Creating GRE tunnel...${NC}"
    ip tunnel add gre1 mode gre remote $IRAN_IP local $KHAREJ_IP ttl 255
    ip addr add 10.10.10.2/30 dev gre1
    ip link set gre1 mtu 1476
    ip link set gre1 up
    
    # فعال‌سازی IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p 2>/dev/null || true
    
    # اضافه کردن route
    ip route add 192.168.0.0/16 via 10.10.10.1 dev gre1 2>/dev/null || true
    ip route add 10.0.0.0/8 via 10.10.10.1 dev gre1 2>/dev/null || true
    
    echo -e "${GREEN}[✓] Kharej server setup complete!${NC}"
    echo ""
    echo "Kharej GRE IP: 10.10.10.2"
    echo "Iran GRE IP should be: 10.10.10.1"
}

# تنظیم دستی تونل
setup_manual() {
    echo -e "${YELLOW}[*] Manual GRE Tunnel Setup${NC}"
    
    read -p "Local IP address: " LOCAL_IP
    read -p "Remote IP address: " REMOTE_IP
    read -p "Local GRE IP [10.10.10.1]: " GRE_LOCAL
    read -p "Remote GRE IP [10.10.10.2]: " GRE_REMOTE
    
    GRE_LOCAL=${GRE_LOCAL:-10.10.10.1}
    GRE_REMOTE=${GRE_REMOTE:-10.10.10.2}
    
    # اعتبارسنجی
    validate_ip $LOCAL_IP
    validate_ip $REMOTE_IP
    
    # حذف تونل‌های قدیمی
    clean_tunnels
    
    # ایجاد تونل
    ip tunnel add gre1 mode gre remote $REMOTE_IP local $LOCAL_IP ttl 255
    ip addr add $GRE_LOCAL/30 dev gre1
    ip link set gre1 mtu 1476
    ip link set gre1 up
    
    echo -e "${GREEN}[✓] Manual tunnel created${NC}"
    echo "Local GRE: $GRE_LOCAL"
    echo "Remote GRE: $GRE_REMOTE"
}

# بررسی وضعیت تونل
check_status() {
    echo -e "${YELLOW}[*] Tunnel Status${NC}"
    echo "======================"
    
    # بررسی تونل‌ها
    echo "Active GRE tunnels:"
    ip tunnel show 2>/dev/null || echo "No tunnels found"
    
    echo ""
    echo "Interface details:"
    ip addr show | grep -A2 "gre\|tun" || echo "No tunnel interfaces"
    
    echo ""
    echo "IP forwarding status:"
    cat /proc/sys/net/ipv4/ip_forward
    
    echo ""
    echo "Routing table (relevant):"
    ip route | grep -E "gre|10\.10\.10\." || echo "No tunnel routes"
}

# حذف تونل‌ها
remove_tunnels() {
    echo -e "${RED}[*] Removing all tunnels...${NC}"
    
    # پیدا کردن و حذف تمام تونل‌های GRE
    for tun in $(ip link show | grep -o "gre[0-9]*\|tun[0-9]*" | sort -u); do
        echo "Removing tunnel: $tun"
        ip link del $tun 2>/dev/null || true
    done
    
    echo -e "${GREEN}[✓] All tunnels removed${NC}"
}

# تست اتصال
test_connection() {
    echo -e "${YELLOW}[*] Testing connection...${NC}"
    
    # تست تونل GRE
    if ip link show gre1 &>/dev/null; then
        echo "✓ GRE tunnel (gre1) exists"
        
        # دریافت IP تونل
        GRE_IP=$(ip addr show gre1 | grep -o "inet [0-9./]*" | cut -d' ' -f2)
        if [ -n "$GRE_IP" ]; then
            echo "✓ GRE IP: $GRE_IP"
            
            # مشخص کردن IP طرف مقابل
            if [[ $GRE_IP == *"10.10.10.1"* ]]; then
                REMOTE_GRE="10.10.10.2"
            else
                REMOTE_GRE="10.10.10.1"
            fi
            
            # تست ping
            echo "Testing ping to $REMOTE_GRE..."
            if ping -c 3 -W 2 $REMOTE_GRE &>/dev/null; then
                echo "✓ Connected to remote GRE"
            else
                echo "✗ Cannot reach remote GRE"
            fi
        fi
    else
        echo "✗ No GRE tunnel found"
    fi
    
    # تست IP forwarding
    echo ""
    echo "IP forwarding status: $(cat /proc/sys/net/ipv4/ip_forward)"
}

# پیکربندی iptables برای ایران
setup_iptables_iran() {
    # پیدا کردن اینترفیس اصلی
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # فوروارد پورت‌های مورد نیاز
    echo -e "${BLUE}[*] Setting up iptables forwarding...${NC}"
    
    # پاک‌سازی قوانین قدیمی (اختیاری)
    # iptables -F
    # iptables -t nat -F
    
    # فوروارد پورت‌ها به طرف خارج
    iptables -t nat -A PREROUTING -i $INTERFACE -p tcp --dport 443 -j DNAT --to-destination 10.10.10.2
    iptables -t nat -A PREROUTING -i $INTERFACE -p udp --dport 443 -j DNAT --to-destination 10.10.10.2
    iptables -t nat -A PREROUTING -i $INTERFACE -p tcp --dport 8443 -j DNAT --to-destination 10.10.10.2
    
    # MASQUERADE برای ترافیک خروجی از تونل
    iptables -t nat -A POSTROUTING -o gre1 -j MASQUERADE
    
    echo -e "${GREEN}[✓] iptables configured${NC}"
}

# اعتبارسنجی IP
validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${RED}Error: Invalid IP address format: $ip${NC}"
        exit 1
    fi
}

# پاک‌سازی تونل‌های قدیمی
clean_tunnels() {
    ip link del gre1 2>/dev/null || true
    ip link del gre0 2>/dev/null || true
}

# ============================================
# شروع اجرای اسکریپت
# ============================================

# بررسی دسترسی root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# منوی اصلی
while true; do
    show_menu
    read -p "Select option [1-7]: " choice
    
    case $choice in
        1)
            setup_iran
            ;;
        2)
            setup_kharej
            ;;
        3)
            setup_manual
            ;;
        4)
            check_status
            ;;
        5)
            remove_tunnels
            ;;
        6)
            test_connection
            ;;
        7)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
