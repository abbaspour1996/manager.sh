#!/bin/bash

# ==========================================
# Script Name: The Punisher (Dayus Manager)
# Tested on: Ubuntu 20.04 / 22.04
# ==========================================

# مسیرهای فایل
USER_LIST="/root/dayus_users.txt"
PID_FILE="/root/dayus_punisher.pid"
SCRIPT_PATH="/usr/local/bin/dayus"

# رنگ‌بندی
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\133[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 1. چک کردن دسترسی روت
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root!${NC}"
  exit
fi

# 2. اطمینان از وجود فایل لیست
if [ ! -f "$USER_LIST" ]; then
    touch "$USER_LIST"
fi

# هدر منو
header() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}       XPanel Bad User Manager (The Punisher)       ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo -e "Users in this list will be disconnected every 2 mins."
    echo ""
}

# اضافه کردن یوزر
add_user() {
    header
    echo -e "${RED}>>> ADDING USERS TO BLACKLIST <<<${NC}"
    echo "Enter usernames one by one."
    echo "Type 'END' to finish and return to menu."
    echo "-------------------------------------------"
    
    while true; do
        read -p "Enter Username to Punish: " username
        if [[ "$username" == "END" || "$username" == "end" || -z "$username" ]]; then
            break
        fi
        
        # بررسی وجود یوزر در سیستم
        if id "$username" &>/dev/null; then
            if grep -Fxq "$username" "$USER_LIST"; then
                 echo -e "${YELLOW}User '$username' is already suffering.${NC}"
            else
                 echo "$username" >> "$USER_LIST"
                 echo -e "${GREEN}User '$username' added to blacklist.${NC}"
            fi
        else
            echo -e "${RED}Error: User '$username' does not exist on this server!${NC}"
            echo -e "Make sure you created the user in XPanel first."
        fi
    done
}

# حذف یوزر
remove_user() {
    header
    echo -e "${GREEN}>>> REMOVING USERS FROM BLACKLIST <<<${NC}"
    if [ ! -s "$USER_LIST" ]; then
        echo "List is empty. Everyone is safe... for now."
        read -p "Press Enter to return..."
        return
    fi

    echo "Current Blacklist:"
    echo "------------------"
    cat -n "$USER_LIST"
    echo "------------------"
    echo "Enter the Username to forgive, or 'ALL' to clear list."
    echo "Type 'BACK' to return."
    
    read -p "Selection: " selection
    
    if [[ "$selection" == "BACK" || "$selection" == "back" ]]; then
        return
    elif [[ "$selection" == "ALL" || "$selection" == "all" ]]; then
        > "$USER_LIST"
        echo -e "${GREEN}All users removed from blacklist.${NC}"
    else
        # حذف دقیق یوزر
        if grep -Fxq "$selection" "$USER_LIST"; then
            sed -i "/^$selection$/d" "$USER_LIST"
            echo -e "${GREEN}User '$selection' removed.${NC}"
        else
            echo -e "${RED}User '$selection' not found in the list.${NC}"
        fi
    fi
    sleep 1.5
}

# شروع عملیات قطع و وصل (Background Process)
start_punishment() {
    if [ -f "$PID_FILE" ]; then
        if ps -p $(cat "$PID_FILE") > /dev/null; then
            echo -e "${RED}Punishment is ALREADY running!${NC}"
            read -p "Press Enter..."
            return
        fi
    fi

    echo -e "${RED}Starting the cycle... Users will be kicked every 120 seconds.${NC}"
    
    # اجرای لوپ در پس‌زمینه
    nohup bash -c "while true; do
        if [ -s $USER_LIST ]; then
            while IFS= read -r user; do
                # انواع متدهای قطع کردن برای اطمینان
                pkill -KILL -u \$user
                killall -u \$user -9
                # قطع کردن نشست‌های SSH خاص
                ps -ef | grep \"sshd: \$user\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9
            done < $USER_LIST
        fi
        sleep 120
    done" >/dev/null 2>&1 &
    
    PID=$!
    echo $PID > "$PID_FILE"
    
    echo -e "${GREEN}Process Started! PID: $PID${NC}"
    sleep 2
}

# توقف عملیات
stop_punishment() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null; then
            kill $PID
            rm "$PID_FILE"
            echo -e "${GREEN}Punishment stopped. Users can breathe now.${NC}"
        else
            echo -e "${YELLOW}Process wasn't running but PID file existed. Cleaned.${NC}"
            rm "$PID_FILE"
        fi
    else
        echo -e "${YELLOW}No active punishment process found.${NC}"
    fi
    sleep 2
}

# منوی اصلی
while true; do
    header
    
    # نمایش وضعیت
    if [ -f "$PID_FILE" ] && ps -p $(cat "$PID_FILE") > /dev/null; then
        echo -e "System Status: ${RED}[ ACTIVE - KICKING USERS ]${NC}"
        echo -e "PID: $(cat $PID_FILE)"
    else
        echo -e "System Status: ${GREEN}[ INACTIVE ]${NC}"
    fi
    echo ""
    
    echo "1) Add User (Diakoone/Dayus)"
    echo "2) Remove User (Forgive)"
    echo "3) Show List"
    echo "4) START Punishment (ON)"
    echo "5) STOP Punishment (OFF)"
    echo "0) Exit"
    echo ""
    read -p "Select option: " opt

    case $opt in
        1) add_user ;;
        2) remove_user ;;
        3) 
           header
           echo "Target List:"
           cat "$USER_LIST"
           echo ""
           read -p "Press Enter..." 
           ;;
        4) start_punishment ;;
        5) stop_punishment ;;
        0) echo "Bye!"; exit 0 ;;
        *) echo "Invalid option"; sleep 1 ;;
    esac
done
