#!/bin/bash

LOG_DIR="./imapsync_logs"
SEC_DIR="./.imapsync_secrets"
TRACKER_FILE="$SEC_DIR/active_migrations.txt"

# Create directories and secure the secrets folder
mkdir -p "$LOG_DIR"
mkdir -p "$SEC_DIR"
chmod 700 "$SEC_DIR"
touch "$TRACKER_FILE"

# Variables to remember previous server inputs
DEFAULT_HOST1=""
DEFAULT_HOST2=""

# --- UTILS ---

clean_tracker() {
    # Removes dead processes from the tracker file
    if [ -f "$TRACKER_FILE" ]; then
        temp_file=$(mktemp)
        while IFS="|" read -r pid user logfile; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo "$pid|$user|$logfile" >> "$temp_file"
            fi
        done < "$TRACKER_FILE"
        mv "$temp_file" "$TRACKER_FILE"
    fi
}

# --- FUNCTIONS ---

start_sync() {
    clear
    echo "================================================="
    echo "            START NEW MIGRATION                  "
    echo "================================================="
    
    read -p "Source Server (Host 1) [$DEFAULT_HOST1]: " input_host1
    host1=${input_host1:-$DEFAULT_HOST1}
    DEFAULT_HOST1=$host1

    read -p "Source Email (User 1): " user1
    read -s -p "Source Password (Pass 1): " pass1; echo

    echo "-------------------------------------------------"
    
    read -p "Destination Server (Host 2) [$DEFAULT_HOST2]: " input_host2
    host2=${input_host2:-$DEFAULT_HOST2}
    DEFAULT_HOST2=$host2

    read -p "Destination Email (User 2) [$user1]: " input_user2
    user2=${input_user2:-$user1}
    read -s -p "Destination Password (Pass 2): " pass2; echo

    echo "-------------------------------------------------"
    echo "⏳ Verifying credentials... Please wait."

    safe_user1=$(echo "$user1" | tr '@.' '__')
    passfile1="$SEC_DIR/${safe_user1}_pass1.txt"
    passfile2="$SEC_DIR/${safe_user1}_pass2.txt"

    echo -n "$pass1" > "$passfile1"
    echo -n "$pass2" > "$passfile2"
    chmod 600 "$passfile1" "$passfile2"

    # Pre-flight check
    if imapsync \
        --host1 "$host1" --user1 "$user1" --passfile1 "$passfile1" --ssl1 \
        --host2 "$host2" --user2 "$user2" --passfile2 "$passfile2" --ssl2 \
        --justlogin > /dev/null 2>&1; then
        echo "✅ Credentials verified successfully!"
    else
        echo "❌ Error: Could not log in. Check credentials."
        rm -f "$passfile1" "$passfile2"
        read -n 1 -s -r -p "Press any key to return..."
        return
    fi

    timestamp=$(date +"%Y%m%d_%H%M%S")
    logfile="$LOG_DIR/${safe_user1}_${timestamp}.log"
    echo "🚀 Starting migration..."

    # Command array
    cmd=(
        imapsync
        --host1 "$host1"
        --user1 "$user1"
        --passfile1 "$passfile1"
        --ssl1
        --host2 "$host2"
        --user2 "$user2"
        --passfile2 "$passfile2"
        --ssl2
        --syncinternaldates
        --resyncflags
        --delete2duplicates
        --no-modulesversion
        --errorsmax 100
        --useheader "Message-Id"
        --skipcrossduplicates
    )

    # Start with nohup, detached from terminal, input redirected from /dev/null
    nohup "${cmd[@]}" > "$logfile" 2>&1 < /dev/null &
    pid=$!

    # Add to tracker: PID | User | LogPath
    echo "$pid|$user1|$logfile" >> "$TRACKER_FILE"

    echo "✅ Started! PID: $pid"
    read -n 1 -s -r -p "Press any key to return..."
}

view_active_logs() {
    clean_tracker
    clear
    echo "================================================="
    echo "           VIEW ACTIVE MIGRATION LOGS            "
    echo "================================================="
    
    if [ ! -s "$TRACKER_FILE" ]; then
        echo "No active migrations running."
        read -n 1 -s -r -p "Press any key to return..."
        return
    fi

    # Read tracker into arrays for selection
    options=()
    logfiles=()
    i=0
    
    while IFS="|" read -r pid user logpath; do
        options+=("PID: $pid - $user")
        logfiles+=("$logpath")
        ((i++))
    done < "$TRACKER_FILE"

    echo "Select an ACTIVE migration to view:"
    select opt in "${options[@]}"; do
        if [ -n "$opt" ]; then
            index=$((REPLY-1))
            selected_log="${logfiles[$index]}"
            
            if [ -f "$selected_log" ]; then
                monitor_log "$selected_log"
            else
                echo "Log file not found."
            fi
            break
        else
            echo "Invalid selection."
        fi
    done
}

monitor_log() {
    local logf=$1
    while true; do
        clear
        echo "================================================="
        echo " Live View: $(basename "$logf")"
        echo " 💡 Press 'q' to return to menu."
        echo "================================================="
        tail -n 25 "$logf"
        read -t 1 -n 1 key
        if [[ $key == "q" || $key == "Q" ]]; then break; fi
    done
}

view_all_logs() {
    clear
    echo "================================================="
    echo "              HISTORY (ALL LOGS)                 "
    echo "================================================="
    shopt -s nullglob
    logs=("$LOG_DIR"/*.log)
    if [ ${#logs[@]} -eq 0 ]; then
        echo "No logs found."
        read -n 1 -s -r -p "Return..."
        return
    fi

    select logf in "${logs[@]}"; do
        if [ -n "$logf" ]; then
            less +G "$logf" # Opens at the end of the file
            break
        fi
    done
}

clean_logs() {
    clear
    echo "================================================="
    echo "               CLEANUP LOGS                      "
    echo "================================================="
    read -p "Are you sure you want to delete ALL log files? (y/n): " confirm
    if [[ $confirm == "y" ]]; then
        rm -f "$LOG_DIR"/*.log
        echo "Logs deleted."
    else
        echo "Cancelled."
    fi
    read -n 1 -s -r -p "Return..."
}

# --- MAIN MENU ---

while true; do
    clean_tracker # Update status before showing menu
    active_count=$(wc -l < "$TRACKER_FILE")
    
    clear
    echo "================================================="
    echo "      UNIVERSAL IMAP MIGRATION TOOL (CLI)        "
    echo "================================================="
    echo "  1) Start new migration"
    echo "  2) View ACTIVE logs ($active_count running)"
    echo "  3) View HISTORY (Old/Completed logs)"
    echo "  4) Delete old logs"
    echo "  5) Exit"
    echo "================================================="
    read -p "Choose: " opt

    case $opt in
        1) start_sync ;;
        2) view_active_logs ;;
        3) view_all_logs ;;
        4) clean_logs ;;
        5) exit 0 ;;
        *) echo "Invalid."; sleep 1 ;;
    esac
done
