#!/bin/bash

# ===============================================
# Script Name: XPanel Manager v9.2 (5m ON / 10m OFF)
# Timing: 10 Min OFF (Disconnect) / 5 Min ON (Connect)
# ===============================================

USER_LIST="/root/dayus_users.txt"
LOG_FILE="/var/log/dayus.log"
SERVICE_FILE="/etc/systemd/system/dayus-manager.service"
SCRIPT_PATH="/usr/local/bin/manager"

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
# سرویس پشت‌صحنه (با زمان‌بندی ۱۰ دقیقه قطع / ۵ دقیقه وصل)
# ====================================================
if [ "$1" == "--service-run" ]; then
    write_log "--- SERVICE STARTED (Timing: 10m OFF / 5m ON) ---"
    while true; do
        # === فاز ۱: قطع و انقضا (۱۰ دقیقه) ===
        if [ -s "$USER_LIST" ]; then
            write_log "[$(date '+%H:%M:%S')] >>> Phase: LOCK & KILL (Users Disabled for 10 mins)"
            while IFS= read -r user; do
                chage -E 0 "$user"
                pkill -KILL -u "$user"
                killall -u "$user" -9
                ps -ef | grep "sshd: $user" | awk '{print $2}' | xargs -r kill -9 2>/dev/null
                write_log "[$(date '+%H:%M:%S')] Target: $user | Status: KICKED & EXPIRED 🚫"
            done < "$USER_LIST"
        else
            write_log "[$(date '+%H:%M:%S')] List is empty. Sleeping..."
        fi
        
        # ۱۰ دقیقه صبر برای قطع بودن (۶۰۰ ثانیه)
        sleep 600 

        # === فاز ۲: وصل و فعال‌سازی (۵ دقیقه) ===
        if [ -s "$USER_LIST" ]; then
            write_log "[$(date '+%H:%M:%S')] >>> Phase: RESTORE (Users Active for 5 mins)"
            while IFS= read -r user; do
                chage -E -1 "$user"
                write_log "[$(date '+%H:%M:%S')] Target: $user | Status: ACTIVE ✅"
            done < "$USER_LIST"
        fi
        
        # ۵ دقیقه صبر برای وصل بودن (۳۰۰ ثانیه)
        sleep 300 
    done
    exit 0
fi

# ====================================================
# منو و ابزارها
# ====================================================

header() {
    clear
    echo -e "${RED}####################################################${NC}"
    echo -e "${YELLOW}    XPanel Manager v9.2 (10m OFF / 5m ON)           ${NC}"
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
             echo "[$(date '+%H:%M:%S')] Added user: $username" >> "$LOG_FILE"
        fi
    else
        echo -e "${RED}User not found in Linux!${NC}"
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
    echo "[$(date '+%H:%M:%S')] Removed user: $selection" >> "$LOG_FILE"
    sleep 1
}

enable_service() {
    echo -e "${YELLOW}Installing Service...${NC}"
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
    
    # ریستارت کردن سرویس برای اعمال تغییرات جدید
    systemctl restart dayus-manager
    
    echo -e "${GREEN}Service STARTED with new timing!${NC}"
    sleep 2
}

disable_service() {
    echo -e "${YELLOW}Stopping Service...${NC}"
    systemctl stop dayus-manager
    systemctl disable dayus-manager
    rm "$SERVICE_FILE" 2>/dev/null
    systemctl daemon-reload
    
    if [ -s "$USER_LIST" ]; then
        while IFS= read -r user; do
            chage -E -1 "$user"
        done < "$USER_LIST"
    fi
    echo -e "${GREEN}Stopped & Users Unlocked.${NC}"
    sleep 2
}

watch_cinema() {
    clear
    echo -e "${YELLOW}--- LIVE MONITOR (10m OFF / 5m ON) ---${NC}"
    echo -e "${BLUE}Waiting for action...${NC}"
    echo "-------------------------------------------"
    tail -f "$LOG_FILE" | while read line; do
        if [[ "$line" == *"KICKED"* ]]; then
            echo -e "${RED}$line${NC}"
        elif [[ "$line" == *"ACTIVE"* ]]; then
            echo -e "${GREEN}$line${NC}"
        elif [[ "$line" == *"LOCK"* ]]; then
            echo -e "${YELLOW}$line${NC}"
        elif [[ "$line" == *"RESTORE"* ]]; then
            echo -e "${BLUE}$line${NC}"
        else
            echo "$line"
        fi
    done
}

# منو
while true; do
    header
    if systemctl is-active --quiet dayus-manager; then
        echo -e "Status: ${GREEN}● RUNNING (10m OFF / 5m ON)${NC}"
    else
        echo -e "Status: ${RED}● STOPPED${NC}"
    fi
    echo ""
    
    echo "1) Add User"
    echo "2) Remove User"
    echo "3) Show List"
    echo "4) START / UPDATE Service"
    echo "5) STOP Service"
    echo -e "${YELLOW}6) WATCH LOGS 🍿${NC}"
    echo "0) Exit"
    echo ""
    read -p "Select: " opt

    case $opt in
        1) add_user ;;
        2) remove_user ;;
        3) cat "$USER_LIST"; read -p "..." ;;
        4) enable_service ;;
        5) disable_service ;;
        6) watch_cinema ;;
        0) exit 0 ;;
    esac
done
