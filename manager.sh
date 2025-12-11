#!/bin/bash

# ==========================================
# Script Name: The Punisher v4.0 (Nightmare)
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
    echo -e "${YELLOW}       XPanel User Manager v4.0 (Nightmare)         ${NC}"
    echo -e "${RED}====================================================${NC}"
    echo ""
}

log_action() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

# تابع کشتن رگباری
kill_user_burst() {
    local target_user=$1
    # این حلقه به مدت 15 ثانیه، هر ثانیه یوزر را چک و قطع می‌کند
    # تا اجازه ندهد بلافاصله ریکانکت شود.
    for i in {1..10}; do
        # پیدا کردن تمام پروسه‌های یوزر (SSH و غیره)
        PIDS=$(pgrep -u "$target_user")
        SSH_PIDS=$(ps -ef | grep "sshd: $target_user" | grep -v grep | awk '{print $2}')
        
        ALL_PIDS="$PIDS $SSH_PIDS"
        
        if [ ! -z "$ALL_PIDS" ] && [ "$ALL_PIDS" != " " ]; then
            # حذف پروسه‌ها با نهایت خشونت
            echo "$ALL_PIDS" | xargs -r kill -9 > /dev/null 2>&1
            pkill -9 -u "$target_user" > /dev/null 2>&1
            killall -9 -u "$target_user" > /dev/null 2>&1
        fi
        sleep 1 # یک ثانیه مکث و دوباره ضربه زدن
    done
    log_action "Targeted $target_user with Burst Mode (10s lock)."
}

add_user() {
    header
    echo -e "${RED}Adding User to Blacklist${NC}"
    read -p "Enter Username: " username
    if id "$username" &>/dev/null; then
        if grep -Fxq "$username" "$USER_LIST"; then
             echo "User already in list."
        else
             echo "$username" >> "$USER_LIST"
             echo -e "${GREEN}User '$username' added.${NC}"
        fi
    else
        echo -e "${RED}User '$username' not found! Added to list anyway.${NC}"
        echo "$username" >> "$USER_LIST"
    fi
    sleep 1
}

remove_user() {
    header
    echo -e "${GREEN}Removing User${NC}"
    cat -n "$USER_LIST"
    echo "----------------"
    read -p "Enter Username to remove: " selection
    sed -i "/^$selection$/d" "$USER_LIST"
    echo -e "${GREEN}Removed $selection${NC}"
    sleep 1
}

test_run() {
    header
    echo -e "${YELLOW}Running BURST TEST (10 seconds attack)...${NC}"
    if [ ! -s "$USER_LIST" ]; then
        echo "List is empty."
        read -p "..."
        return
    fi

    while IFS= read -r user; do
        echo -e "Attacking: ${RED}$user${NC}"
        kill_user_burst "$user"
        echo -e "${GREEN}Attack finished for $user.${NC}"
    done < "$USER_LIST"
    read -p "Press Enter..."
}

start_punishment() {
    if [ -f "$PID_FILE" ]; then
        if ps -p $(cat "$PID_FILE") > /dev/null; then
            echo "Already running."
            sleep 1
            return
        fi
    fi
    
    echo -e "${RED}Starting Nightmare Monitor...${NC}"
    
    # اجرای حلقه اصلی
    nohup bash -c "
    while true; do
        if [ -s $USER_LIST ]; then
            while IFS= read -r user; do
                # اجرای حمله رگباری برای هر یوزر
                for i in {1..12}; do
                   pgrep -u \"\$user\" | xargs -r kill -9
                   ps -ef | grep \"sshd: \$user\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9
                   sleep 1
                done
            done < $USER_LIST
        fi
        sleep 120 # دو دقیقه استراحت
    done" >/dev/null 2>&1 &
    
    echo $! > "$PID_FILE"
    echo -e "${GREEN}Started! PID: $(cat $PID_FILE)${NC}"
    sleep 2
}

stop_punishment() {
    if [ -f "$PID_FILE" ]; then
        kill $(cat "$PID_FILE")
        rm "$PID_FILE"
        echo -e "${GREEN}Stopped.${NC}"
    fi
    sleep 1
}

show_logs() {
    clear
    tail -f "$LOG_FILE"
}

# منو
while true; do
    header
    if [ -f "$PID_FILE" ] && ps -p $(cat "$PID_FILE") > /dev/null; then
        echo -e "Status: ${RED}ACTIVE (Nightmare Mode)${NC}"
    else
        echo -e "Status: ${GREEN}INACTIVE${NC}"
    fi
    
    echo "1) Add User (Diakoone)"
    echo "2) Remove User"
    echo "3) Show List"
    echo "4) START Punishment (ON)"
    echo "5) STOP Punishment (OFF)"
    echo "6) TEST BURST (Manual Attack)"
    echo "0) Exit"
    echo ""
    read -p "Select: " opt
    
    case $opt in
        1) add_user ;;
        2) remove_user ;;
        3) cat "$USER_LIST"; read -p "..." ;;
        4) start_punishment ;;
        5) stop_punishment ;;
        6) test_run ;;
        0) exit 0 ;;
    esac
done
