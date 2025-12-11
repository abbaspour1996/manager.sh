#!/bin/bash

# ==========================================
# Script Name: The Punisher v2.0 (Debug Mode)
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

# ایجاد فایل‌ها
touch "$USER_LIST"
touch "$LOG_FILE"

header() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}       XPanel User Manager v2.0 (Debug Mode)        ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo ""
}

# تابع لاگ‌نویسی
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
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
             log_action "Added user: $username"
        fi
    else
        echo -e "${RED}User '$username' not found on server!${NC}"
    fi
    sleep 2
}

remove_user() {
    header
    echo -e "${GREEN}Removing User${NC}"
    cat -n "$USER_LIST"
    echo "----------------"
    read -p "Enter Username to remove: " selection
    sed -i "/^$selection$/d" "$USER_LIST"
    echo -e "${GREEN}Removed $selection${NC}"
    log_action "Removed user: $selection"
    sleep 2
}

# تابع اصلی کشتن (با لاگ دقیق)
kill_logic() {
    if [ -s "$USER_LIST" ]; then
        while IFS= read -r user; do
            # پیدا کردن پروسه‌های یوزر
            PIDS=$(pgrep -u "$user")
            
            if [ ! -z "$PIDS" ]; then
                echo "Found active processes for $user: $PIDS" >> "$LOG_FILE"
                
                # تلاش اول: pkill استاندارد
                pkill -KILL -u "$user" 2>> "$LOG_FILE"
                
                # تلاش دوم: کشتن مستقیم PID ها
                echo "$PIDS" | xargs -r kill -9 2>> "$LOG_FILE"
                
                # تلاش سوم: کشتن نشست‌های SSH خاص
                ps aux | grep "sshd: $user" | awk '{print $2}' | xargs -r kill -9 2>> "$LOG_FILE"
                
                log_action "KICKED user: $user | PIDs: $PIDS"
            else
                # اگر پروسه‌ای پیدا نشه توی لاگ نمینویسیم که شلوغ نشه (مگر در حالت تست)
                :
            fi
        done < "$USER_LIST"
    else
        echo "List is empty." >> "$LOG_FILE"
    fi
}

# تست دستی (همین الان چک کن)
test_run() {
    header
    echo -e "${YELLOW}Running a SINGLE TEST now...${NC}"
    echo "Checking users in list..."
    
    if [ ! -s "$USER_LIST" ]; then
        echo -e "${RED}List is empty! Add a user first.${NC}"
        read -p "Press Enter..."
        return
    fi

    while IFS= read -r user; do
        echo -e "Checking user: ${CYAN}$user${NC}"
        
        # نشان دادن پروسه‌های فعال یوزر
        USER_PIDS=$(pgrep -u "$user")
        if [ ! -z "$USER_PIDS" ]; then
            echo -e "${RED}Found PIDs: $USER_PIDS${NC}"
            echo -e "Processes:"
            ps -fp $USER_PIDS
            
            echo -e "${YELLOW}Attempting to KILL...${NC}"
            kill -9 $USER_PIDS
            pkill -KILL -u "$user"
            
            sleep 1
            # چک کردن مجدد
            if pgrep -u "$user" > /dev/null; then
                echo -e "${RED}FAILED to kill $user (Processes still active).${NC}"
            else
                echo -e "${GREEN}SUCCESS! User $user kicked.${NC}"
            fi
        else
            echo -e "${GREEN}User $user is NOT online (No active processes).${NC}"
        fi
        echo "--------------------------------"
    done < "$USER_LIST"
    
    echo -e "Check finished."
    read -p "Press Enter to return..."
}

# پروسه بک‌گراند
start_punishment() {
    if [ -f "$PID_FILE" ]; then
        echo "Already running."
        sleep 1
        return
    fi
    
    log_action "STARTED Punishment Loop"
    nohup bash -c "while true; do
        source $0 # Reload script functions if needed (simplified here)
        # Re-defining kill logic inside subshell or calling external isn't needed if we put logic here
        
        if [ -s $USER_LIST ]; then
            while IFS= read -r user; do
                PIDS=\$(pgrep -u \"\$user\")
                if [ ! -z \"\$PIDS\" ]; then
                   echo \"Found \$user with PIDS: \$PIDS\" >> $LOG_FILE
                   kill -9 \$PIDS 2>/dev/null
                   pkill -KILL -u \"\$user\"
                   # Kill specific SSHD sessions
                   ps -ef | grep \"sshd: \$user\" | awk '{print \$2}' | xargs -r kill -9
                fi
            done < $USER_LIST
        fi
        sleep 120
    done" >/dev/null 2>&1 &
    
    echo $! > "$PID_FILE"
    echo -e "${GREEN}Punishment Started (Check logs for details).${NC}"
    sleep 2
}

stop_punishment() {
    if [ -f "$PID_FILE" ]; then
        kill $(cat "$PID_FILE")
        rm "$PID_FILE"
        echo -e "${GREEN}Stopped.${NC}"
        log_action "STOPPED Punishment Loop"
    fi
    sleep 1
}

show_logs() {
    clear
    echo -e "${YELLOW}Last 20 lines of Log File:${NC}"
    echo "---------------------------------"
    if [ -f "$LOG_FILE" ]; then
        tail -n 20 "$LOG_FILE"
    else
        echo "No logs yet."
    fi
    echo "---------------------------------"
    echo -e "Press ${RED}Ctrl+C${NC} to exit logs, or wait..."
    read -p "Press Enter to return menu..."
}

# منو
while true; do
    header
    if [ -f "$PID_FILE" ]; then
        echo -e "Status: ${RED}ACTIVE${NC}"
    else
        echo -e "Status: ${GREEN}INACTIVE${NC}"
    fi
    
    echo "1) Add User (Diakoone)"
    echo "2) Remove User"
    echo "3) Show List"
    echo "4) START Loop (Every 2 min)"
    echo "5) STOP Loop"
    echo "6) TEST NOW (Run once & Debug)"
    echo "7) Show Logs"
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
