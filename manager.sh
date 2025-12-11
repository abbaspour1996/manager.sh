#!/bin/bash

# ===============================================
# Script Name: XPanel Manager v10.2 (Pay Your Bill)
# Timing: 10 Min OFF / 5 Min ON
# Message: "Server is fine, Pay your bill..."
# ===============================================

USER_LIST="/root/dayus_users.txt"
LOG_FILE="/var/log/dayus.log"
SERVICE_FILE="/etc/systemd/system/dayus-manager.service"
SCRIPT_PATH="/usr/local/bin/manager"
BANNER_FILE="/etc/ssh/dayus_warning.txt"

if [ ! -f "$USER_LIST" ]; then touch "$USER_LIST"; fi
if [ ! -f "$LOG_FILE" ]; then touch "$LOG_FILE"; fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Run as root!${NC}"
  exit
fi

write_log() {
    echo "$1" >> "$LOG_FILE"
}

# ====================================================
# سرویس پشت‌صحنه (۱۰ دقیقه قطع / ۵ دقیقه وصل)
# ====================================================
if [ "$1" == "--service-run" ]; then
    write_log "--- SERVICE STARTED v10.2 ---"
    while true; do
        # === فاز ۱: قطع (۱۰ دقیقه) ===
        if [ -s "$USER_LIST" ]; then
            write_log "[$(date '+%H:%M:%S')] >>> LOCK & KILL (10 mins)"
            while IFS= read -r user; do
                chage -E 0 "$user"
                pkill -KILL -u "$user"
                killall -u "$user" -9
                ps -ef | grep "sshd: $user" | awk '{print $2}' | xargs -r kill -9 2>/dev/null
                write_log "[$(date '+%H:%M:%S')] Target: $user | Status: KICKED 🚫"
            done < "$USER_LIST"
        fi
        sleep 600 

        # === فاز ۲: وصل (۵ دقیقه) ===
        if [ -s "$USER_LIST" ]; then
            write_log "[$(date '+%H:%M:%S')] >>> RESTORE (5 mins)"
            while IFS= read -r user; do
                chage -E -1 "$user"
                write_log "[$(date '+%H:%M:%S')] Target: $user | Status: ACTIVE ✅"
            done < "$USER_LIST"
        fi
        sleep 300 
    done
    exit 0
fi

# ====================================================
# تنظیم پیام اخطار (متن جدید و دندان‌شکن)
# ====================================================
set_banner() {
    header
    echo -e "${YELLOW}>>> Setting up Warning Message <<<${NC}"
    
    # متن پیام (فارسی + فینگلیش)
    cat > "$BANNER_FILE" <<EOF
************************************************************
* *
* سرور سالمه! چند ماه استفاده کردی پولشو ندادی.           *
* پول یوزرت رو تسویه کن تا قطع نشی.                       *
* *
* Server Saleme! Chand mah estefade kardi poolesho nadadi.*
* Pool useret ro tasviye kon ta ghat nashi.               *
* *
************************************************************
EOF

    # اعمال در تنظیمات SSH
    if grep -q "Banner $BANNER_FILE" /etc/ssh/sshd_config; then
        echo "Config exists."
    else
        sed -i '/^Banner/d' /etc/ssh/sshd_config
        echo "Banner $BANNER_FILE" >> /etc/ssh/sshd_config
    fi
    
    # ریستارت سرویس SSH
    service ssh restart
    service sshd restart
    
    echo -e "${GREEN}Message Set!${NC}"
    sleep 2
}

remove_banner() {
    sed -i '/^Banner/d' /etc/ssh/sshd_config
    rm "$BANNER_FILE" 2>/dev/null
    service ssh restart
    service sshd restart
    echo -e "${GREEN}Message Removed.${NC}"
    sleep 2
}

# ====================================================
# منو و ابزارها
# ====================================================

header() {
    clear
    echo -e "${RED}####################################################${NC}"
    echo -e "${YELLOW}    XPanel Manager v10.2 (Pay Your Bill)            ${NC}"
    echo -e "${RED}####################################################${NC}"
    echo ""
}

add_user() {
    header
    echo -e "${GREEN}>>> Add User <<<${NC}"
    read -p "Enter Username: " username
    if id "$username" &>/dev/null; then
        if grep -Fxq "$username" "$USER_LIST"; then
             echo "Already in list."
        else
             echo "$username" >> "$USER_LIST"
             echo -e "${GREEN}Added.${NC}"
             echo "[$(date '+%H:%M:%S')] Added: $username" >> "$LOG_FILE"
        fi
    else
        echo -e "${RED}User not found!${NC}"
    fi
    sleep 1
}

remove_user() {
    header
    echo -e "${GREEN}>>> Remove User <<<${NC}"
    cat -n "$USER_LIST"
    echo "----------------"
    read -p "Enter Username to remove: " selection
    chage -E -1 "$selection" >/dev/null 2>&1
    sed -i "/^$selection$/d" "$USER_LIST"
    echo -e "${GREEN}Removed & Restored $selection${NC}"
    echo "[$(date '+%H:%M:%S')] Removed: $selection" >> "$LOG_FILE"
    sleep 1
}

enable_service() {
    echo -e "${YELLOW}Updating Service...${NC}"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Dayus Manager Auto-Disconnect
After=network.target

[Service]
Type=simple
ExecStart=$SCRIPT_PATH --service-run
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable dayus-manager
    systemctl restart dayus-manager
    
    echo -e "${GREEN}Service UPDATED (10m OFF / 5m ON).${NC}"
    sleep 2
}

disable_service() {
    systemctl stop dayus-manager
    systemctl disable dayus-manager
    
    if [ -s "$USER_LIST" ]; then
        while IFS= read -r user; do
            chage -E -1 "$user"
        done < "$USER_LIST"
    fi
    echo -e "${GREEN}Stopped.${NC}"
    sleep 2
}

watch_cinema() {
    clear
    echo -e "${YELLOW}--- LIVE LOGS ---${NC}"
    tail -f "$LOG_FILE" | while read line; do
        if [[ "$line" == *"KICKED"* ]]; then echo -e "${RED}$line${NC}";
        elif [[ "$line" == *"ACTIVE"* ]]; then echo -e "${GREEN}$line${NC}";
        else echo "$line"; fi
    done
}

# منو
while true; do
    header
    if systemctl is-active --quiet dayus-manager; then
        echo -e "Status: ${GREEN}● RUNNING${NC}"
    else
        echo -e "Status: ${RED}● STOPPED${NC}"
    fi
    echo ""
    
    echo "1) Add User"
    echo "2) Remove User"
    echo "3) Show List"
    echo "4) START / UPDATE Service"
    echo "5) STOP Service"
    echo -e "${BLUE}6) SET WARNING MESSAGE (Tasviye Kon)${NC}"
    echo "7) Remove Warning Message"
    echo -e "${YELLOW}8) WATCH LOGS 🍿${NC}"
    echo "0) Exit"
    echo ""
    read -p "Select: " opt

    case $opt in
        1) add_user ;;
        2) remove_user ;;
        3) cat "$USER_LIST"; read -p "..." ;;
        4) enable_service ;;
        5) disable_service ;;
        6) set_banner ;;
        7) remove_banner ;;
        8) watch_cinema ;;
        0) exit 0 ;;
    esac
done
