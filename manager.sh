#!/bin/bash

# ===============================================
# Script Name: XPanel User Torture (Final Logic)
# Tested on: XPanel / Ubuntu 20 & 22
# ===============================================

USER_LIST="/root/dayus_users.txt"
touch "$USER_LIST"

# رنگ‌ها
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# چک کردن دسترسی روت
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root!${NC}"
  exit
fi

header() {
    clear
    echo -e "${RED}####################################################${NC}"
    echo -e "${YELLOW}      XPanel Bad User Kicker (Lock & Kill Strategy) ${NC}"
    echo -e "${RED}####################################################${NC}"
    echo ""
}

add_user() {
    header
    echo -e "${GREEN}>>> Add User (Exact Username) <<<${NC}"
    read -p "Enter Username: " username

    # چک کردن وجود یوزر در سیستم (مخصوص XPanel)
    if id "$username" &>/dev/null; then
        if grep -Fxq "$username" "$USER_LIST"; then
             echo -e "${YELLOW}User '$username' is already targeted.${NC}"
        else
             echo "$username" >> "$USER_LIST"
             echo -e "${GREEN}User '$username' Added.${NC}"
        fi
    else
        echo -e "${RED}Error: User '$username' not found in Linux!${NC}"
        echo -e "Please check the exact spelling in XPanel."
    fi
    sleep 2
}

remove_user() {
    header
    echo -e "${GREEN}>>> Remove & Fix User <<<${NC}"
    cat -n "$USER_LIST"
    echo "----------------"
    read -p "Enter Username to remove: " selection
    
    # اطمینان از اینکه یوزر قفل نمونده باشه
    usermod -U "$selection" 2>/dev/null
    passwd -u "$selection" 2>/dev/null
    
    sed -i "/^$selection$/d" "$USER_LIST"
    echo -e "${GREEN}User '$selection' removed and unlocked.${NC}"
    sleep 2
}

# عملیات اصلی شکنجه
torture_cycle() {
    if [ ! -s "$USER_LIST" ]; then
        echo -e "${RED}List is empty! Add users first.${NC}"
        sleep 2
        return
    fi

    echo -e "${YELLOW}Starting Torture Loop (Runs every 2 mins)...${NC}"
    echo -e "${BLUE}Press Ctrl+C to STOP and UNLOCK everyone.${NC}"
    echo "---------------------------------------------------"

    while true; do
        while IFS= read -r user; do
            # 1. LOCK: جلوگیری از ریکانکت سریع
            # usermod -L جلوی لاگین مجدد رو میگیره
            usermod -L "$user" >/dev/null 2>&1
            
            # 2. KILL: قطع کردن تمام اتصالات (SSH + Dropbear)
            # کشتن پروسه‌های متعلق به یوزر
            pkill -KILL -u "$user" >/dev/null 2>&1
            killall -9 -u "$user" >/dev/null 2>&1
            
            # کشتن دستی پروسه‌های SSHD (برای اطمینان)
            ps -ef | grep "sshd: $user" | awk '{print $2}' | xargs -r kill -9 >/dev/null 2>&1
            # کشتن پروسه‌های Dropbear (اگر XPanel دراپ‌بیر داره)
            ps -ef | grep "dropbear" | grep "$user" | awk '{print $2}' | xargs -r kill -9 >/dev/null 2>&1

            echo -e "[$(date +%H:%M)] ${RED}KICKED & LOCKED:${NC} $user"
        done < "$USER_LIST"

        # 3. WAIT: ۱۰ ثانیه صبر میکنیم تا کلاینت یوزر ارور Auth Failed بده و قطع بشه
        echo -e "${BLUE}>>> Waiting 10s (Forcing client disconnect)...${NC}"
        sleep 10

        # 4. UNLOCK: باز کردن یوزرها برای دور بعدی (شکنجه ادامه دارد)
        while IFS= read -r user; do
            usermod -U "$user" >/dev/null 2>&1
        done < "$USER_LIST"
        
        echo -e "[$(date +%H:%M)] ${GREEN}UNLOCKED all users. Waiting 2 mins...${NC}"
        
        # 5. استراحت ۲ دقیقه‌ای
        sleep 120
    done
}

# هندل کردن خروج با Ctrl+C (خیلی مهم برای باز کردن قفل یوزرها)
trap ctrl_c INT
ctrl_c() {
    echo -e "\n${YELLOW}Stopping... Unlocking all users...${NC}"
    if [ -s "$USER_LIST" ]; then
        while IFS= read -r user; do
            usermod -U "$user" >/dev/null 2>&1
        done < "$USER_LIST"
    fi
    echo -e "${GREEN}All users unlocked. Bye!${NC}"
    exit 0
}

# منو
while true; do
    header
    echo "1) Add User (Diakoone)"
    echo "2) Remove User"
    echo "3) Show List"
    echo "4) START TORTURE LOOP"
    echo "0) Exit"
    echo ""
    read -p "Select: " opt

    case $opt in
        1) add_user ;;
        2) remove_user ;;
        3) cat "$USER_LIST"; read -p "..." ;;
        4) torture_cycle ;;
        0) exit 0 ;;
        *) echo "Invalid" ;;
    esac
done
