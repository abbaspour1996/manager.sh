#!/bin/bash

# ===============================================
# Script Name: XPanel Manager v13.0 (Targeted Message)
# Timing: 10 Min OFF / 5 Min ON
# Feature: Banner ONLY for listed users (Match User)
# ===============================================

USER_LIST="/root/dayus_users.txt"
LOG_FILE="/var/log/dayus.log"
SERVICE_FILE="/etc/systemd/system/dayus-manager.service"
SCRIPT_PATH="/usr/local/bin/manager"
BANNER_FILE="/etc/ssh/dayus_warning.txt"
SSH_CONFIG="/etc/ssh/sshd_config"

# اطمینان از وجود فایل‌ها
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
# مدیریت هوشمند کانفیگ SSH (فقط برای یوزرهای لیست)
# ====================================================
update_ssh_config() {
    # 1. اول پاکسازی تنظیمات قبلی اسکریپت از فایل کانفیگ
    sed -i '/^# --- DAYUS START ---$/,/^# --- DAYUS END ---$/d' "$SSH_CONFIG"
    # حذف خط‌های خالی اضافی ته فایل
    sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$SSH_CONFIG"

    # 2. اگر لیست خالیه، دیگه کاری نداریم (پیام برای کسی نمیره)
    if [ ! -s "$USER_LIST" ]; then
        service ssh restart >/dev/null 2>&1
        service sshd restart >/dev/null 2>&1
        return
    fi

    # 3. ساختن لیست یوزرها با کاما (user1,user2,user3)
    USERS_COMMA=$(paste -sd, "$USER_LIST")
    
    # 4. نوشتن بلاک Match User به ته فایل کانفیگ
    # این دستور میگه: فقط برای این یوزرها، فایل بنر رو نشون بده
    cat >> "$SSH_CONFIG" <<EOF

# --- DAYUS START ---
Match User $USERS_COMMA
    Banner $BANNER_FILE
# --- DAYUS END ---
EOF

    # 5. ساخت فایل پیام
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

    # 6. ریستارت سرویس برای اعمال تغییرات
    service ssh restart >/dev/null 2>&1
    service sshd restart >/dev/null 2>&1
}

# ====================================================
# سرویس پشت‌صحنه (۱۰ دقیقه قطع / ۵ دقیقه وصل)
# ====================================================
if [ "$1" == "--service-run" ]; then
    write_log "--- SERVICE STARTED v13.0 (Targeted) ---"
    while true; do
        # === فاز ۱: قطع (۱۰ دقیقه) ===
        if [ -s "$USER_LIST" ]; then
            write_log "[$(date '+%H:%M:%S')] >>> LOCK & KILL (10 Mins)"
            while IFS= read -r user; do
                chage -E 0 "$user"
                pkill -KILL -u "$user"
                killall -u "$user" -9
                ps -ef | grep "sshd: $user" | awk '{print $2}' | xargs -r kill -9 2>/dev/null
                write_log "[$(date '+%H:%M:%S')] Target: $user | Status: KICKED 🚫"
            done < "$USER_LIST"
        fi
        sleep 600  # ۱۰ دقیقه قطع

        # === فاز ۲: وصل (۵ دقیقه) ===
        if [ -s "$USER_LIST" ]; then
            write_log "[$(date '+%H:%M:%S')] >>> RESTORE (5 Mins)"
            while IFS= read -r user; do
                chage -E -1 "$user"
                write_log "[$(date '+%H:%M:%S')] Target: $user | Status: ACTIVE ✅"
            done < "$USER_LIST"
        fi
        sleep 300 # ۵ دقیقه وصل
    done
    exit 0
fi

# ====================================================
# منو و ابزارها
# ====================================================
header() {
    clear
    echo -e "${RED}####################################################${NC}"
    echo -e "${YELLOW}    XPanel Manager v13.0 (Targeted Sniper)          ${NC}"
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
             update_ssh_config # آپدیت کانفیگ SSH
             echo -e "${GREEN}Added & Message Configured for $username.${NC}"
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
    
    update_ssh_config # آپدیت کانفیگ SSH (حذف یوزر از لیست پیام)
    
    echo -e "${GREEN}Removed & Restored $selection${NC}"
    echo "[$(date '+%H:%M:%S')] Removed: $selection" >> "$LOG_FILE"
    sleep 1
}

enable_service() {
    echo -e "${YELLOW}Updating Service & Configs...${NC}"
    
    # پاکسازی بنر عمومی (Global Banner) اگر قبلاً فعال شده باشه
    sed -i '/^Banner \/etc\/ssh\/dayus_warning.txt/d' "$SSH_CONFIG"
    
    # اعمال تنظیمات جدید
    update_ssh_config

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Dayus Manager
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
    echo -e "${GREEN}Service STARTED (10m OFF / 5m ON).${NC}"
    echo -e "${BLUE}Targeted Messaging Active (Only for listed users).${NC}"
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
    
    # پاک کردن تنظیمات SSH
    sed -i '/^# --- DAYUS START ---$/,/^# --- DAYUS END ---$/d' "$SSH_CONFIG"
    service ssh restart >/dev/null 2>&1
    
    echo -e "${GREEN}Stopped & Cleaned up.${NC}"
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

# منوی اصلی
while true; do
    header
    if systemctl is-active --quiet dayus-manager; then
        echo -e "Status: ${GREEN}● RUNNING (10m OFF / 5m ON)${NC}"
    else
        echo -e "Status: ${RED}● STOPPED${NC}"
    fi
    echo ""
    echo "1) Add User (Auto-Configure Message)"
    echo "2) Remove User"
    echo "3) Show List"
    echo "4) START / UPDATE Service"
    echo "5) STOP Service"
    echo "6) WATCH LOGS 🍿"
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
