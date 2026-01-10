#!/bin/bash

# Script backup που δημιουργει αντιγραφο του τρεχοντος καταλογου εργασιας στο /tmp
# Χρηση: bck2 (χωρις ορισματα)
# Προγραμματιζεται με cron καθε Κυριακη βραδυ στις 11μμ για 6 μηνες

# Ελεγχος αριθμου ορισματα
if [ $# -ne 0 ]; then
    echo "Σφαλμα::: Αυτο το script δεν δεχεται ορισματα"
    echo "Χρηση::: $0"
    exit 1
fi

# Ελεγχος υπαρξης καταλογου εργασιας
CURRENT_DIR=$(pwd)
if [ -z "$CURRENT_DIR" ]; then
    echo "Σφαλμα::: Δεν ηταν δυνατη η αναγνωση του τρεχοντος καταλογου"
    exit 1
fi

# Ελεγχος υπαρξης /tmp
if [ ! -d "/tmp" ]; then
    echo "Σφαλμα::: Ο καταλογος /tmp δεν υπαρχει"
    exit 1
fi

# Ελεγχος δικαιωματων εγγραφης στο /tmp
if [ ! -w "/tmp" ]; then
    echo "Σφαλμα::: Δεν υπαρχουν δικαιωματα εγγραφης στο /tmp"
    exit 1
fi

# Δημιουργια ονοματος αρχειου backup με timestamp
BACKUP_NAME="backup_$(basename $CURRENT_DIR)_$(date +%Y%m%d_%H%M%S | tr -d '\n')"
BACKUP_FILE="/tmp/${BACKUP_NAME}.tar.gz"

# Δημιουργια tar backup του τρεχοντος καταλογου
echo "Δημιουργια backup του καταλογου '$CURRENT_DIR'..."
tar -czf "$BACKUP_FILE" . 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Σφαλμα::: Αποτυχια δημιουργιας του backup"
    exit 1
fi

# Ελεγχος υπαρξης του backup αρχειου
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Σφαλμα::: Το backup αρχειο δεν δημιουργηθηκε"
    exit 1
fi

# Εμφανιση πληροφοριων
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "==============================="
echo "Backup ολοκληρωθηκε επιτυχως!"
echo "Τοποθεσια::: $BACKUP_FILE"
echo "Μεγεθος::: $BACKUP_SIZE"
echo "Ημερομηνια::: $(date)"
echo "==============================="
