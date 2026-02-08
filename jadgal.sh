#!/bin/bash
clear
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "\033[1;31mError:\033[0m This script must be run as root."
        exit 1
    fi
}
# Function to check and install GOST if missing
check_and_install_gost() {
    if [[ ! -f /usr/local/bin/gost ]]; then
        echo -e "\033[1;31m? GOST is not installed!\033[0m"
        install_gost3
    else
        echo -e "\033[1;32m✓ GOST is already installed.\033[0m"
    fi
}

# Check if GOST is installed and get its version
if command -v gost &> /dev/null; then
    gost_version=$(gost -V 2>&1)
else
    gost_version="GOST not installed"
fi

# Function to create a new GOST core binary
create_gost_core() {
    local core_name="$1"
    local gost_binary="/usr/local/bin/$core_name"
    
    # Check if original gost exists
    if [[ ! -f "/usr/local/bin/gost" ]]; then
        echo -e "\033[1;31m✗ Original GOST binary not found. Please install GOST first.\033[0m"
        return 1
    fi
    
    # Check if core already exists
    if [[ -f "$gost_binary" ]]; then
        echo -e "\033[1;33m⚠ Using existing GOST core: $core_name\033[0m"
        return 0
    fi
    
    # Copy the original gost binary
    echo -e "\033[1;32mCreating new GOST core: $core_name\033[0m"
    if cp /usr/local/bin/gost "$gost_binary"; then
        chmod +x "$gost_binary"
        echo -e "\033[1;32m✓ Successfully created GOST core: $core_name\033[0m"
        return 0
    else
        echo -e "\033[1;31m✗ Failed to create GOST core. Using original.\033[0m"
        return 1
    fi
}

# Function to list all GOST cores
list_gost_cores() {
    echo -e "\033[1;34m📋 List of GOST Cores:\033[0m"
    echo -e "\033[1;33mAvailable cores in /usr/local/bin:\033[0m"
    ls -la /usr/local/bin/gost* 2>/dev/null | grep -v "\.bak" || echo "No GOST cores found"
}

# Main Menu Function
main_menu() {
    while true; do
        clear
        echo -e "\033[1;32mTransmission:\033[0m ICMP Tunnel (Ping Tunnel)"
        echo -e "\033[1;32mTip:\033[0m You can create infinite tunnels"
        echo -e "\033[1;32mgost version:\033[0m ${gost_version}"
        echo -e "\033[1;32m===================================\033[0m"
        echo -e "          \033[1;36mReverse GOST - ICMP Only\033[0m"
        echo -e "\033[1;32m===================================\033[0m"
        echo -e " \033[1;34m1.\033[0m Install GOST"
        echo -e " \033[1;34m2.\033[0m relay mode (multi-port) "
        echo -e " \033[1;34m3.\033[0m socks5 mode (multi-port) "
        echo -e " \033[1;34m4.\033[0m Manage Tunnels Services"
        echo -e " \033[1;34m5.\033[0m List GOST Cores"
        echo -e " \033[1;34m6.\033[0m Remove GOST"
        
        echo -e " \033[1;31m0. Exit\033[0m"
        echo -e "\033[1;32m===================================\033[0m"

        read -p "Please select an option: " option

        case $option in
            1) install_gost3 ;;
            2) configure_relay ;;
            3) configure_socks5 ;;
            4) select_service_to_manage ;;
            5) list_gost_cores; read -p "Press Enter to continue..." ;;
            6) remove_gost ;;
            
            0) 
                echo -e "\033[1;31mExiting... Goodbye!\033[0m"
                exit 0
                ;;
            *) 
                echo -e "\033[1;31mInvalid option! Please try again.\033[0m"
                sleep 1
                ;;
        esac
    done
}

configure_relay() {
    echo -e "\033[1;33mIs this the client or server side?\033[0m"
    echo -e "\033[1;32m1.\033[0m \033[1;36mClient-Side (Iran)\033[0m"
    echo -e "\033[1;32m2.\033[0m \033[1;36mServer-Side (Kharej)\033[0m"
    read -p $'\033[1;33mEnter your choice [1-2]: \033[0m' side_choice

    case $side_choice in
        1)
            # Client-side configuration (Iran)
            echo -e "\n\033[1;34m Configure Client-Side (iran)\033[0m"

            # Ask for core name
            echo -e "\n\033[1;34m📝 Core Configuration:\033[0m"
            read -p $'\033[1;33mEnter a unique name for this GOST core (e.g., gost-relay1, gost-tunnel2): \033[0m' core_name
            if [[ -z "$core_name" ]]; then
                core_name="gost-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6)"
                echo -e "\033[1;36mGenerated core name: $core_name\033[0m"
            fi
            
            # Create GOST core
            if ! create_gost_core "$core_name"; then
                core_name="gost"  # Fallback to original
            fi
            
            GOST_BINARY="/usr/local/bin/$core_name"

            # Prompt the user for a port until a free one is provided
            while true; do
                read -p $'\033[1;33mEnter server communication port (default: 9001): \033[0m' lport_relay
                lport_relay=${lport_relay:-9001}
                break
            done
            
            # ICMP Transmission Type with advanced stealth options
            echo -e "\n\033[1;34mConfiguring ICMP Tunnel\033[0m"
            TRANSMISSION="+icmp"
            
            # Select Security Profile
            echo -e "\n\033[1;34m🔒 Select Security Profile:\033[0m"
            echo -e "\033[1;32m1.\033[0m Maximum Stealth (Recommended - Hardest to detect)"
            echo -e "\033[1;32m2.\033[0m High Speed + Stealth (Balanced)"
            echo -e "\033[1;32m3.\033[0m Ultra Security (Maximum obfuscation)"
            echo -e "\033[1;32m4.\033[0m Custom Settings"
            read -p $'\033[1;33mSelect profile (default: 1): \033[0m' profile_choice
            profile_choice=${profile_choice:-1}
            
            case $profile_choice in
                1)  # Maximum Stealth
                    echo -e "\033[1;32m✓ Selected: Maximum Stealth Profile\033[0m"
                    
                    # Advanced stealth with performance
                    ICMP_INTERVAL="random,150ms-3000ms"
                    ICMP_SIZE="random,84-548"
                    ICMP_TTL="random,52-64"
                    ICMP_CIPHER="chacha20-poly1305"
                    ICMP_JITTER="&jitter=true&jitterMax=200ms"
                    ICMP_PADDING="&padding=true&paddingMin=48&paddingMax=192"
                    
                    # Performance without compromising security
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true&muxMaxStreams=50&muxBufferSize=32768"
                    OPTIMIZATION_PARAMS="&windowSize=65535&bufferSize=32768&noDelay=true"
                    
                    # Advanced obfuscation
                    OBFUSCATION_PARAMS="&trafficClass=0x00&dscp=0x00&mtu=576"
                    
                    # Behavioral mimicry
                    BEHAVIOR_PARAMS="&rate=random,50k-200k&burst=5"
                    ;;
                    
                2)  # High Speed + Stealth
                    echo -e "\033[1;32m✓ Selected: High Speed + Stealth Profile\033[0m"
                    
                    ICMP_INTERVAL="random,100ms-1500ms"
                    ICMP_SIZE="random,128-1024"
                    ICMP_TTL="random,55-65"
                    ICMP_CIPHER="aes-256-gcm"
                    ICMP_JITTER="&jitter=true&jitterMax=150ms"
                    ICMP_PADDING="&padding=true&paddingMin=32&paddingMax=128"
                    
                    # High performance settings
                    COMPRESS_OPTION="compress=true&compressionLevel=3"
                    MUX_OPTION="mux=true&muxMaxStreams=100&muxBufferSize=65536"
                    OPTIMIZATION_PARAMS="&windowSize=131072&bufferSize=65536&noDelay=true&fastOpen=true"
                    
                    OBFUSCATION_PARAMS="&trafficClass=0x10&dscp=0x28&mtu=1500"
                    BEHAVIOR_PARAMS="&rate=random,100k-500k&burst=10"
                    ;;
                    
                3)  # Ultra Security
                    echo -e "\033[1;32m✓ Selected: Ultra Security Profile\033[0m"
                    
                    # Extreme obfuscation
                    ICMP_INTERVAL="random,200ms-8000ms"
                    ICMP_SIZE="random,56-256"
                    ICMP_TTL="random,48-72"
                    ICMP_CIPHER="aes-256-gcm"
                    ICMP_JITTER="&jitter=true&jitterMax=500ms&jitterMin=50ms"
                    ICMP_PADDING="&padding=true&paddingMin=64&paddingMax=256&paddingRandom=true"
                    
                    # Stealth performance
                    COMPRESS_OPTION="compress=true&compressionLevel=1"
                    MUX_OPTION="mux=true&muxMaxStreams=30&muxBufferSize=16384"
                    OPTIMIZATION_PARAMS="&windowSize=32768&bufferSize=16384"
                    
                    # Advanced obfuscation techniques
                    OBFUSCATION_PARAMS="&trafficClass=0x00&dscp=0x00&mtu=576&fragment=true&fragmentSize=512"
                    
                    # Behavioral obfuscation
                    BEHAVIOR_PARAMS="&rate=random,20k-100k&burst=3&pattern=random"
                    
                    # Add random packet loss simulation
                    OBFUSCATION_PARAMS+="&loss=random,0.1-1.0"
                    ;;
                    
                4)  # Custom Settings
                    echo -e "\n\033[1;34m⚙️ Custom ICMP Settings:\033[0m"
                    
                    # Interval settings
                    echo -e "\033[1;36m1. Packet Interval Settings:\033[0m"
                    read -p $'\033[1;33mEnter min interval in ms (default: 150): \033[0m' interval_min
                    interval_min=${interval_min:-150}
                    read -p $'\033[1;33mEnter max interval in ms (default: 3000): \033[0m' interval_max
                    interval_max=${interval_max:-3000}
                    ICMP_INTERVAL="random,${interval_min}ms-${interval_max}ms"
                    
                    # Packet size settings
                    echo -e "\n\033[1;36m2. Packet Size Settings:\033[0m"
                    read -p $'\033[1;33mEnter min size in bytes (default: 84): \033[0m' size_min
                    size_min=${size_min:-84}
                    read -p $'\033[1;33mEnter max size in bytes (default: 548): \033[0m' size_max
                    size_max=${size_max:-548}
                    ICMP_SIZE="random,${size_min}-${size_max}"
                    
                    # TTL settings
                    echo -e "\n\033[1;36m3. TTL Settings:\033[0m"
                    read -p $'\033[1;33mEnter min TTL (default: 52): \033[0m' ttl_min
                    ttl_min=${ttl_min:-52}
                    read -p $'\033[1;33mEnter max TTL (default: 64): \033[0m' ttl_max
                    ttl_max=${ttl_max:-64}
                    ICMP_TTL="random,${ttl_min}-${ttl_max}"
                    
                    # Encryption settings
                    echo -e "\n\033[1;36m4. Encryption Settings:\033[0m"
                    echo -e "   \033[1;32m1.\033[0m ChaCha20-Poly1305 (Fast, Recommended)"
                    echo -e "   \033[1;32m2.\033[0m AES-256-GCM (Strong)"
                    echo -e "   \033[1;32m3.\033[0m No encryption"
                    read -p $'\033[1;33mSelect encryption type (default: 1): \033[0m' cipher_choice
                    cipher_choice=${cipher_choice:-1}
                    
                    case $cipher_choice in
                        1) ICMP_CIPHER="chacha20-poly1305" ;;
                        2) ICMP_CIPHER="aes-256-gcm" ;;
                        3) ICMP_CIPHER="" ;;
                        *) ICMP_CIPHER="chacha20-poly1305" ;;
                    esac
                    
                    # Jitter settings
                    echo -e "\n\033[1;36m5. Jitter Settings:\033[0m"
                    read -p $'\033[1;33mEnable jitter? [y/n] (default: y): \033[0m' jitter_enable
                    jitter_enable=${jitter_enable:-y}
                    if [[ "$jitter_enable" == "y" || "$jitter_enable" == "yes" ]]; then
                        read -p $'\033[1;33mEnter max jitter in ms (default: 200): \033[0m' jitter_max
                        jitter_max=${jitter_max:-200}
                        ICMP_JITTER="&jitter=true&jitterMax=${jitter_max}ms"
                    else
                        ICMP_JITTER=""
                    fi
                    
                    # Padding settings
                    echo -e "\n\033[1;36m6. Padding Settings:\033[0m"
                    read -p $'\033[1;33mEnable random padding? [y/n] (default: y): \033[0m' padding_enable
                    padding_enable=${padding_enable:-y}
                    if [[ "$padding_enable" == "y" || "$padding_enable" == "yes" ]]; then
                        read -p $'\033[1;33mEnter min padding size (default: 48): \033[0m' padding_min
                        padding_min=${padding_min:-48}
                        read -p $'\033[1;33mEnter max padding size (default: 192): \033[0m' padding_max
                        padding_max=${padding_max:-192}
                        ICMP_PADDING="&padding=true&paddingMin=${padding_min}&paddingMax=${padding_max}"
                    else
                        ICMP_PADDING=""
                    fi
                    
                    # Compression
                    echo -e "\n\033[1;36m7. Compression:\033[0m"
                    read -p $'\033[1;33mEnable compression? [y/n] (default: y): \033[0m' compress_enable
                    compress_enable=${compress_enable:-y}
                    if [[ "$compress_enable" == "y" || "$compress_enable" == "yes" ]]; then
                        COMPRESS_OPTION="compress=true"
                    else
                        COMPRESS_OPTION=""
                    fi
                    
                    # Multiplexing
                    echo -e "\n\033[1;36m8. Multiplexing:\033[0m"
                    read -p $'\033[1;33mEnable multiplexing? [y/n] (default: y): \033[0m' mux_enable
                    mux_enable=${mux_enable:-y}
                    if [[ "$mux_enable" == "y" || "$mux_enable" == "yes" ]]; then
                        MUX_OPTION="mux=true"
                    else
                        MUX_OPTION=""
                    fi
                    
                    OPTIMIZATION_PARAMS=""
                    OBFUSCATION_PARAMS=""
                    BEHAVIOR_PARAMS=""
                    ;;
            esac

            # Ask about connection stability
            echo -e "\n\033[1;34m🔧 Connection Stability Settings\033[0m"
            echo -e "Do you want to configure connection stability options?"
            echo -e "\033[1;32m1.\033[0m Yes - Configure advanced options"
            echo -e "\033[1;32m2.\033[0m No - Use default settings"
            read -p $'\033[1;33mEnter your choice (default: 2): \033[0m' stability_choice
            stability_choice=${stability_choice:-2}
            
            # Set default values
            TIMEOUT_VALUE="30s"
            RWTIMEOUT_VALUE="30s"
            RETRY_VALUE="3"
            HEARTBEAT_VALUE="30s"
            
            # If user wants advanced options
            if [[ "$stability_choice" == "1" ]]; then
                echo -e "\n\033[1;34m⚡ Advanced Stability Options\033[0m"
                
                # Connection Timeout
                read -p $'\033[1;33mEnter connection timeout in seconds (default: 30): \033[0m' custom_timeout
                custom_timeout=${custom_timeout:-30}
                TIMEOUT_VALUE="${custom_timeout}s"
                
                # Read/Write Timeout
                read -p $'\033[1;33mEnter read/write timeout in seconds (default: 30): \033[0m' custom_rwtimeout
                custom_rwtimeout=${custom_rwtimeout:-30}
                RWTIMEOUT_VALUE="${custom_rwtimeout}s"
                
                # Retry attempts
                echo -e "\n\033[1;34mRetry Attempts:\033[0m"
                echo -e "\033[1;32m1.\033[0m 0 (No retry)"
                echo -e "\033[1;32m2.\033[0m 3 (Default)"
                echo -e "\033[1;32m3.\033[0m 5 (High retry)"
                echo -e "\033[1;32m4.\033[0m -1 (Infinite retry)"
                read -p $'\033[1;33mEnter your choice [1-4] (default: 2): \033[0m' retry_choice
                retry_choice=${retry_choice:-2}
                
                case $retry_choice in
                    1) RETRY_VALUE="0" ;;
                    2) RETRY_VALUE="3" ;;
                    3) RETRY_VALUE="5" ;;
                    4) RETRY_VALUE="-1" ;;
                    *) RETRY_VALUE="3" ;;
                esac
                
                # Heartbeat interval
                read -p $'\033[1;33mEnter heartbeat interval in seconds (default: 30): \033[0m' custom_heartbeat
                custom_heartbeat=${custom_heartbeat:-30}
                HEARTBEAT_VALUE="${custom_heartbeat}s"
                
                echo -e "\n\033[1;32m✅ Stability Settings:\033[0m"
                echo -e "   • Timeout: $TIMEOUT_VALUE"
                echo -e "   • Read/Write Timeout: $RWTIMEOUT_VALUE"
                echo -e "   • Retries: $RETRY_VALUE"
                echo -e "   • Heartbeat: $HEARTBEAT_VALUE"
            fi

            # Ask about multi-path tunneling (increases speed and stealth)
            echo -e "\n\033[1;34m🛤️ Multi-Path Tunneling:\033[0m"
            echo -e "Create multiple parallel tunnels for increased speed and stealth?"
            echo -e "\033[1;32m1.\033[0m Single tunnel (Default)"
            echo -e "\033[1;32m2.\033[0m Dual tunnel (2 parallel connections)"
            echo -e "\033[1;32m3.\033[0m Quad tunnel (4 parallel connections)"
            read -p $'\033[1;33mSelect number of tunnels (default: 1): \033[0m' tunnel_choice
            tunnel_choice=${tunnel_choice:-1}
            
            # Build GOST options with ICMP stealth parameters
            GOST_OPTIONS="-L relay${TRANSMISSION}://:${lport_relay}?bind=true"
            
            # Add stability options
            GOST_OPTIONS+="&timeout=${TIMEOUT_VALUE}"
            GOST_OPTIONS+="&rwTimeout=${RWTIMEOUT_VALUE}"
            GOST_OPTIONS+="&retries=${RETRY_VALUE}"
            GOST_OPTIONS+="&heartbeat=${HEARTBEAT_VALUE}"
            GOST_OPTIONS+="&keepAlive=true"
            
            # Add ICMP stealth parameters
            GOST_OPTIONS+="&interval=${ICMP_INTERVAL}"
            GOST_OPTIONS+="&size=${ICMP_SIZE}"
            GOST_OPTIONS+="&ttl=${ICMP_TTL}"
            
            # Add encryption if enabled
            if [[ -n "$ICMP_CIPHER" ]]; then
                GOST_OPTIONS+="&cipher=${ICMP_CIPHER}"
            fi
            
            # Add jitter if enabled
            if [[ -n "$ICMP_JITTER" ]]; then
                GOST_OPTIONS+="$ICMP_JITTER"
            fi
            
            # Add padding if enabled
            if [[ -n "$ICMP_PADDING" ]]; then
                GOST_OPTIONS+="$ICMP_PADDING"
            fi
            
            # Add compression if enabled
            if [[ -n "$COMPRESS_OPTION" ]]; then
                GOST_OPTIONS+="&${COMPRESS_OPTION}"
            fi
            
            # Add multiplexing if enabled
            if [[ -n "$MUX_OPTION" ]]; then
                GOST_OPTIONS+="&${MUX_OPTION}"
            fi
            
            # Add optimization parameters
            if [[ -n "$OPTIMIZATION_PARAMS" ]]; then
                GOST_OPTIONS+="$OPTIMIZATION_PARAMS"
            fi
            
            # Add obfuscation parameters
            if [[ -n "$OBFUSCATION_PARAMS" ]]; then
                GOST_OPTIONS+="$OBFUSCATION_PARAMS"
            fi
            
            # Add behavioral parameters
            if [[ -n "$BEHAVIOR_PARAMS" ]]; then
                GOST_OPTIONS+="$BEHAVIOR_PARAMS"
            fi

            # Handle multi-path tunneling
            MULTI_TUNNEL_OPTIONS=""
            if [[ "$tunnel_choice" == "2" ]]; then
                # Create dual tunnel configuration
                SECOND_PORT=$((lport_relay + 1))
                MULTI_TUNNEL_OPTIONS=" -L relay${TRANSMISSION}://:${SECOND_PORT}?bind=true"
                MULTI_TUNNEL_OPTIONS+="&interval=random,${interval_min}ms-$((interval_max + 500))ms"
                MULTI_TUNNEL_OPTIONS+="&size=random,$((size_min - 20))-$((size_max + 20))"
                MULTI_TUNNEL_OPTIONS+="&ttl=random,$((ttl_min - 2))-$((ttl_max + 2))"
                MULTI_TUNNEL_OPTIONS+="${GOST_OPTIONS#*bind=true?}"
                
                echo -e "\033[1;32m✓ Dual tunnel created on ports $lport_relay and $SECOND_PORT\033[0m"
                
            elif [[ "$tunnel_choice" == "3" ]]; then
                # Create quad tunnel configuration
                for i in {0..3}; do
                    PORT=$((lport_relay + i))
                    if [[ $i -eq 0 ]]; then
                        MULTI_TUNNEL_OPTIONS="-L relay${TRANSMISSION}://:${PORT}?bind=true"
                    else
                        MULTI_TUNNEL_OPTIONS+=" -L relay${TRANSMISSION}://:${PORT}?bind=true"
                    fi
                    
                    # Vary parameters for each tunnel to avoid pattern detection
                    RAND_INTERVAL_MIN=$((150 + (RANDOM % 100)))
                    RAND_INTERVAL_MAX=$((2000 + (RANDOM % 2000)))
                    RAND_SIZE_MIN=$((64 + (RANDOM % 50)))
                    RAND_SIZE_MAX=$((512 + (RANDOM % 200)))
                    RAND_TTL_MIN=$((52 + (RANDOM % 10)))
                    RAND_TTL_MAX=$((64 + (RANDOM % 8)))
                    
                    MULTI_TUNNEL_OPTIONS+="&interval=random,${RAND_INTERVAL_MIN}ms-${RAND_INTERVAL_MAX}ms"
                    MULTI_TUNNEL_OPTIONS+="&size=random,${RAND_SIZE_MIN}-${RAND_SIZE_MAX}"
                    MULTI_TUNNEL_OPTIONS+="&ttl=random,${RAND_TTL_MIN}-${RAND_TTL_MAX}"
                    MULTI_TUNNEL_OPTIONS+="${GOST_OPTIONS#*bind=true?}"
                done
                
                echo -e "\033[1;32m✓ Quad tunnel created on ports $lport_relay to $((lport_relay + 3))\033[0m"
            fi

            # If multi-tunnel, use those options
            if [[ -n "$MULTI_TUNNEL_OPTIONS" ]]; then
                GOST_OPTIONS="$MULTI_TUNNEL_OPTIONS"
            fi

            echo -e "\n\033[1;32m✅ ICMP Tunnel Configuration:\033[0m"
            echo -e "   • Transmission: ICMP with advanced stealth"
            echo -e "   • Interval: ${ICMP_INTERVAL}"
            echo -e "   • Packet Size: ${ICMP_SIZE}"
            echo -e "   • TTL: ${ICMP_TTL}"
            echo -e "   • Encryption: ${ICMP_CIPHER:-AES-256-GCM}"
            echo -e "   • Tunnels: $tunnel_choice parallel connection(s)"
            echo -e "   • Port: ${lport_relay}"
            if [[ "$tunnel_choice" -gt 1 ]]; then
                echo -e "   • Additional Ports: $((lport_relay + 1)) to $((lport_relay + tunnel_choice - 1))"
            fi
            echo -e "\n\033[1;32mGenerated GOST options:\033[0m $GOST_OPTIONS"
            echo -e "\033[1;32mUsing GOST core:\033[0m $core_name"

            read -p "Enter a custom name for this service (leave blank for a random name): " service_name
            [[ -z "$service_name" ]] && service_name="relay_client_$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 6)"

            echo -e "\033[1;32mCreating Gost service for ${service_name}...\033[0m"
            create_gost_service "$service_name" "$GOST_BINARY"
            start_service "$service_name"
            read -p "Press Enter to continue..."
            ;;
        
        2)
            echo -e "\n\033[1;34mConfigure Server-Side (kharej)\033[0m"

            # Ask for core name
            echo -e "\n\033[1;34m📝 Core Configuration:\033[0m"
            read -p $'\033[1;33mEnter a unique name for this GOST core (e.g., gost-relay1, gost-tunnel2): \033[0m' core_name
            if [[ -z "$core_name" ]]; then
                core_name="gost-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6)"
                echo -e "\033[1;36mGenerated core name: $core_name\033[0m"
            fi
            
            # Create GOST core
            if ! create_gost_core "$core_name"; then
                core_name="gost"  # Fallback to original
            fi
            
            GOST_BINARY="/usr/local/bin/$core_name"

            # Select listen type (TCP/UDP)
            echo -e "\n\033[1;34mSelect Listen Type:\033[0m"
            echo -e "\033[1;32m1.\033[0m \033[1;36mTCP mode\033[0m"
            echo -e "\033[1;32m2.\033[0m \033[1;36mUDP mode\033[0m"
            read -p $'\033[1;33mEnter listen transmission type: \033[0m' listen_choice

            case $listen_choice in
                1) LISTEN_TRANSMISSION="rtcp" ;;
                2) LISTEN_TRANSMISSION="rudp" ;;
                *) echo -e "\033[1;31mInvalid choice! Defaulting to TCP.\033[0m"; LISTEN_TRANSMISSION="tcp" ;;
            esac

            # Inbound port input
            while true; do
                read -p $'\033[1;33mEnter inbound (config) port: \033[0m' config_port
                if [[ "$config_port" =~ ^[0-9]+$ ]]; then
                    break
                else
                    echo -e "\033[1;31mInvalid port: $config_port. Please enter a valid numeric port.\033[0m"
                fi
            done

            # Listen port input
            while true; do
                read -p $'\033[1;33mEnter listen port: \033[0m' listen_port
                if [[ "$listen_port" =~ ^[0-9]+$ ]]; then
                    break
                else
                    echo -e "\033[1;31mInvalid port: $listen_port. Please enter a valid numeric port.\033[0m"
                fi
            done

            echo -e "\033[1;32mInbound (config) port set to: $config_port\033[0m"
            echo -e "\033[1;32mListen port set to: $listen_port\033[0m"

            # Remote server IP
            read -p $'\033[1;33mEnter remote server IP (iran): \033[0m' relay_ip
            [[ $relay_ip =~ : ]] && relay_ip="[$relay_ip]"
            echo -e "\033[1;36mFormatted IP:\033[0m $relay_ip"

            # Remote server port
            while true; do
                read -p $'\033[1;33mEnter server communication port (default: 9001): \033[0m' relay_port
                relay_port=${relay_port:-9001}
                if [[ "$relay_port" =~ ^[0-9]+$ ]]; then
                    break
                else
                    echo -e "\033[1;31mInvalid port. Please enter a valid numeric port.\033[0m"
                fi
            done

            # ICMP Transmission Type
            echo -e "\n\033[1;34mConfiguring ICMP Tunnel\033[0m"
            TRANSMISSION="+icmp"
            
            # Select Security Profile for server side
            echo -e "\n\033[1;34m🔒 Select Security Profile:\033[0m"
            echo -e "\033[1;32m1.\033[0m Maximum Stealth (Recommended)"
            echo -e "\033[1;32m2.\033[0m High Speed + Stealth"
            echo -e "\033[1;32m3.\033[0m Ultra Security"
            echo -e "\033[1;32m4.\033[0m Custom Settings"
            read -p $'\033[1;33mSelect profile (default: 1): \033[0m' profile_choice
            profile_choice=${profile_choice:-1}
            
            case $profile_choice in
                1)  # Maximum Stealth
                    ICMP_INTERVAL="random,150ms-3000ms"
                    ICMP_SIZE="random,84-548"
                    ICMP_TTL="random,52-64"
                    ICMP_CIPHER="chacha20-poly1305"
                    ICMP_JITTER="&jitter=true&jitterMax=200ms"
                    ICMP_PADDING="&padding=true&paddingMin=48&paddingMax=192"
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true"
                    OPTIMIZATION_PARAMS="&windowSize=65535&bufferSize=32768"
                    ;;
                    
                2)  # High Speed + Stealth
                    ICMP_INTERVAL="random,100ms-1500ms"
                    ICMP_SIZE="random,128-1024"
                    ICMP_TTL="random,55-65"
                    ICMP_CIPHER="aes-256-gcm"
                    ICMP_JITTER="&jitter=true&jitterMax=150ms"
                    ICMP_PADDING="&padding=true&paddingMin=32&paddingMax=128"
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true"
                    OPTIMIZATION_PARAMS="&windowSize=131072&bufferSize=65536"
                    ;;
                    
                3)  # Ultra Security
                    ICMP_INTERVAL="random,200ms-8000ms"
                    ICMP_SIZE="random,56-256"
                    ICMP_TTL="random,48-72"
                    ICMP_CIPHER="aes-256-gcm"
                    ICMP_JITTER="&jitter=true&jitterMax=500ms"
                    ICMP_PADDING="&padding=true&paddingMin=64&paddingMax=256"
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true"
                    OPTIMIZATION_PARAMS="&windowSize=32768&bufferSize=16384"
                    ;;
                    
                4)  # Custom Settings
                    echo -e "\n\033[1;34m⚙️ Custom ICMP Settings:\033[0m"
                    
                    # Interval settings
                    read -p $'\033[1;33mEnter min interval in ms (default: 150): \033[0m' interval_min
                    interval_min=${interval_min:-150}
                    read -p $'\033[1;33mEnter max interval in ms (default: 3000): \033[0m' interval_max
                    interval_max=${interval_max:-3000}
                    ICMP_INTERVAL="random,${interval_min}ms-${interval_max}ms"
                    
                    # Packet size settings
                    read -p $'\033[1;33mEnter min size in bytes (default: 84): \033[0m' size_min
                    size_min=${size_min:-84}
                    read -p $'\033[1;33mEnter max size in bytes (default: 548): \033[0m' size_max
                    size_max=${size_max:-548}
                    ICMP_SIZE="random,${size_min}-${size_max}"
                    
                    # TTL settings
                    read -p $'\033[1;33mEnter min TTL (default: 52): \033[0m' ttl_min
                    ttl_min=${ttl_min:-52}
                    read -p $'\033[1;33mEnter max TTL (default: 64): \033[0m' ttl_max
                    ttl_max=${ttl_max:-64}
                    ICMP_TTL="random,${ttl_min}-${ttl_max}"
                    
                    # Encryption
                    read -p $'\033[1;33mEnable encryption? [y/n] (default: y): \033[0m' encrypt_enable
                    encrypt_enable=${encrypt_enable:-y}
                    if [[ "$encrypt_enable" == "y" || "$encrypt_enable" == "yes" ]]; then
                        ICMP_CIPHER="chacha20-poly1305"
                    else
                        ICMP_CIPHER=""
                    fi
                    
                    ICMP_JITTER=""
                    ICMP_PADDING=""
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true"
                    OPTIMIZATION_PARAMS=""
                    ;;
            esac

            # Ask about connection stability for server side
            echo -e "\n\033[1;34m🔧 Connection Stability Settings\033[0m"
            echo -e "Do you want to configure connection stability options?"
            echo -e "\033[1;32m1.\033[0m Yes - Configure advanced options"
            echo -e "\033[1;32m2.\033[0m No - Use default settings"
            read -p $'\033[1;33mEnter your choice (default: 2): \033[0m' stability_choice
            stability_choice=${stability_choice:-2}
            
            # Set default values
            TIMEOUT_VALUE="30s"
            RWTIMEOUT_VALUE="30s"
            RETRY_VALUE="3"
            HEARTBEAT_VALUE="30s"
            
            # If user wants advanced options
            if [[ "$stability_choice" == "1" ]]; then
                echo -e "\n\033[1;34m⚡ Advanced Stability Options\033[0m"
                
                # Connection Timeout
                read -p $'\033[1;33mEnter connection timeout in seconds (default: 30): \033[0m' custom_timeout
                custom_timeout=${custom_timeout:-30}
                TIMEOUT_VALUE="${custom_timeout}s"
                
                # Read/Write Timeout
                read -p $'\033[1;33mEnter read/write timeout in seconds (default: 30): \033[0m' custom_rwtimeout
                custom_rwtimeout=${custom_rwtimeout:-30}
                RWTIMEOUT_VALUE="${custom_rwtimeout}s"
                
                # Retry attempts
                echo -e "\n\033[1;34mRetry Attempts:\033[0m"
                echo -e "\033[1;32m1.\033[0m 0 (No retry)"
                echo -e "\033[1;32m2.\033[0m 3 (Default)"
                echo -e "\033[1;32m3.\033[0m 5 (High retry)"
                echo -e "\033[1;32m4.\033[0m -1 (Infinite retry)"
                read -p $'\033[1;33mEnter your choice [1-4] (default: 2): \033[0m' retry_choice
                retry_choice=${retry_choice:-2}
                
                case $retry_choice in
                    1) RETRY_VALUE="0" ;;
                    2) RETRY_VALUE="3" ;;
                    3) RETRY_VALUE="5" ;;
                    4) RETRY_VALUE="-1" ;;
                    *) RETRY_VALUE="3" ;;
                esac
                
                # Heartbeat interval
                read -p $'\033[1;33mEnter heartbeat interval in seconds (default: 30): \033[0m' custom_heartbeat
                custom_heartbeat=${custom_heartbeat:-30}
                HEARTBEAT_VALUE="${custom_heartbeat}s"
            fi

            # Ask about compression for relay side
            echo -e "\n\033[1;34mEnable Compression for relay?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for better performance)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' compress_choice
            compress_choice=${compress_choice:-1}
            
            # Ask about multiplexing for relay side
            echo -e "\n\033[1;34mEnable Multiplexing (mux) for relay?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for multiple connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' mux_choice
            mux_choice=${mux_choice:-1}

            # Construct GOST options for listen side (first -L)
            LISTEN_OPTIONS="${LISTEN_TRANSMISSION}://:${listen_port}/127.0.0.1:${config_port}"
            
            # Construct GOST options for forward side (second -F)
            FORWARD_OPTIONS="relay${TRANSMISSION}://${relay_ip}:${relay_port}"
            
            # Build parameters for forward side with ICMP stealth
            FORWARD_PARAMS="interval=${ICMP_INTERVAL}"
            FORWARD_PARAMS+="&size=${ICMP_SIZE}"
            FORWARD_PARAMS+="&ttl=${ICMP_TTL}"
            
            # Add encryption if enabled
            if [[ -n "$ICMP_CIPHER" ]]; then
                FORWARD_PARAMS+="&cipher=${ICMP_CIPHER}"
            fi
            
            # Add jitter if enabled
            if [[ -n "$ICMP_JITTER" ]]; then
                FORWARD_PARAMS+="$ICMP_JITTER"
            fi
            
            # Add padding if enabled
            if [[ -n "$ICMP_PADDING" ]]; then
                FORWARD_PARAMS+="$ICMP_PADDING"
            fi
            
            # Add compression if enabled
            if [[ "$compress_choice" == "1" ]]; then
                FORWARD_PARAMS+="&compress=true"
            fi
            
            # Add multiplexing if enabled
            if [[ "$mux_choice" == "1" ]]; then
                FORWARD_PARAMS+="&mux=true"
            fi
            
            # Add optimization parameters
            if [[ -n "$OPTIMIZATION_PARAMS" ]]; then
                FORWARD_PARAMS+="$OPTIMIZATION_PARAMS"
            fi
            
            # Add stability options to forward side
            FORWARD_PARAMS+="&timeout=${TIMEOUT_VALUE}"
            FORWARD_PARAMS+="&rwTimeout=${RWTIMEOUT_VALUE}"
            FORWARD_PARAMS+="&retries=${RETRY_VALUE}"
            FORWARD_PARAMS+="&heartbeat=${HEARTBEAT_VALUE}"
            
            # Combine all options
            GOST_OPTIONS="-L $LISTEN_OPTIONS -F $FORWARD_OPTIONS?$FORWARD_PARAMS"

            echo -e "\n\033[1;32m✅ ICMP Tunnel Configuration:\033[0m"
            echo -e "   • Transmission: ICMP with stealth mode"
            echo -e "   • Interval: ${ICMP_INTERVAL}"
            echo -e "   • Packet Size: ${ICMP_SIZE}"
            echo -e "   • TTL: ${ICMP_TTL}"
            echo -e "   • Encryption: ${ICMP_CIPHER:-AES-256-GCM}"
            echo -e "   • Listen Port: ${listen_port}"
            echo -e "   • Config Port: ${config_port}"
            echo -e "\n\033[1;32mGenerated GOST options:\033[0m $GOST_OPTIONS"
            echo -e "\033[1;32mUsing GOST core:\033[0m $core_name"

            read -p "Enter a custom name for this service (leave blank for a random name): " service_name
            [[ -z "$service_name" ]] && service_name="relay_server_$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 6)"

            echo -e "\033[1;32mCreating Gost service for ${service_name}...\033[0m"
            create_gost_service "$service_name" "$GOST_BINARY"
            start_service "$service_name"

            read -p "Press Enter to continue..."
            ;;
        *)
            echo -e "\033[1;31mInvalid choice! Exiting.\033[0m"
            ;;
    esac
}

configure_socks5() {
    echo -e "\033[1;33mIs this the client or server side?\033[0m"
    echo -e "\033[1;32m1.\033[0m \033[1;36mClient-Side (Iran)\033[0m"
    echo -e "\033[1;32m2.\033[0m \033[1;36mServer-Side (Kharej)\033[0m"
    read -p $'\033[1;33mEnter your choice: \033[0m' side_choice

    case $side_choice in
        1)
            # Client-side configuration (Iran)
            echo -e "\n\033[1;34m Configure Client-Side (iran)\033[0m"

            # Ask for core name
            echo -e "\n\033[1;34m📝 Core Configuration:\033[0m"
            read -p $'\033[1;33mEnter a unique name for this GOST core (e.g., gost-socks5-1, gost-socks5-2): \033[0m' core_name
            if [[ -z "$core_name" ]]; then
                core_name="gost-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6)"
                echo -e "\033[1;36mGenerated core name: $core_name\033[0m"
            fi
            
            # Create GOST core
            if ! create_gost_core "$core_name"; then
                core_name="gost"  # Fallback to original
            fi
            
            GOST_BINARY="/usr/local/bin/$core_name"

            # Prompt the user for a port
            while true; do
                read -p $'\033[1;33mEnter server communication port (default: 9001): \033[0m' lport_socks5
                lport_socks5=${lport_socks5:-9001}
                break
            done
            
            # ICMP Transmission Type
            echo -e "\n\033[1;34mConfiguring ICMP Tunnel\033[0m"
            TRANSMISSION="+icmp"
            
            # Select Security Profile for socks5
            echo -e "\n\033[1;34m🔒 Select Security Profile:\033[0m"
            echo -e "\033[1;32m1.\033[0m Maximum Stealth (Recommended)"
            echo -e "\033[1;32m2.\033[0m High Speed + Stealth"
            echo -e "\033[1;32m3.\033[0m Ultra Security"
            echo -e "\033[1;32m4.\033[0m Custom Settings"
            read -p $'\033[1;33mSelect profile (default: 1): \033[0m' profile_choice
            profile_choice=${profile_choice:-1}
            
            case $profile_choice in
                1)  # Maximum Stealth
                    ICMP_INTERVAL="random,150ms-3000ms"
                    ICMP_SIZE="random,84-548"
                    ICMP_TTL="random,52-64"
                    ICMP_CIPHER="chacha20-poly1305"
                    ICMP_JITTER="&jitter=true&jitterMax=200ms"
                    ICMP_PADDING="&padding=true&paddingMin=48&paddingMax=192"
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true"
                    OPTIMIZATION_PARAMS="&windowSize=65535&bufferSize=32768"
                    ;;
                    
                2)  # High Speed + Stealth
                    ICMP_INTERVAL="random,100ms-1500ms"
                    ICMP_SIZE="random,128-1024"
                    ICMP_TTL="random,55-65"
                    ICMP_CIPHER="aes-256-gcm"
                    ICMP_JITTER="&jitter=true&jitterMax=150ms"
                    ICMP_PADDING="&padding=true&paddingMin=32&paddingMax=128"
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true"
                    OPTIMIZATION_PARAMS="&windowSize=131072&bufferSize=65536"
                    ;;
                    
                3)  # Ultra Security
                    ICMP_INTERVAL="random,200ms-8000ms"
                    ICMP_SIZE="random,56-256"
                    ICMP_TTL="random,48-72"
                    ICMP_CIPHER="aes-256-gcm"
                    ICMP_JITTER="&jitter=true&jitterMax=500ms"
                    ICMP_PADDING="&padding=true&paddingMin=64&paddingMax=256"
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true"
                    OPTIMIZATION_PARAMS="&windowSize=32768&bufferSize=16384"
                    ;;
                    
                4)  # Custom Settings
                    echo -e "\n\033[1;34m⚙️ Custom ICMP Settings:\033[0m"
                    
                    # Interval settings
                    read -p $'\033[1;33mEnter min interval in ms (default: 150): \033[0m' interval_min
                    interval_min=${interval_min:-150}
                    read -p $'\033[1;33mEnter max interval in ms (default: 3000): \033[0m' interval_max
                    interval_max=${interval_max:-3000}
                    ICMP_INTERVAL="random,${interval_min}ms-${interval_max}ms"
                    
                    # Packet size settings
                    read -p $'\033[1;33mEnter min size in bytes (default: 84): \033[0m' size_min
                    size_min=${size_min:-84}
                    read -p $'\033[1;33mEnter max size in bytes (default: 548): \033[0m' size_max
                    size_max=${size_max:-548}
                    ICMP_SIZE="random,${size_min}-${size_max}"
                    
                    # TTL settings
                    read -p $'\033[1;33mEnter min TTL (default: 52): \033[0m' ttl_min
                    ttl_min=${ttl_min:-52}
                    read -p $'\033[1;33mEnter max TTL (default: 64): \033[0m' ttl_max
                    ttl_max=${ttl_max:-64}
                    ICMP_TTL="random,${ttl_min}-${ttl_max}"
                    
                    # Encryption
                    read -p $'\033[1;33mEnable encryption? [y/n] (default: y): \033[0m' encrypt_enable
                    encrypt_enable=${encrypt_enable:-y}
                    if [[ "$encrypt_enable" == "y" || "$encrypt_enable" == "yes" ]]; then
                        ICMP_CIPHER="chacha20-poly1305"
                    else
                        ICMP_CIPHER=""
                    fi
                    
                    ICMP_JITTER=""
                    ICMP_PADDING=""
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true"
                    OPTIMIZATION_PARAMS=""
                    ;;
            esac

            # Ask about connection stability
            echo -e "\n\033[1;34m🔧 Connection Stability Settings\033[0m"
            echo -e "Do you want to configure connection stability options?"
            echo -e "\033[1;32m1.\033[0m Yes - Configure advanced options"
            echo -e "\033[1;32m2.\033[0m No - Use default settings"
            read -p $'\033[1;33mEnter your choice (default: 2): \033[0m' stability_choice
            stability_choice=${stability_choice:-2}
            
            # Set default values
            TIMEOUT_VALUE="30s"
            RWTIMEOUT_VALUE="30s"
            RETRY_VALUE="3"
            HEARTBEAT_VALUE="30s"
            
            # If user wants advanced options
            if [[ "$stability_choice" == "1" ]]; then
                echo -e "\n\033[1;34m⚡ Advanced Stability Options\033[0m"
                
                # Connection Timeout
                read -p $'\033[1;33mEnter connection timeout in seconds (default: 30): \033[0m' custom_timeout
                custom_timeout=${custom_timeout:-30}
                TIMEOUT_VALUE="${custom_timeout}s"
                
                # Read/Write Timeout
                read -p $'\033[1;33mEnter read/write timeout in seconds (default: 30): \033[0m' custom_rwtimeout
                custom_rwtimeout=${custom_rwtimeout:-30}
                RWTIMEOUT_VALUE="${custom_rwtimeout}s"
                
                # Retry attempts
                echo -e "\n\033[1;34mRetry Attempts:\033[0m"
                echo -e "\033[1;32m1.\033[0m 0 (No retry)"
                echo -e "\033[1;32m2.\033[0m 3 (Default)"
                echo -e "\033[1;32m3.\033[0m 5 (High retry)"
                echo -e "\033[1;32m4.\033[0m -1 (Infinite retry)"
                read -p $'\033[1;33mEnter your choice [1-4] (default: 2): \033[0m' retry_choice
                retry_choice=${retry_choice:-2}
                
                case $retry_choice in
                    1) RETRY_VALUE="0" ;;
                    2) RETRY_VALUE="3" ;;
                    3) RETRY_VALUE="5" ;;
                    4) RETRY_VALUE="-1" ;;
                    *) RETRY_VALUE="3" ;;
                esac
                
                # Heartbeat interval
                read -p $'\033[1;33mEnter heartbeat interval in seconds (default: 30): \033[0m' custom_heartbeat
                custom_heartbeat=${custom_heartbeat:-30}
                HEARTBEAT_VALUE="${custom_heartbeat}s"
            fi

            # Build GOST options with ICMP stealth parameters
            GOST_OPTIONS="-L socks5${TRANSMISSION}://:${lport_socks5}?bind=true"
            
            # Add stability options
            GOST_OPTIONS+="&timeout=${TIMEOUT_VALUE}"
            GOST_OPTIONS+="&rwTimeout=${RWTIMEOUT_VALUE}"
            GOST_OPTIONS+="&retries=${RETRY_VALUE}"
            GOST_OPTIONS+="&heartbeat=${HEARTBEAT_VALUE}"
            GOST_OPTIONS+="&keepAlive=true"
            
            # Add ICMP stealth parameters
            GOST_OPTIONS+="&interval=${ICMP_INTERVAL}"
            GOST_OPTIONS+="&size=${ICMP_SIZE}"
            GOST_OPTIONS+="&ttl=${ICMP_TTL}"
            
            # Add encryption if enabled
            if [[ -n "$ICMP_CIPHER" ]]; then
                GOST_OPTIONS+="&cipher=${ICMP_CIPHER}"
            fi
            
            # Add jitter if enabled
            if [[ -n "$ICMP_JITTER" ]]; then
                GOST_OPTIONS+="$ICMP_JITTER"
            fi
            
            # Add padding if enabled
            if [[ -n "$ICMP_PADDING" ]]; then
                GOST_OPTIONS+="$ICMP_PADDING"
            fi
            
            # Add compression if enabled
            if [[ -n "$COMPRESS_OPTION" ]]; then
                GOST_OPTIONS+="&${COMPRESS_OPTION}"
            fi
            
            # Add multiplexing if enabled
            if [[ -n "$MUX_OPTION" ]]; then
                GOST_OPTIONS+="&${MUX_OPTION}"
            fi
            
            # Add optimization parameters
            if [[ -n "$OPTIMIZATION_PARAMS" ]]; then
                GOST_OPTIONS+="$OPTIMIZATION_PARAMS"
            fi

            echo -e "\n\033[1;32m✅ ICMP Tunnel Configuration:\033[0m"
            echo -e "   • Transmission: ICMP with stealth mode"
            echo -e "   • Interval: ${ICMP_INTERVAL}"
            echo -e "   • Packet Size: ${ICMP_SIZE}"
            echo -e "   • TTL: ${ICMP_TTL}"
            echo -e "   • Encryption: ${ICMP_CIPHER:-AES-256-GCM}"
            echo -e "   • Port: ${lport_socks5}"
            echo -e "\n\033[1;32mGenerated GOST options:\033[0m $GOST_OPTIONS"
            echo -e "\033[1;32mUsing GOST core:\033[0m $core_name"

            read -p "Enter a custom name for this service (leave blank for a random name): " service_name
            [[ -z "$service_name" ]] && service_name="socks5_client_$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 6)"

            echo -e "\033[1;32mCreating Gost service for ${service_name}...\033[0m"
            create_gost_service "$service_name" "$GOST_BINARY"
            start_service "$service_name"
            read -p "Press Enter to continue..."
            ;;
        
        2)
            echo -e "\n\033[1;34mConfigure Server-Side (kharej)\033[0m"

            # Ask for core name
            echo -e "\n\033[1;34m📝 Core Configuration:\033[0m"
            read -p $'\033[1;33mEnter a unique name for this GOST core (e.g., gost-socks5-1, gost-socks5-2): \033[0m' core_name
            if [[ -z "$core_name" ]]; then
                core_name="gost-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6)"
                echo -e "\033[1;36mGenerated core name: $core_name\033[0m"
            fi
            
            # Create GOST core
            if ! create_gost_core "$core_name"; then
                core_name="gost"  # Fallback to original
            fi
            
            GOST_BINARY="/usr/local/bin/$core_name"

            # Select Listen Type (TCP/UDP)
            echo -e "\n\033[1;34mSelect Listen Type:\033[0m"
            echo -e "\033[1;32m1.\033[0m \033[1;36mTCP mode\033[0m"
            echo -e "\033[1;32m2.\033[0m \033[1;36mUDP mode\033[0m"
            read -p $'\033[1;33mEnter listen transmission type: \033[0m' listen_choice

            case $listen_choice in
                1) LISTEN_TRANSMISSION="rtcp" ;;
                2) LISTEN_TRANSMISSION="rudp" ;;
                *) echo -e "\033[1;31mInvalid choice! Defaulting to TCP.\033[0m"; LISTEN_TRANSMISSION="tcp" ;;
            esac

            # Inbound port input
            while true; do
                read -p $'\033[1;33mEnter inbound (config) port: \033[0m' config_port
                if [[ "$config_port" =~ ^[0-9]+$ ]]; then
                    break
                else
                    echo -e "\033[1;31mInvalid port. Please enter a numeric value.\033[0m"
                fi
            done

            # Listen port input
            while true; do
                read -p $'\033[1;33mEnter listen port: \033[0m' listen_port
                if [[ "$listen_port" =~ ^[0-9]+$ ]]; then
                    break
                else
                    echo -e "\033[1;31mInvalid port. Please enter a numeric value.\033[0m"
                fi
            done

            echo -e "\033[1;32mInbound (config) port set to: $config_port\033[0m"
            echo -e "\033[1;32mListen port set to: $listen_port\033[0m"

            # Remote server IP input
            read -p $'\033[1;33mEnter remote server IP (iran): \033[0m' socks5_ip
            [[ "$socks5_ip" =~ : ]] && socks5_ip="[$socks5_ip]"
            echo -e "\033[1;36mFormatted IP:\033[0m $socks5_ip"

            # Server communication port input
            while true; do
                read -p $'\033[1;33mEnter server communication port (default: 9001): \033[0m' socks5_port
                socks5_port=${socks5_port:-9001}
                break
            done

            # ICMP Transmission Type
            echo -e "\n\033[1;34mConfiguring ICMP Tunnel\033[0m"
            TRANSMISSION="+icmp"
            
            # Select Security Profile for socks5
            echo -e "\n\033[1;34m🔒 Select Security Profile:\033[0m"
            echo -e "\033[1;32m1.\033[0m Maximum Stealth (Recommended)"
            echo -e "\033[1;32m2.\033[0m High Speed + Stealth"
            echo -e "\033[1;32m3.\033[0m Ultra Security"
            echo -e "\033[1;32m4.\033[0m Custom Settings"
            read -p $'\033[1;33mSelect profile (default: 1): \033[0m' profile_choice
            profile_choice=${profile_choice:-1}
            
            case $profile_choice in
                1)  # Maximum Stealth
                    ICMP_INTERVAL="random,150ms-3000ms"
                    ICMP_SIZE="random,84-548"
                    ICMP_TTL="random,52-64"
                    ICMP_CIPHER="chacha20-poly1305"
                    ICMP_JITTER="&jitter=true&jitterMax=200ms"
                    ICMP_PADDING="&padding=true&paddingMin=48&paddingMax=192"
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true"
                    OPTIMIZATION_PARAMS="&windowSize=65535&bufferSize=32768"
                    ;;
                    
                2)  # High Speed + Stealth
                    ICMP_INTERVAL="random,100ms-1500ms"
                    ICMP_SIZE="random,128-1024"
                    ICMP_TTL="random,55-65"
                    ICMP_CIPHER="aes-256-gcm"
                    ICMP_JITTER="&jitter=true&jitterMax=150ms"
                    ICMP_PADDING="&padding=true&paddingMin=32&paddingMax=128"
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true"
                    OPTIMIZATION_PARAMS="&windowSize=131072&bufferSize=65536"
                    ;;
                    
                3)  # Ultra Security
                    ICMP_INTERVAL="random,200ms-8000ms"
                    ICMP_SIZE="random,56-256"
                    ICMP_TTL="random,48-72"
                    ICMP_CIPHER="aes-256-gcm"
                    ICMP_JITTER="&jitter=true&jitterMax=500ms"
                    ICMP_PADDING="&padding=true&paddingMin=64&paddingMax=256"
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true"
                    OPTIMIZATION_PARAMS="&windowSize=32768&bufferSize=16384"
                    ;;
                    
                4)  # Custom Settings
                    echo -e "\n\033[1;34m⚙️ Custom ICMP Settings:\033[0m"
                    
                    # Interval settings
                    read -p $'\033[1;33mEnter min interval in ms (default: 150): \033[0m' interval_min
                    interval_min=${interval_min:-150}
                    read -p $'\033[1;33mEnter max interval in ms (default: 3000): \033[0m' interval_max
                    interval_max=${interval_max:-3000}
                    ICMP_INTERVAL="random,${interval_min}ms-${interval_max}ms"
                    
                    # Packet size settings
                    read -p $'\033[1;33mEnter min size in bytes (default: 84): \033[0m' size_min
                    size_min=${size_min:-84}
                    read -p $'\033[1;33mEnter max size in bytes (default: 548): \033[0m' size_max
                    size_max=${size_max:-548}
                    ICMP_SIZE="random,${size_min}-${size_max}"
                    
                    # TTL settings
                    read -p $'\033[1;33mEnter min TTL (default: 52): \033[0m' ttl_min
                    ttl_min=${ttl_min:-52}
                    read -p $'\033[1;33mEnter max TTL (default: 64): \033[0m' ttl_max
                    ttl_max=${ttl_max:-64}
                    ICMP_TTL="random,${ttl_min}-${ttl_max}"
                    
                    # Encryption
                    read -p $'\033[1;33mEnable encryption? [y/n] (default: y): \033[0m' encrypt_enable
                    encrypt_enable=${encrypt_enable:-y}
                    if [[ "$encrypt_enable" == "y" || "$encrypt_enable" == "yes" ]]; then
                        ICMP_CIPHER="chacha20-poly1305"
                    else
                        ICMP_CIPHER=""
                    fi
                    
                    ICMP_JITTER=""
                    ICMP_PADDING=""
                    COMPRESS_OPTION="compress=true"
                    MUX_OPTION="mux=true"
                    OPTIMIZATION_PARAMS=""
                    ;;
            esac

            # Ask about connection stability for server side
            echo -e "\n\033[1;34m🔧 Connection Stability Settings\033[0m"
            echo -e "Do you want to configure connection stability options?"
            echo -e "\033[1;32m1.\033[0m Yes - Configure advanced options"
            echo -e "\033[1;32m2.\033[0m No - Use default settings"
            read -p $'\033[1;33mEnter your choice (default: 2): \033[0m' stability_choice
            stability_choice=${stability_choice:-2}
            
            # Set default values
            TIMEOUT_VALUE="30s"
            RWTIMEOUT_VALUE="30s"
            RETRY_VALUE="3"
            HEARTBEAT_VALUE="30s"
            
            # If user wants advanced options
            if [[ "$stability_choice" == "1" ]]; then
                echo -e "\n\033[1;34m⚡ Advanced Stability Options\033[0m"
                
                # Connection Timeout
                read -p $'\033[1;33mEnter connection timeout in seconds (default: 30): \033[0m' custom_timeout
                custom_timeout=${custom_timeout:-30}
                TIMEOUT_VALUE="${custom_timeout}s"
                
                # Read/Write Timeout
                read -p $'\033[1;33mEnter read/write timeout in seconds (default: 30): \033[0m' custom_rwtimeout
                custom_rwtimeout=${custom_rwtimeout:-30}
                RWTIMEOUT_VALUE="${custom_rwtimeout}s"
                
                # Retry attempts
                echo -e "\n\033[1;34mRetry Attempts:\033[0m"
                echo -e "\033[1;32m1.\033[0m 0 (No retry)"
                echo -e "\033[1;32m2.\033[0m 3 (Default)"
                echo -e "\033[1;32m3.\033[0m 5 (High retry)"
                echo -e "\033[1;32m4.\033[0m -1 (Infinite retry)"
                read -p $'\033[1;33mEnter your choice [1-4] (default: 2): \033[0m' retry_choice
                retry_choice=${retry_choice:-2}
                
                case $retry_choice in
                    1) RETRY_VALUE="0" ;;
                    2) RETRY_VALUE="3" ;;
                    3) RETRY_VALUE="5" ;;
                    4) RETRY_VALUE="-1" ;;
                    *) RETRY_VALUE="3" ;;
                esac
                
                # Heartbeat interval
                read -p $'\033[1;33mEnter heartbeat interval in seconds (default: 30): \033[0m' custom_heartbeat
                custom_heartbeat=${custom_heartbeat:-30}
                HEARTBEAT_VALUE="${custom_heartbeat}s"
            fi

            # Ask about compression for socks5 side
            echo -e "\n\033[1;34mEnable Compression for socks5?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for better performance)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' compress_choice
            compress_choice=${compress_choice:-1}
            
            # Ask about multiplexing for socks5 side
            echo -e "\n\033[1;34mEnable Multiplexing (mux) for socks5?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for multiple connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' mux_choice
            mux_choice=${mux_choice:-1}

            # Construct GOST options for listen side (first -L)
            LISTEN_OPTIONS="${LISTEN_TRANSMISSION}://:${listen_port}/127.0.0.1:${config_port}"
            
            # Construct GOST options for forward side (second -F)
            FORWARD_OPTIONS="socks5${TRANSMISSION}://${socks5_ip}:${socks5_port}"
            
            # Build parameters for forward side with ICMP stealth
            FORWARD_PARAMS="interval=${ICMP_INTERVAL}"
            FORWARD_PARAMS+="&size=${ICMP_SIZE}"
            FORWARD_PARAMS+="&ttl=${ICMP_TTL}"
            
            # Add encryption if enabled
            if [[ -n "$ICMP_CIPHER" ]]; then
                FORWARD_PARAMS+="&cipher=${ICMP_CIPHER}"
            fi
            
            # Add jitter if enabled
            if [[ -n "$ICMP_JITTER" ]]; then
                FORWARD_PARAMS+="$ICMP_JITTER"
            fi
            
            # Add padding if enabled
            if [[ -n "$ICMP_PADDING" ]]; then
                FORWARD_PARAMS+="$ICMP_PADDING"
            fi
            
            # Add stability parameters
            FORWARD_PARAMS+="&timeout=${TIMEOUT_VALUE}"
            FORWARD_PARAMS+="&rwTimeout=${RWTIMEOUT_VALUE}"
            FORWARD_PARAMS+="&retries=${RETRY_VALUE}"
            FORWARD_PARAMS+="&heartbeat=${HEARTBEAT_VALUE}"
            
            if [[ "$compress_choice" == "1" ]]; then
                FORWARD_PARAMS+="&compress=true"
            fi
            
            if [[ "$mux_choice" == "1" ]]; then
                FORWARD_PARAMS+="&mux=true"
            fi
            
            # Add optimization parameters
            if [[ -n "$OPTIMIZATION_PARAMS" ]]; then
                FORWARD_PARAMS+="$OPTIMIZATION_PARAMS"
            fi
            
            # Combine all options
            GOST_OPTIONS="-L $LISTEN_OPTIONS -F $FORWARD_OPTIONS?$FORWARD_PARAMS"

            echo -e "\n\033[1;32m✅ ICMP Tunnel Configuration:\033[0m"
            echo -e "   • Transmission: ICMP with stealth mode"
            echo -e "   • Interval: ${ICMP_INTERVAL}"
            echo -e "   • Packet Size: ${ICMP_SIZE}"
            echo -e "   • TTL: ${ICMP_TTL}"
            echo -e "   • Encryption: ${ICMP_CIPHER:-AES-256-GCM}"
            echo -e "   • Listen Port: ${listen_port}"
            echo -e "   • Config Port: ${config_port}"
            echo -e "\n\033[1;32mGenerated GOST options:\033[0m $GOST_OPTIONS"
            echo -e "\033[1;32mUsing GOST core:\033[0m $core_name"

            # Prompt for custom service name
            read -p "Enter a custom name for this service (leave blank for a random name): " service_name
            [[ -z "$service_name" ]] && service_name="socks5_server_$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 6)"

            echo -e "\033[1;32mCreating Gost service for ${service_name}...\033[0m"
            create_gost_service "$service_name" "$GOST_BINARY"
            start_service "$service_name"

            read -p "Press Enter to continue..."
            ;;
        
        *)
            echo -e "\033[1;31mInvalid choice! Exiting.\033[0m"
            ;;
    esac
}

# Function to check if a port is already in use
is_port_used() {
    local port=$1
    if sudo lsof -i :$port >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is not in use
    fi
}

# Function to create a service for Gost (port forwarding or relay mode)
create_gost_service() {
    local service_name=$1
    local gost_binary="${2:-/usr/local/bin/gost}"  # Use custom binary if provided, else default
    
    echo -e "\033[1;34mCreating Gost service for $service_name...\033[0m"
    echo -e "\033[1;36mUsing binary: $gost_binary\033[0m"

    # Create the systemd service file
    cat <<EOF > /etc/systemd/system/gost-${service_name}.service
[Unit]
Description=GOST ${service_name} Service
After=network.target

[Service]
Type=simple
ExecStart=$gost_binary ${GOST_OPTIONS}
Environment="GOST_LOGGER_LEVEL=fatal"
StandardOutput=null
StandardError=null
Restart=always
RestartSec=5
User=root
TasksMax=infinity
WorkingDirectory=/root
LimitNOFILE=1000000
LimitNPROC=10000
Nice=-20
CPUQuota=90%
LimitFSIZE=infinity
LimitCPU=infinity
LimitRSS=infinity
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to recognize the new service
    systemctl daemon-reload
    sleep 1
}

# Function to start the service
start_service() {
    local service_name=$1
    echo -e "\033[1;32mStarting $service_name service...\033[0m"
    systemctl start gost-${service_name}
    systemctl enable gost-${service_name}  # Ensure it starts on boot
    systemctl status gost-${service_name}
    sleep 1
}

# **Function to Select a Service to Manage**
select_service_to_manage() {
    # Get a list of all GOST service files in /etc/systemd/system/ directory
    gost_services=($(find /etc/systemd/system/ -maxdepth 1 -name 'gost*.service' | sed 's/\/etc\/systemd\/system\///'))

    if [ ${#gost_services[@]} -eq 0 ]; then
        echo -e "\033[1;31mNo GOST services found in /etc/systemd/system/!\033[0m"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "\033[1;34mSelect a GOST service to manage:\033[0m"
    select service_name in "${gost_services[@]}"; do
        if [[ -n "$service_name" ]]; then
            echo -e "\033[1;32mYou selected: $service_name\033[0m"
            # Call a function to manage the selected service's action (start, stop, etc.)
            manage_service_action "$service_name"
            break
        else
            echo -e "\033[1;31mInvalid selection. Please choose a valid service.\033[0m"
        fi
    done
}

# **Function to Perform Actions (start, stop, restart, etc.) on Selected Service**
manage_service_action() {
    local service_name=$1

    while true; do
        clear
        echo -e "\n\033[1;34m==============================\033[0m"
        echo -e "    \033[1;36mManage Service: $service_name\033[0m"
        echo -e "\033[1;34m==============================\033[0m"
        echo -e " \033[1;34m1.\033[0m Start the Service"
        echo -e " \033[1;34m2.\033[0m Stop the Service"
        echo -e " \033[1;34m3.\033[0m Restart the Service"
        echo -e " \033[1;34m4.\033[0m Check Service Status"
        echo -e " \033[1;34m5.\033[0m Remove the Service"
        echo -e " \033[1;34m6.\033[0m Edit the Service with nano"
        echo -e " \033[1;34m7.\033[0m Auto Restart Service (Cron)"
        echo -e " \033[1;34m8.\033[0m Rename the Service"
        echo -e " \033[1;31m0.\033[0m Return"
        echo -e "\033[1;34m==============================\033[0m"

        read -p "Please select an action: " action_option

        case $action_option in
            1)
                systemctl start "$service_name" && echo -e "\033[1;32mService $service_name started.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            2)
                systemctl stop "$service_name" && echo -e "\033[1;32mService $service_name stopped.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            3)
                systemctl restart "$service_name" && echo -e "\033[1;32mService $service_name restarted.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            4)
                systemctl status "$service_name"
                read -p "Press Enter to continue..."
                ;;
            5)
                systemctl stop "$service_name"
                systemctl disable "$service_name"
                rm "/etc/systemd/system/$service_name"
                systemctl daemon-reload
                echo -e "\033[1;32mService $service_name removed.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            6)
                service_file="/etc/systemd/system/$service_name"
            
                if [[ -f "$service_file" ]]; then
                    echo -e "\033[1;33mOpening $service_file for editing...\033[0m"
                    sleep 1
                    nano "$service_file"
                    systemctl daemon-reload
                    # Ask if the user wants to restart the service
                    read -p $'\033[1;33mDo you want to restart the service? [y/n] (default: y): \033[0m' restart_choice
                    restart_choice="${restart_choice:-y}"  # Default to "y" if empty
            
                    if [[ "$restart_choice" == "y" || "$restart_choice" == "yes" ]]; then
                        # Reload systemd and restart the service after editing
                        systemctl restart "$service_name"
                        echo -e "\033[1;32mService $service_name reloaded and restarted.\033[0m"
                    else
                        echo -e "\033[1;33mService $service_name was not restarted.\033[0m"
                    fi
                else
                    echo -e "\033[1;31mError: Service file not found!\033[0m"
                fi
            
                read -p "Press Enter to continue..."
                ;;
7)
    echo -e "\n\033[1;34mManage Service Cron Jobs:\033[0m"
    echo -e " \033[1;34m1.\033[0m Add/Update Cron Job"
    echo -e " \033[1;34m2.\033[0m Remove Cron Job"
    echo -e " \033[1;34m3.\033[0m Edit Cron Jobs with Nano"
    echo -e " \033[1;31m0.\033[0m Return"

    read -p "Select an option: " cron_option

    case $cron_option in
        1)
    echo -e "\n\033[1;34mChoose the restart interval type:\033[0m"
    echo -e " \033[1;34m1.\033[0m Every X minutes"
    echo -e " \033[1;34m2.\033[0m Every X hours"
    echo -e " \033[1;34m3.\033[0m Every X days"
    read -p "Select interval type (1-3): " interval_type

    case $interval_type in
        1)
            read -p "Enter the interval in minutes (1-59): " interval
            if [[ ! "$interval" =~ ^[1-9]$|^[1-5][0-9]$ ]]; then
                echo -e "\033[1;31mInvalid input! Please enter a number between 1 and 59.\033[0m"
                break
            fi
            cron_job="*/$interval * * * * /bin/systemctl restart $service_name"
            ;;
        2)
            read -p "Enter the interval in hours (1-23): " interval
            if [[ ! "$interval" =~ ^[1-9]$|^1[0-9]$|^2[0-3]$ ]]; then
                echo -e "\033[1;31mInvalid input! Please enter a number between 1 and 23.\033[0m"
                break
            fi
            cron_job="0 */$interval * * * /bin/systemctl restart $service_name"
            ;;
        3)
            read -p "Enter the interval in days (1-30): " interval
            if [[ ! "$interval" =~ ^[1-9]$|^[12][0-9]$|^30$ ]]; then
                echo -e "\033[1;31mInvalid input! Please enter a number between 1 and 30.\033[0m"
                break
            fi
            cron_job="0 0 */$interval * * /bin/systemctl restart $service_name"
            ;;
        *)
            echo -e "\033[1;31mInvalid option! Returning...\033[0m"
            break
            ;;
    esac

    # Remove any existing cron job for this service
    (crontab -l 2>/dev/null | grep -v "/bin/systemctl restart $service_name") | crontab -

    # Add the new cron job
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -

    echo -e "\033[1;32mCron job updated: Restart $service_name every $interval unit(s).\033[0m"
    ;;

        2)
            # Remove the cron job related to the service
            crontab -l 2>/dev/null | grep -v "/bin/systemctl restart $service_name" | crontab -
            echo -e "\033[1;32mCron job for $service_name removed.\033[0m"
            ;;
        3)
            echo -e "\033[1;33mOpening crontab for manual editing...\033[0m"
            sleep 1
            crontab -e
            ;;
        0)
            echo -e "\033[1;33mReturning to previous menu...\033[0m"
            ;;
        *)
            echo -e "\033[1;31mInvalid option! Please try again.\033[0m"
            sleep 2
            ;;
    esac
    read -p "Press Enter to continue..."
    ;;

            8)
                # Rename the Service feature
                echo -e "\n\033[1;34mRename Service:\033[0m"
                
                # Get current service information
                service_file="/etc/systemd/system/$service_name"
                
                if [[ ! -f "$service_file" ]]; then
                    echo -e "\033[1;31mError: Service file not found!\033[0m"
                    read -p "Press Enter to continue..."
                    continue
                fi
                
                # Show current name
                echo -e "Current service name: \033[1;36m$service_name\033[0m"
                
                # Ask for new name with validation
                while true; do
                    read -p $'\033[1;33mEnter new service name (must start with "gost-"): \033[0m' new_name
                    
                    # Validate the new name
                    if [[ -z "$new_name" ]]; then
                        echo -e "\033[1;31mService name cannot be empty!\033[0m"
                        continue
                    fi
                    
                    # Check if name starts with "gost-"
                    if [[ ! "$new_name" =~ ^gost- ]]; then
                        echo -e "\033[1;31mService name must start with 'gost-' prefix!\033[0m"
                        echo -e "Example: gost-de-aeza-4540.service"
                        continue
                    fi
                    
                    # Check if name contains .service extension
                    if [[ ! "$new_name" =~ \.service$ ]]; then
                        new_name="$new_name.service"
                    fi
                    
                    # Check if new name already exists
                    if [[ -f "/etc/systemd/system/$new_name" ]]; then
                        echo -e "\033[1;31mA service with name '$new_name' already exists!\033[0m"
                        continue
                    fi
                    
                    # Confirm the rename
                    echo -e "\n\033[1;33mRenaming:\033[0m"
                    echo -e "From: \033[1;31m$service_name\033[0m"
                    echo -e "To:   \033[1;32m$new_name\033[0m"
                    
                    read -p $'\033[1;33mAre you sure you want to rename? [y/n] (default: n): \033[0m' confirm_rename
                    confirm_rename="${confirm_rename:-n}"
                    
                    if [[ "$confirm_rename" != "y" && "$confirm_rename" != "yes" ]]; then
                        echo -e "\033[1;33mRename cancelled.\033[0m"
                        break
                    fi
                    
                    # Stop the service first
                    systemctl stop "$service_name" 2>/dev/null
                    
                    # Rename the service file
                    mv "$service_file" "/etc/systemd/system/$new_name"
                    
                    # Update service references in the file
                    sed -i "s/Description=Gost Service.*/Description=Gost Service - ${new_name%.service}/" "/etc/systemd/system/$new_name"
                    
                    # Reload systemd
                    systemctl daemon-reload
                    
                    # Disable old service and enable new one
                    systemctl disable "$service_name" 2>/dev/null
                    systemctl enable "$new_name" 2>/dev/null
                    
                    # Update any cron jobs
                    if crontab -l 2>/dev/null | grep -q "/bin/systemctl restart $service_name"; then
                        (crontab -l 2>/dev/null | sed "s|/bin/systemctl restart $service_name|/bin/systemctl restart $new_name|g") | crontab -
                    fi
                    
                    # Update the service_name variable for the current session
                    service_name="$new_name"
                    
                    echo -e "\n\033[1;32m✓ Service renamed successfully!\033[0m"
                    echo -e "\033[1;36mNew service name: $service_name\033[0m"
                    
                    # Ask if user wants to start the service
                    read -p $'\033[1;33mDo you want to start the renamed service? [y/n] (default: y): \033[0m' start_choice
                    start_choice="${start_choice:-y}"
                    
                    if [[ "$start_choice" == "y" || "$start_choice" == "yes" ]]; then
                        systemctl start "$service_name" && echo -e "\033[1;32mService $service_name started.\033[0m"
                    fi
                    
                    break
                done
                read -p "Press Enter to continue..."
                ;;

            0)
                break
                ;;
            *)
                echo -e "\033[1;31mInvalid option! Please try again.\033[0m"
                sleep 2
                ;;
        esac
    done
}
# Fetch the latest GOST releases from GitHub
fetch_gost_versions() {
    releases=$(curl -s https://api.github.com/repos/ginuerzh/gost/releases | jq -r '.[].tag_name' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$')
    if [[ -z "$releases" ]]; then
        echo -e "\033[1;31m? Error: Unable to fetch releases from GitHub!\033[0m"
        exit 1
    fi
    echo "$releases"
}
# Fetch the latest GOST releases from GitHub
fetch_gost_versions3() {
    releases=$(curl -s https://api.github.com/repos/go-gost/gost/releases | jq -r '.[].tag_name' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$')
    if [[ -z "$releases" ]]; then
        echo -e "\033[1;31m? Error: Unable to fetch releases from GitHub!\033[0m"
        exit 1
    fi
    echo "$releases"
}

install_gost() {
    check_root

    while true; do
        echo -e "\033[1;34mSelect which version of GOST to install:\033[0m"
        echo -e "1) GOST 2"
        echo -e "2) GOST 3"
        echo -e "0) Return to the main menu"
        read -p "Enter your choice: " choice

        case "$choice" in
            1) install_gost2; break ;;
            2) install_gost3; break ;;
            0) return ;;
            *) echo -e "\033[1;31mInvalid choice! Please select a valid option.\033[0m" ;;
        esac
    done
}


install_gost2() {
    check_root

    # Install dependencies
    echo "Installing wget and nano..."
    sudo apt install wget unzip nano lsof -y

    # Fetch and display versions
    versions=$(fetch_gost_versions)
    if [[ -z "$versions" ]]; then
        echo -e "\033[1;31m? No releases found! Exiting...\033[0m"
        exit 1
    fi

    # Display available versions
    echo -e "\n\033[1;34mAvailable GOST versions:\033[0m"
    select version in $versions; do
        if [[ -n "$version" ]]; then
            echo -e "\033[1;32mYou selected: $version\033[0m"
            break
        else
            echo -e "\033[1;31m? Invalid selection! Please select a valid version.\033[0m"
        fi
    done

    # Define the correct GOST binary URL format
    download_url="https://github.com/ginuerzh/gost/releases/download/$version/gost_${version//v/}_linux_amd64.tar.gz"

    # Check if the URL is valid by testing with curl
    echo "Checking URL: $download_url"
    if ! curl --head --silent --fail "$download_url" > /dev/null; then
        echo -e "\033[1;31m? The release URL does not exist! Please check the release version.\033[0m"
        exit 1
    fi

    # Download and install the selected GOST version
    echo "Downloading GOST $version..."
    if ! sudo wget -q "$download_url"; then
        echo -e "\033[1;31m? Failed to download GOST! Exiting...\033[0m"
        exit 1
    fi

    # Extract the downloaded file
    echo "Extracting GOST..."
    if ! sudo tar -xvzf "gost_${version//v/}_linux_amd64.tar.gz"; then
        echo -e "\033[1;31m? Failed to extract GOST! Exiting...\033[0m"
        exit 1
    fi

    # Move the binary to /usr/local/bin and make it executable
    echo "Installing GOST..."
    sudo mv gost /usr/local/bin/gost
    sudo chmod +x /usr/local/bin/gost

    # Verify the installation
    if [[ -f /usr/local/bin/gost ]]; then
        echo -e "\033[1;32mGOST $version installed successfully!\033[0m"
    else
        echo -e "\033[1;31mError: GOST installation failed!\033[0m"
        exit 1
    fi

    read -p "Press Enter to continue..."
}


install_gost3() {
    check_root

    # Install dependencies
    echo "Installing wget and nano..."
    sudo apt install wget unzip nano lsof -y

   repo="go-gost/gost"
base_url="https://api.github.com/repos/$repo/releases"

# Function to download and install gost
install_gost() {
    version=$1
    # Detect the operating system
    if [[ "$(uname)" == "Linux" ]]; then
        os="linux"
    elif [[ "$(uname)" == "Darwin" ]]; then
        os="darwin"
    elif [[ "$(uname)" == "MINGW"* ]]; then
        os="windows"
    else
        echo "Unsupported operating system."
        exit 1
    fi

    # Detect the CPU architecture
    arch=$(uname -m)
    case $arch in
    x86_64)
        cpu_arch="amd64"
        ;;
    armv5*)
        cpu_arch="armv5"
        ;;
    armv6*)
        cpu_arch="armv6"
        ;;
    armv7*)
        cpu_arch="armv7"
        ;;
    aarch64)
        cpu_arch="arm64"
        ;;
    i686)
        cpu_arch="386"
        ;;
    mips64*)
        cpu_arch="mips64"
        ;;
    mips*)
        cpu_arch="mips"
        ;;
    mipsel*)
        cpu_arch="mipsle"
        ;;
    *)
        echo "Unsupported CPU architecture."
        exit 1
        ;;
    esac
    get_download_url="$base_url/tags/$version"
    download_url=$(curl -s "$get_download_url" | grep -Eo "\"browser_download_url\": \".*${os}.*${cpu_arch}.*\"" | awk -F'["]' '{print $4}')

    # Download the binary
    echo "Downloading gost version $version..."
    curl -fsSL -o gost.tar.gz $download_url

    # Extract and install the binary
    echo "Installing gost..."
    tar -xzf gost.tar.gz
    chmod +x gost
    mv gost /usr/local/bin/gost

    echo "gost installation completed!"
}

# Retrieve available versions from GitHub API
versions=$(curl -s "$base_url" | grep -oP 'tag_name": "\K[^"]+')

# Check if --install option provided
if [[ "$1" == "--install" ]]; then
    # Install the latest version automatically
    latest_version=$(echo "$versions" | head -n 1)
    install_gost $latest_version
else
    # Display available versions to the user
    echo "Available gost versions:"
    select version in $versions; do
        if [[ -n $version ]]; then
            install_gost $version
            break
        else
            echo "Invalid choice! Please select a valid option."
        fi
    done
fi

    read -p "Press Enter to continue..."
}

# Remove GOST
remove_gost() {
    check_root
    echo -e "\033[1;31m⚠ Warning: This will remove ALL GOST binaries and services!\033[0m"
    read -p $'\033[1;33mAre you sure you want to remove GOST? [y/n] (default: n): \033[0m' confirm_remove
    confirm_remove="${confirm_remove:-n}"
    
    if [[ "$confirm_remove" != "y" && "$confirm_remove" != "yes" ]]; then
        echo -e "\033[1;33mGOST removal cancelled.\033[0m"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Remove all GOST binaries
    echo "Removing GOST binaries..."
    rm -f /usr/local/bin/gost*
    rm -f /usr/bin/gost*
    
    # Remove all GOST services
    echo "Removing GOST services..."
    for service_file in /etc/systemd/system/gost*.service; do
        if [[ -f "$service_file" ]]; then
            service_name=$(basename "$service_file")
            systemctl stop "$service_name" 2>/dev/null
            systemctl disable "$service_name" 2>/dev/null
            rm -f "$service_file"
        fi
    done
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "\033[1;32m✓ GOST and all related files removed successfully!\033[0m"
    read -p "Press Enter to continue..."
}

# Start the main menu
check_and_install_gost

main_menu
