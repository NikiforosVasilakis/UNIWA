#!/bin/bash

# backup Script για συγκεκριμενο χρηστη
# Χρηση: bck <username> <source_dir_or_file> <destination_dir_or_file>

# Ελεγχος ορισματων
if [ $# -ne 3 ]; then
    echo "Σφαλμα::: Λαθος αριθμος ορισματων"
    echo "Χρηση::: $0 <username> <source_dir_or_file> <destination_dir_or_file>"
    exit 1
fi

USERNAME=$1
SOURCE=$2
DESTINATION=$3

# Ελεγχος πρωτου ορισματος (username)
if [ -z "$USERNAME" ]; then
    echo "Σφαλμα::: Το username δεν μπορει να ειναι κενο"
    exit 1
fi

# Ελεγχος υπαρξης χρηστη
if ! id "$USERNAME" &>/dev/null; then
    echo "Σφαλμα::: Ο χρηστης '$USERNAME' δεν υπαρχει"
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

# Δημιουργια προσωρινου αρχειου για το tar
TEMP_TAR=$(mktemp /tmp/backup_${USERNAME}_$(date +%Y%m%d_%H%M%S).tar.gz 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Σφαλμα::: Δεν ηταν δυνατη η δημιουργια προσωρινου αρχειου"
    exit 1
fi

# Δημιουργια tar backup
echo "Δημιουργια backup του '$SOURCE'..."
if [ -d "$SOURCE" ]; then
    tar -czf "$TEMP_TAR" "$SOURCE" 2>/dev/null
elif [ -f "$SOURCE" ]; then
    tar -czf "$TEMP_TAR" "$SOURCE" 2>/dev/null
else
    echo "Σφαλμα::: Το source '$SOURCE' δεν ειναι ουτε directory ουτε αρχειο"
    rm -f "$TEMP_TAR"
    exit 1
fi

if [ $? -ne 0 ]; then
    echo "Σφαλμα::: Αποτυχια δημιουργιας του tar backup"
    rm -f "$TEMP_TAR"
    exit 1
fi

# Αντιγραφη η append στο destination
if [ -d "$DESTINATION" ]; then
    # Αν το destination ειναι Directory αντιγραφουμε το tar εκει
    echo "Αντιγραφη backup στο directory '$DESTINATION'..."
    cp "$TEMP_TAR" "$DESTINATION/"
    if [ $? -eq 0 ]; then
        echo "Επιτυχης αντιγραφη στο '$DESTINATION/$(basename $TEMP_TAR)'"
    else
        echo "Σφαλμα::: Αποτυχια αντιγραφης στον καταλογο '$DESTINATION'"
        rm -f "$TEMP_TAR"
        exit 1
    fi
elif [ -f "$DESTINATION" ]; then
    # Αν το destination ειναι αρχειο κανουμε append
    echo "Προσθηκη backup στο αρχειο '$DESTINATION'..."
    cat "$TEMP_TAR" >> "$DESTINATION"
    if [ $? -eq 0 ]; then
        echo "Επιτυχης προσθηκη στο '$DESTINATION'"
    else
        echo "Σφαλμα::: Αποτυχια προσθηκης στο αρχειο '$DESTINATION'"
        rm -f "$TEMP_TAR"
        exit 1
    fi
else
    # Αν το destination δεν υπαρχει ελεγχουμε αν parent directory υπαρχει
    DEST_DIR=$(dirname "$DESTINATION")
    if [ -d "$DEST_DIR" ]; then
        # Αντιγραφουμε ως αρχειο
        echo "Αντιγραφη backup ως αρχειο '$DESTINATION'..."
        cp "$TEMP_TAR" "$DESTINATION"
        if [ $? -eq 0 ]; then
            echo "Επιτυχης αντιγραφη στο '$DESTINATION'"
        else
            echo "Σφαλμα::: Αποτυχια αντιγραφης στο '$DESTINATION'"
            rm -f "$TEMP_TAR"
            exit 1
        fi
    else
        echo "Σφαλμα::: parent directory του destination '$DEST_DIR' δεν υπαρχει"
        rm -f "$TEMP_TAR"
        exit 1
    fi
fi

# Καθαρισμος προσωρινου αρχειου
rm -f "$TEMP_TAR"
echo "==============================================="
echo "Backup ολοκληρωθηκε επιτυχως!"
echo "==============================================="
