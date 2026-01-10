#!/bin/bash

# Script backup προγραμματισμενο με at
# Χρηση: bck1 <username> <source_dir_or_file> <destination_dir_or_file> <time>
# Παραδειγμα ωρας: "11:00 PM", "23:00", "now + 1 hour", "tomorrow 11pm"

# Ελεγχος αριθμου ορισματων
if [ $# -ne 4 ]; then
    echo "Σφαλμα::: Λαθος αριθμος ορισματων"
    echo "Χρηση::: $0 <username> <source_dir_or_file> <destination_dir_or_file> <time>"
    echo "Παραδειγμα::: $0 user1 /home/user1/docs /backup/user1_backup.tar.gz '11:00 PM'"
    echo "Η::: $0 user1 /home/user1/docs /backup/user1_backup.tar.gz 'now + 1 hour'"
    exit 1
fi

USERNAME=$1
SOURCE=$2
DESTINATION=$3
TIME=$4

# Ελεγχος πρωτου ορισματος (username)
if [ -z "$USERNAME" ]; then
    echo "Σφαλμα::: Το username δεν μπορει να ειναι κενο"
    exit 1
fi

# Ελεγχος υπαρξης χρηστη
if ! id "$USERNAME" &>/dev/null; then
    echo "Σφαλμα:: Ο χρηστης '$USERNAME' δεν υπαρχει"
    exit 1
fi

# Ελεγχος δευτερου ορισματος (source)
if [ -z "$SOURCE" ]; then
    echo "Σφαλμα::: Το source δεν μπορει να ειναι κενο"
    exit 1
fi

if [ ! -e "$SOURCE" ]; then
    echo "Σφαλμα::: Το source '$SOURCE' δεν υπαρχει"
    exit 1
fi

# Ελεγχος τριτου ορισματος (destination)
if [ -z "$DESTINATION" ]; then
    echo "Σφαλμα::: Το destination δεν μπορει να ειναι κενο"
    exit 1
fi

# Ελεγχος τεταρτου ορισματος (time)
if [ -z "$TIME" ]; then
    echo "Σφαλμα::: Η ωρα δεν μπορει να ειναι κενη"
    exit 1
fi

# Δημιουργια προσωρινου script που θα εκτελεστει απο το at
TEMP_SCRIPT=$(mktemp /tmp/bck1_script_$$.sh 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Σφαλμα::: Δεν ηταν δυνατη η δημιουργια προσωρινου script"
    exit 1
fi

# Καταγραφη του script που θα εκτελεστει
cat > "$TEMP_SCRIPT" << EOF
#!/bin/bash
# Προγραμματισμενο backup script
# Δημιουργηθηκε::: $(date)

USERNAME="$USERNAME"
SOURCE="$SOURCE"
DESTINATION="$DESTINATION"

# Δημιουργια προσωρινου αρχειου για το tar
TEMP_TAR=\$(mktemp /tmp/backup_\${USERNAME}_\$(date +%Y%m%d_%H%M%S).tar.gz 2>/dev/null)
if [ \$? -ne 0 ]; then
    echo "Σφαλμα::: Δεν ηταν δυνατη η δημιουργια προσωρινου αρχειου" >&2
    exit 1
fi

# Δημιουργια tar backup
echo "Δημιουργια backup του '\$SOURCE'..."
if [ -d "\$SOURCE" ]; then
    tar -czf "\$TEMP_TAR" "\$SOURCE" 2>/dev/null
elif [ -f "\$SOURCE" ]; then
    tar -czf "\$TEMP_TAR" "\$SOURCE" 2>/dev/null
else
    echo "Σφαλμα::: Το source '\$SOURCE' δεν ειναι ουτε directory ουτε αρχειο" >&2
    rm -f "\$TEMP_TAR"
    exit 1
fi

if [ \$? -ne 0 ]; then
    echo "Σφαλμα::: Αποτυχια δημιουργιας του tar backup" >&2
    rm -f "\$TEMP_TAR"
    exit 1
fi

# Αντιγραφη η append στο destination
if [ -d "\$DESTINATION" ]; then
    echo "Αντιγραφη backup στον καταλογο '\$DESTINATION'..."
    cp "\$TEMP_TAR" "\$DESTINATION/"
    if [ \$? -eq 0 ]; then
        echo "Επιτυχης αντιγραφη στο '\$DESTINATION/\$(basename \$TEMP_TAR)'"
    else
        echo "Σφαλμα::: Αποτυχια αντιγραφης στον καταλογο '\$DESTINATION'" >&2
        rm -f "\$TEMP_TAR"
        exit 1
    fi
elif [ -f "\$DESTINATION" ]; then
    echo "Προσθηκη backup στο αρχειο '\$DESTINATION'..."
    cat "\$TEMP_TAR" >> "\$DESTINATION"
    if [ \$? -eq 0 ]; then
        echo "Επιτυχης προσθηκη στο '\$DESTINATION'"
    else
        echo "Σφαλμα::: Αποτυχια προσθηκης στο αρχειο '\$DESTINATION'" >&2
        rm -f "\$TEMP_TAR"
        exit 1
    fi
else
    DEST_DIR=\$(dirname "\$DESTINATION")
    if [ -d "\$DEST_DIR" ]; then
        echo "Αντιγραφη backup ως αρχειο '\$DESTINATION'..."
        cp "\$TEMP_TAR" "\$DESTINATION"
        if [ \$? -eq 0 ]; then
            echo "Επιτυχης αντιγραφη στο '\$DESTINATION'"
        else
            echo "Σφαλμα::: Αποτυχια αντιγραφης στο '\$DESTINATION'" >&2
            rm -f "\$TEMP_TAR"
            exit 1
        fi
    else
        echo "Σφαλμα::: parent directory του destination '\$DEST_DIR' δεν υπαρχει" >&2
        rm -f "\$TEMP_TAR"
        exit 1
    fi
fi

# Καθαρισμος προσωρινου αρχειου
rm -f "\$TEMP_TAR"
echo "Backup ολοκληρωθηκε επιτυχως!"
EOF

chmod +x "$TEMP_SCRIPT"

# Προγραμματισμος με at
echo "Προγραμματισμος backup για ωρα::: $TIME"
echo "$TEMP_SCRIPT" | at "$TIME" 2>&1

if [ $? -eq 0 ]; then
    echo "==============================================="
    echo "Το backup εχει προγραμματιστει επιτυχως!"
    echo "Το προσωρινο script θα διαγραφει αυτοματα μετα την εκτελεση."
    echo "==============================================="
    # Προσθηκη εντολης διαγραφης του script στο τελος
    echo "rm -f $TEMP_SCRIPT" | at "$TIME" 2>/dev/null
else
    echo "==============================================="
    echo "Σφαλμα::: Αποτυχια προγραμματισμου με at"
    echo "==============================================="
    rm -f "$TEMP_SCRIPT"
    exit 1
fi

