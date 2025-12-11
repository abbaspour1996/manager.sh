#!/bin/bash

# ===============================================
# Script Name: XPanel Manager v7.0 (Expire Method)
# Logic: Uses 'chage' to expire account instantly
# ===============================================

USER_LIST="/root/dayus_users.txt"
touch "$USER_LIST"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Run as root!${NC}"
  exit
fi

header() {
    clear
    echo -e "${RED}####################################################${NC}"
    echo -e "${YELLOW}      XPanel User Manager (Expiration Method)       ${NC}"
    echo -e "${RED}####################################################${NC}"
    echo ""
}

# تابع بازگردانی همه یوزرها (برای وقتی که اسکریپت رو میبندی)
restore_all() {
    echo -e "\n${YELLOW}Restoring all users to active status...${NC}"
    if [ -s "$USER_LIST" ]; then
        while IFS= read -r user; do
            # دستور chage -E -1 یعنی انقضا رو بردار (نامحدود کن)
            chage -E -1 "$user" >/dev/null 2>&1
            echo -e "User $user -> ${GREEN}Active${NC}"
        done < "$USER_LIST"
    fi
    exit 0
}
trap restore_all INT

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
        echo -e "${RED}User does not exist in Linux!${NC}"
    fi
    sleep 1
}

remove_user() {
    header
    echo -e "${GREEN}>>> Remove User <<<${NC}"
    cat -n "$USER_LIST"
    echo "----------------"
    read -p "Enter Username to remove: " selection
    
    # قبل از پاک کردن، یوزر رو فعال میکنیم که خراب نمونه
    chage -E -1 "$selection" >/dev/null 2>&1
    
    sed -i "/^$selection$/d" "$USER_LIST"
    echo -e "${GREEN}Removed and Activated $selection${NC}"
    sleep 1
}

start_cycle() {
    if [ ! -s "$USER_LIST" ]; then
        echo "List is empty."
        sleep 2
        return
    fi

    echo -e "${YELLOW}Cycle Started. Press Ctrl+C to STOP and Fix Users.${NC}"
    echo "---------------------------------------------------"

    while true; do
        # === فاز ۱: قطع کردن (بستن حساب) ===
        echo -e "[$(date +%H:%M:%S)] ${RED}>>> DISABLE & KILL USERS${NC}"
        while IFS= read -r user; do
            # 1. تنظیم تاریخ انقضا به 0 (غیرفعال سازی فوری اکانت)
            chage -E 0 "$user"
            
            # 2. بیرون انداختن یوزر
            pkill -KILL -u "$user"
            killall -u "$user" -9
            # کشتن دقیق SSH
            ps -ef | grep "sshd: $user" | awk '{print $2}' | xargs -r kill -9 2>/dev/null
            
            echo -e "User $user -> ${RED}EXPIRED & KICKED${NC}"
        done < "$USER_LIST"
        
        # ۳ دقیقه (یا هر چقدر میخوای) صبر میکنه تو حالت قطع
        echo -e "${YELLOW}Waiting 2 mins (Users cannot connect)...${NC}"
        sleep 120 

        # === فاز ۲: وصل کردن (فعال کردن حساب) ===
        echo -e "[$(date +%H:%M:%S)] ${GREEN}>>> RE-ACTIVATE USERS${NC}"
        while IFS= read -r user; do
            # برداشتن انقضا (اکانت سالم میشه)
            chage -E -1 "$user"
            echo -e "User $user -> ${GREEN}ACTIVE${NC}"
        done < "$USER_LIST"
        
        # ۳ دقیقه (یا هر چقدر میخوای) وصل میمونه
        echo -e "${YELLOW}Waiting 2 mins (Users can connect)...${NC}"
        sleep 120
    done
}

# منو
while true; do
    header
    echo "1) Add User"
    echo "2) Remove User"
    echo "3) Show List"
    echo "4) START CYCLE (2min OFF / 2min ON)"
    echo "0) Exit"
    echo ""
    read -p "Select: " opt

    case $opt in
        1) add_user ;;
        2) remove_user ;;
        3) cat "$USER_LIST"; read -p "..." ;;
        4) start_cycle ;;
        0) exit 0 ;;
    esac
done
