#!/bin/bash

# ===============================================
# Script Name: XPanel Manager v8.0 (Service Mode)
# Features: Systemd Service, Auto-Start on Boot
# ===============================================

USER_LIST="/root/dayus_users.txt"
SERVICE_FILE="/etc/systemd/system/dayus-manager.service"
SCRIPT_PATH="/usr/local/bin/manager"

# اطمینان از وجود فایل لیست
if [ ! -f "$USER_LIST" ]; then touch "$USER_LIST"; fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root!${NC}"
  exit
fi

# ====================================================
# بخش لاجیک اصلی (که توسط سرویس اجرا میشه)
# ====================================================
if [ "$1" == "--service-run" ]; then
    while true; do
        # === فاز ۱: قطع و انقضا (۱ دقیقه) ===
        if [ -s "$USER_LIST" ]; then
            while IFS= read -r user; do
                # منقضی کردن اکانت (تاریخ انقضا = ۰)
                chage -E 0 "$user"
                # قطع اتصال‌های فعلی
                pkill -KILL -u "$user"
                killall -u "$user" -9
                ps -ef | grep "sshd: $user" | awk '{print $2}' | xargs -r kill -9 2>/dev/null
            done < "$USER_LIST"
        fi
        
        sleep 60 # یک دقیقه خاموشی

        # === فاز ۲: وصل و فعال‌سازی (۱ دقیقه) ===
        if [ -s "$USER_LIST" ]; then
            while IFS= read -r user; do
                # برداشتن انقضا (فعال شدن اکانت)
                chage -E -1 "$user"
            done < "$USER_LIST"
        fi
        
        sleep 60 # یک دقیقه آزادی
    done
    exit 0
fi

# ====================================================
# بخش مدیریت و منو
# ====================================================

header() {
    clear
    echo -e "${RED}####################################################${NC}"
    echo -e "${YELLOW}    XPanel Manager v8.0 (Immortal Service Mode)     ${NC}"
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
    # قبل از حذف، آنلاکش میکنیم
    chage -E -1 "$selection" >/dev/null 2>&1
    sed -i "/^$selection$/d" "$USER_LIST"
    echo -e "${GREEN}Removed & Restored $selection${NC}"
    sleep 1
}

# ساخت و فعال‌سازی سرویس (جادوی اصلی)
enable_service() {
    echo -e "${YELLOW}Creating Systemd Service...${NC}"
    
    # ساخت فایل سرویس
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Dayus Manager Auto-Disconnect Service
After=network.target

[Service]
Type=simple
ExecStart=$SCRIPT_PATH --service-run
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    # ریلود کردن دیمِن‌های لینوکس
    systemctl daemon-reload
    # فعال کردن برای بوت (که بعد از ریستارت روشن شه)
    systemctl enable dayus-manager
    # استارت زدن همین الان
    systemctl start dayus-manager
    
    echo -e "${GREEN}Service STARTED and ENABLED on Boot!${NC}"
    echo -e "You can now close the terminal. It runs in background."
    sleep 3
}

# غیرفعال کردن و پاکسازی
disable_service() {
    echo -e "${YELLOW}Stopping Service...${NC}"
    systemctl stop dayus-manager
    systemctl disable dayus-manager
    rm "$SERVICE_FILE" 2>/dev/null
    systemctl daemon-reload
    
    echo -e "${YELLOW}Restoring all users...${NC}"
    if [ -s "$USER_LIST" ]; then
        while IFS= read -r user; do
            chage -E -1 "$user"
            echo -e "Restored: $user"
        done < "$USER_LIST"
    fi
    echo -e "${GREEN}All Stopped & Fixed.${NC}"
    sleep 2
}

# منوی اصلی
while true; do
    header
    # چک کردن وضعیت سرویس
    if systemctl is-active --quiet dayus-manager; then
        echo -e "Status: ${GREEN}● ACTIVE (Running in Background)${NC}"
    else
        echo -e "Status: ${RED}● INACTIVE (Stopped)${NC}"
    fi
    echo ""
    
    echo "1) Add User"
    echo "2) Remove User"
    echo "3) Show List"
    echo "4) START Service (Auto-Start on Boot)"
    echo "5) STOP Service (Unlock Everyone)"
    echo "0) Exit"
    echo ""
    read -p "Select: " opt

    case $opt in
        1) add_user ;;
        2) remove_user ;;
        3) cat "$USER_LIST"; read -p "..." ;;
        4) enable_service ;;
        5) disable_service ;;
        0) exit 0 ;;
    esac
done
