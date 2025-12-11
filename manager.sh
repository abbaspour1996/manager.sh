#!/bin/bash

# فایل لیست یوزرها
USER_LIST="/root/dayus_users.txt"
touch "$USER_LIST"

# رنگ‌ها
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# هدر
header() {
    clear
    echo -e "${YELLOW}--- XPanel Simple Manager (Native Kill) ---${NC}"
    echo ""
}

# 1. چک کردن و اضافه کردن یوزر
add_user() {
    header
    echo -e "${GREEN}>>> Add User to Auto-Disconnect List <<<${NC}"
    read -p "Enter Username: " username

    # اول چک میکنیم اصلا این بشر توی سرور وجود داره یا نه؟ (استاندارد لینوکس)
    if id "$username" &>/dev/null; then
        if grep -Fxq "$username" "$USER_LIST"; then
             echo -e "${YELLOW}User '$username' is already in the list.${NC}"
        else
             echo "$username" >> "$USER_LIST"
             echo -e "${GREEN}OK. User '$username' added.${NC}"
        fi
    else
        echo -e "${RED}ERROR: User '$username' does NOT exist on this server!${NC}"
        echo "Check your XPanel user list again."
    fi
    sleep 2
}

# حذف یوزر
remove_user() {
    header
    echo -e "${GREEN}>>> Remove User <<<${NC}"
    cat -n "$USER_LIST"
    echo "----------------"
    read -p "Enter Username to remove: " selection
    sed -i "/^$selection$/d" "$USER_LIST"
    echo -e "${GREEN}User '$selection' removed. They are safe now.${NC}"
    sleep 1
}

# لاجیک اصلی (ساده و استاندارد)
# این تابع چک میکنه یوزر آنلاینه یا نه، بعد قطعش میکنه
kill_logic() {
    if [ -s "$USER_LIST" ]; then
        while IFS= read -r user; do
            # چک کردن اینکه آیا یوزر پروسه فعالی داره؟
            # دستور pgrep -u دقیق ترین راه برای فهمیدن آنلاین بودن یوزر لینوکسیه
            if pgrep -u "$user" > /dev/null; then
                # یوزر آنلاینه، پس قطعش میکنیم
                # این دقیقا دستوریه که ادمین‌های لینوکس استفاده میکنن
                killall -u "$user" -9  >/dev/null 2>&1
                pkill -u "$user" -9    >/dev/null 2>&1
                
                # یه لاگ کوچیک که بفهمیم کار کرد
                echo "[$(date +%H:%M:%S)] User '$user' was ONLINE -> KILLED."
            else
                # یوزر آنلاین نیست، کاری نداریم
                # echo "User '$user' is offline."
                :
            fi
        done < "$USER_LIST"
    fi
}

# استارت لوپ ساده (هر 2 دقیقه)
start_loop() {
    echo -e "${GREEN}Starting Auto-Disconnect (Interval: 120s)...${NC}"
    echo "Logs will appear here directly. Press Ctrl+C to stop."
    echo "-----------------------------------------------------"
    
    while true; do
        kill_logic
        sleep 120
    done
}

# منوی ساده
while true; do
    header
    echo "1) Add User (Diakoone)"
    echo "2) Remove User"
    echo "3) Show List"
    echo "4) START (Run & Show Output)"
    echo "0) Exit"
    echo ""
    read -p "Select: " opt

    case $opt in
        1) add_user ;;
        2) remove_user ;;
        3) cat "$USER_LIST"; read -p "..." ;;
        4) start_loop ;; # اینجا دیگه بک گراند نمیره، جلو چشم خودت کار میکنه
        0) exit 0 ;;
        *) echo "Invalid" ;;
    esac
done
