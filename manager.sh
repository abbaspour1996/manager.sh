#!/bin/bash

# ==========================================
# Script Name: The Punisher v3.0 (Targeted Kill)
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

# چک کردن روت
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root!${NC}"
  exit
fi

touch "$USER_LIST"
touch "$LOG_FILE"

header() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}       XPanel User Manager v3.0 (Targeted)          ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo ""
}

log_action() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

# تابع کشتن قدرتمند
kill_user_process() {
    local target_user=$1
    local killed=0
    
    # روش ۱: پیدا کردن پروسه‌های SSHD اختصاصی (مهمترین بخش)
    # این دستور دنبال پروسه‌هایی میگردد که فرمت sshd: user دارند
    PIDS_SSH=$(ps -ef | grep "sshd: $target_user" | grep -v grep | awk '{print $2}')
    
    # روش ۲: پیدا کردن پروسه متعلق به خود یوزر
    PIDS_USER=$(pgrep -u "$target_user")

    # ترکیب همه PID ها
    ALL_PIDS="$PIDS_SSH $PIDS_USER"
    
    if [ ! -z "$ALL_PIDS" ]; then
        # حذف فضای خالی اضافه
        ALL_PIDS=$(echo "$ALL_PIDS" | tr '\n' ' ')
        
        log_action "Targeting $target_user | Found PIDs: $ALL_PIDS"
        
        # تیر خلاص
        echo "$ALL_PIDS" | xargs -r kill -9
        
        log_action ">>> KILLED $target_user successfully."
        killed=1
    else
        # فقط برای دیباگ مینویسیم که یوزر آنلاین نیست
        # log_action "User $target_user is offline (No PIDs found)."
        :
    fi
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
             log_action "Added user to list: $username"
        fi
    else
        echo -e "${RED}Warning: User '$username' not found in system /etc/passwd!${NC}"
        echo -e "But added to list anyway (maybe it's a virtual user)."
        echo "$username" >> "$USER_LIST"
        sleep 2
    fi
}

remove_user() {
    header
    echo -e "${GREEN}Removing User${NC}"
    cat -n "$USER_LIST"
    echo "----------------"
    read -p "Enter Username to remove: " selection
    sed -i "/^$selection$/d" "$USER_LIST"
    echo -e "${GREEN}Removed $selection${NC}"
    log_action "Removed user from list: $selection"
    sleep 1
}

test_run() {
    header
    echo -e "${YELLOW}Running TEST NOW (Check output below)...${NC}"
    
    if [ ! -s "$USER_LIST" ]; then
        echo "List is empty."
        read -p "..."
        return
    fi

    while IFS= read -r user; do
        echo -e "Checking: ${CYAN}$user${NC}"
        # نمایش زنده پروسه
        ps -ef | grep "sshd: $user" | grep -v grep
        
        kill_user_process "$user"
        echo "--------------------------------"
    done < "$USER_LIST"
    
    echo "Done. Check logs for details."
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
    
    echo -e "${RED}Starting Background Monitor...${NC}"
    log_action "--- MONITOR STARTED ---"
    
    # اجرای حلقه در بک‌گراند
    nohup bash -c "
    while true; do
        if [ -s $USER_LIST ]; then
            while IFS= read -r user; do
                # بازنویسی منطق کشتن در ساب‌شل
                PIDS=\$(ps -ef | grep \"sshd: \$user\" | grep -v grep | awk '{print \$2}')
                if [ ! -z \"\$PIDS\" ]; then
                    echo \"[\$(date '+%H:%M:%S')] Kicking \$user (PIDs: \$PIDS)\" >> $LOG_FILE
                    echo \"\$PIDS\" | xargs -r kill -9
                fi
            done < $USER_LIST
        fi
        sleep 120
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
        log_action "--- MONITOR STOPPED ---"
    fi
    sleep 1
}

show_logs() {
    clear
    echo -e "${YELLOW}Live Logs (Press Ctrl+C to exit logs):${NC}"
    echo "---------------------------------"
    tail -f "$LOG_FILE"
}

# منوی اصلی
while true; do
    header
    if [ -f "$PID_FILE" ] && ps -p $(cat "$PID_FILE") > /dev/null; then
        echo -e "Status: ${RED}ACTIVE [PID: $(cat $PID_FILE)]${NC}"
    else
        echo -e "Status: ${GREEN}INACTIVE${NC}"
    fi
    
    echo "1) Add User (Diakoone)"
    echo "2) Remove User"
    echo "3) Show Blacklist"
    echo "4) START Monitor (Auto Kick)"
    echo "5) STOP Monitor"
    echo "6) TEST NOW (Manual Kick)"
    echo "7) Watch Logs Live"
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
        7) show_logs ;;
        0) exit 0 ;;
    esac
done
