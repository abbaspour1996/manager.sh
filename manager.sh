#!/bin/bash

# ==========================================
# Script Name: The Punisher v5.0 (Lockdown Edition)
# ==========================================

USER_LIST="/root/dayus_users.txt"
PID_FILE="/root/dayus_punisher.pid"
LOG_FILE="/root/punisher_log.txt"

# رنگ‌ها
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root!${NC}"
  exit
fi

touch "$USER_LIST"
touch "$LOG_FILE"

header() {
    clear
    echo -e "${RED}====================================================${NC}"
    echo -e "${YELLOW}    XPanel User Manager v5.0 (Account Lockdown)     ${NC}"
    echo -e "${RED}====================================================${NC}"
    echo -e "Method: Locking accounts periodically (Auth Failed error)."
    echo ""
}

log_action() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

# باز کردن قفل همه یوزرها (برای وقتی که استپ میکنی)
unlock_all_users() {
    if [ -s "$USER_LIST" ]; then
        echo -e "${YELLOW}Unlocking all users...${NC}"
        while IFS= read -r user; do
            passwd -u "$user" >/dev/null 2>&1
            # usermod -U "$user" >/dev/null 2>&1
            log_action "User $user UNLOCKED (Rescue)."
        done < "$USER_LIST"
    fi
}

add_user() {
    header
    echo -e "${RED}Adding User to List${NC}"
    read -p "Enter Username: " username
    if id "$username" &>/dev/null; then
        if grep -Fxq "$username" "$USER_LIST"; then
             echo "User already in list."
        else
             echo "$username" >> "$USER_LIST"
             echo -e "${GREEN}User '$username' added.${NC}"
        fi
    else
        echo -e "${RED}User '$username' does not exist!${NC}"
    fi
    sleep 1
}

remove_user() {
    header
    echo -e "${GREEN}Removing User${NC}"
    cat -n "$USER_LIST"
    echo "----------------"
    read -p "Enter Username to remove: " selection
    # قبل از حذف از لیست، مطمئن میشیم آنلاک شده باشه
    passwd -u "$selection" >/dev/null 2>&1
    
    sed -i "/^$selection$/d" "$USER_LIST"
    echo -e "${GREEN}Removed and Unlocked $selection${NC}"
    sleep 1
}

start_punishment() {
    if [ -f "$PID_FILE" ]; then
        echo "Already running."
        sleep 1
        return
    fi
    
    echo -e "${RED}Starting Lockdown Cycle...${NC}"
    echo -e "${YELLOW}Users will be LOCKED for 60s, then UNLOCKED for 60s.${NC}"
    
    nohup bash -c "
    while true; do
        # === PHASE 1: LOCK & KILL (60 Seconds) ===
        if [ -s $USER_LIST ]; then
            echo \"[$(date '+%H:%M:%S')] >>> LOCKING USERS\" >> $LOG_FILE
            while IFS= read -r user; do
                passwd -l \"\$user\" >/dev/null 2>&1  # قفل کردن پسورد
                
                # قطع کردن اتصالات
                pgrep -u \"\$user\" | xargs -r kill -9
                ps -ef | grep \"sshd: \$user\" | awk '{print \$2}' | xargs -r kill -9
            done < $USER_LIST
        fi
        sleep 60 

        # === PHASE 2: UNLOCK (60 Seconds) ===
        if [ -s $USER_LIST ]; then
             echo \"[$(date '+%H:%M:%S')] >>> UNLOCKING USERS\" >> $LOG_FILE
             while IFS= read -r user; do
                passwd -u \"\$user\" >/dev/null 2>&1 # باز کردن پسورد
             done < $USER_LIST
        fi
        sleep 60
    done" >/dev/null 2>&1 &
    
    echo $! > "$PID_FILE"
    echo -e "${GREEN}Started! PID: $(cat $PID_FILE)${NC}"
    sleep 2
}

stop_punishment() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        kill $PID
        rm "$PID_FILE"
        echo -e "${GREEN}Monitor Stopped.${NC}"
        log_action "Monitor Stopped."
        
        # خیلی مهم: بازگرداندن دسترسی یوزرها
        unlock_all_users
    else
        echo "Not running."
    fi
    sleep 2
}

# تست دستی برای اطمینان
test_lock() {
    header
    echo -e "${RED}TEST MODE: Locking users for 10 seconds...${NC}"
    if [ ! -s "$USER_LIST" ]; then echo "List empty."; sleep 1; return; fi
    
    while IFS= read -r user; do
        echo -e "Locking $user..."
        passwd -l "$user"
        pkill -9 -u "$user"
    done < "$USER_LIST"
    
    echo -e "${YELLOW}Users are now LOCKED. Try to connect with VPN now! (Wait 10s)${NC}"
    sleep 10
    
    echo -e "${GREEN}Unlocking users...${NC}"
    while IFS= read -r user; do
        passwd -u "$user"
    done < "$USER_LIST"
    echo "Done."
    read -p "Press Enter..."
}

show_logs() {
    clear
    tail -f "$LOG_FILE"
}

# منو
while true; do
    header
    if [ -f "$PID_FILE" ] && ps -p $(cat "$PID_FILE") > /dev/null; then
        echo -e "Status: ${RED}ACTIVE (Lock/Unlock Cycle)${NC}"
    else
        echo -e "Status: ${GREEN}INACTIVE${NC}"
    fi
    
    echo "1) Add User"
    echo "2) Remove User"
    echo "3) Show List"
    echo "4) START Lockdown (60s Off / 60s On)"
    echo "5) STOP Lockdown (Unlock Everyone)"
    echo "6) TEST LOCK (10s Test)"
    echo "7) Watch Logs"
    echo "0) Exit"
    echo ""
    read -p "Select: " opt
    
    case $opt in
        1) add_user ;;
        2) remove_user ;;
        3) cat "$USER_LIST"; read -p "..." ;;
        4) start_punishment ;;
        5) stop_punishment ;;
        6) test_lock ;;
        7) show_logs ;;
        0) exit 0 ;;
    esac
done
