#!/bin/bash

# Script mfproc - Εμφανιζει πληροφοριες για διεργασιες
# Χρηση: mfproc [-u username] [-s S|R|Z]

# Αρχικοποιηση μεταβλητων
FILTER_USER=""
FILTER_STATE=""
PROCESSES_FOUND=0

# Αναλυση ορισματων
while [[ $# -gt 0 ]]; do
    case $1 in
        -u)
            if [ -z "$2" ]; then
                echo "Σφαλμα: Το -u απαιτει ονομα χρηστη" >&2
                exit 1
            fi
            FILTER_USER="$2"
            shift 2
            ;;
        -s)
            if [ -z "$2" ]; then
                echo "Σφαλμα: Το -s απαιτει κατασταση (R, S, η Z)" >&2
                exit 1
            fi
            FILTER_STATE="$2"
            # Ελεγχος οτι η κατασταση ειναι εγκυρη
            if [[ ! "$FILTER_STATE" =~ ^[RSZ]$ ]]; then
                echo "Σφαλμα: Η κατασταση πρεπει να ειναι R, S, η Z" >&2
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "Σφαλμα: Αγνωστη παραμετρος '$1'" >&2
            echo "Χρηση: $0 [-u username] [-s S|R|Z]" >&2
            exit 1
            ;;
    esac
done

# Ελεγχος υπαρξης χρηστη αν δοθηκε -u
if [ -n "$FILTER_USER" ]; then
    if ! id "$FILTER_USER" &>/dev/null; then
        exit 1  # Δεν υπαρχει ο χρηστης
    fi
    # Ληψη UID του χρηστη
    FILTER_UID=$(id -u "$FILTER_USER" 2>/dev/null)
fi

# Συναρτηση για την αναγνωση της καταστασης απο /proc/PID/stat
get_state() {
    local pid=$1
    if [ -r "/proc/$pid/stat" ]; then
        # Η κατασταση ειναι το 3ο πεδιο στο /proc/PID/stat
        awk '{print $3}' "/proc/$pid/stat" 2>/dev/null
    fi
}

# Συναρτηση για την αναγνωση του ονοματος διεργασιας
get_name() {
    local pid=$1
    if [ -r "/proc/$pid/comm" ]; then
        cat "/proc/$pid/comm" 2>/dev/null | tr -d '\n'
    elif [ -r "/proc/$pid/stat" ]; then
        # Αν δεν υπαρχει comm, διαβαζουμε απο stat (2ο πεδιο, αλλα μπορει να εχει παρενθεσεις)
        awk '{gsub(/[()]/, "", $2); print $2}' "/proc/$pid/stat" 2>/dev/null
    fi
}

# Συναρτηση για την αναγνωση PPID
get_ppid() {
    local pid=$1
    if [ -r "/proc/$pid/stat" ]; then
        awk '{print $4}' "/proc/$pid/stat" 2>/dev/null
    fi
}

# Συναρτηση για την αναγνωση UID
get_uid() {
    local pid=$1
    if [ -r "/proc/$pid/status" ]; then
        grep "^Uid:" "/proc/$pid/status" 2>/dev/null | awk '{print $2}'
    fi
}

# Συναρτηση για την αναγνωση GID
get_gid() {
    local pid=$1
    if [ -r "/proc/$pid/status" ]; then
        grep "^Gid:" "/proc/$pid/status" 2>/dev/null | awk '{print $2}'
    fi
}

# Συναρτηση για την καταμετρηση locked files
count_locked_files() {
    local pid=$1
    local read_locks=0
    local write_locks=0
    
    # Ελεγχος αν υπαρχει ο καταλογος fd
    if [ ! -d "/proc/$pid/fd" ]; then
        echo "0 0"
        return
    fi
    
    # Χρηση lsof αν ειναι διαθεσιμο για ακριβεστερη μετρηση
    if command -v lsof &>/dev/null; then
        # Μετραμε αρχεια με read access (ανοιχτα για αναγνωση)
        read_locks=$(lsof -p "$pid" 2>/dev/null | awk '/REG/ && /r/ {count++} END {print count+0}' || echo "0")
        # Μετραμε αρχεια με write access (ανοιχτα για εγγραφη)
        write_locks=$(lsof -p "$pid" 2>/dev/null | awk '/REG/ && /w/ {count++} END {print count+0}' || echo "0")
    else
        # Εναλλακτικη μεθοδος: ελεγχος των fdinfo
        # Διασχιση των file descriptors
        for fd in /proc/$pid/fd/*; do
            if [ -L "$fd" ]; then
                local fd_num=$(basename "$fd")
                # Ελεγχος αν υπαρχει fdinfo
                if [ -r "/proc/$pid/fdinfo/$fd_num" ]; then
                    # Ελεγχος για read lock (POSIX read lock)
                    if grep -q "lock.*:.*POSIX.*READ" "/proc/$pid/fdinfo/$fd_num" 2>/dev/null; then
                        read_locks=$((read_locks + 1))
                    fi
                    # Ελεγχος για write lock (POSIX write lock)
                    if grep -q "lock.*:.*POSIX.*WRITE" "/proc/$pid/fdinfo/$fd_num" 2>/dev/null; then
                        write_locks=$((write_locks + 1))
                    fi
                    # Ελεγχος για FLOCK read
                    if grep -q "flock.*:.*READ" "/proc/$pid/fdinfo/$fd_num" 2>/dev/null; then
                        read_locks=$((read_locks + 1))
                    fi
                    # Ελεγχος για FLOCK write
                    if grep -q "flock.*:.*WRITE" "/proc/$pid/fdinfo/$fd_num" 2>/dev/null; then
                        write_locks=$((write_locks + 1))
                    fi
                fi
            fi
        done
        
        # Αν δεν βρεθηκαν locks, μετραμε τα ανοιχτα αρχεια ως fallback
        if [ $read_locks -eq 0 ] && [ $write_locks -eq 0 ]; then
            # Απλοποιημενη μετρηση: αριθμος ανοιχτων fd
            local total_fds=$(ls -1 /proc/$pid/fd 2>/dev/null | wc -l)
            read_locks=$total_fds
        fi
    fi
    
    echo "$write_locks $read_locks"
}

# Μετατροπη state character σε αναγνωσιμο
state_to_char() {
    local state=$1
    case "$state" in
        R) echo "R" ;;
        S) echo "S" ;;
        D) echo "S" ;;  # Disk sleep, θεωρουμε ως Sleeping
        Z) echo "Z" ;;
        T) echo "S" ;;  # Stopped, θεωρουμε ως Sleeping
        *) echo "S" ;;  # Default
    esac
}

# Εκτυπωση header
printf "%-20s %-8s %-8s %-8s %-8s %-6s %-8s %-8s\n" \
    "Name" "PID" "PPID" "UID" "GID" "State" "WRITE_Locks" "READ_Locks"

# Διασχιση ολων των διεργασιων στο /proc
for pid_dir in /proc/[0-9]*; do
    pid=$(basename "$pid_dir")
    
    # Ελεγχος αν ειναι εγκυρη διεργασια
    if [ ! -d "$pid_dir" ]; then
        continue
    fi
    
    # Αναγνωση πληροφοριων
    name=$(get_name "$pid")
    ppid=$(get_ppid "$pid")
    uid=$(get_uid "$pid")
    gid=$(get_gid "$pid")
    state=$(get_state "$pid")
    state_char=$(state_to_char "$state")
    
    # Ελεγχος φιλτρου καταστασης
    if [ -n "$FILTER_STATE" ]; then
        if [ "$state_char" != "$FILTER_STATE" ]; then
            continue
        fi
    fi
    
    # Ελεγχος φιλτρου χρηστη
    if [ -n "$FILTER_USER" ]; then
        if [ "$uid" != "$FILTER_UID" ]; then
            continue
        fi
    fi
    
    # Αναγνωση locked files
    locks=$(count_locked_files "$pid")
    write_locks=$(echo "$locks" | awk '{print $1}')
    read_locks=$(echo "$locks" | awk '{print $2}')
    
    # Εκτυπωση πληροφοριων
    printf "%-20s %-8s %-8s %-8s %-8s %-6s %-8s %-8s\n" \
        "$name" "$pid" "$ppid" "$uid" "$gid" "$state_char" "$write_locks" "$read_locks"
    
    PROCESSES_FOUND=$((PROCESSES_FOUND + 1))
done

# Ελεγχος επιστρεφομενης τιμης
# Αν δωθηκε -s και δεν βρεθηκαν διεργασιες
if [ -n "$FILTER_STATE" ] && [ $PROCESSES_FOUND -eq 0 ]; then
    exit 2  # Δεν υπαρχει διεργασια σε αυτη την κατασταση
else
    exit 0  # Επιτυχια
fi

