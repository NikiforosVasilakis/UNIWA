#!/bin/bash

# Σαρωνει καταλογο και αναφερει αρχεια/καταλογους ανα permissions, τροποποιηση/προσπελαση, και δικαιωματα αναγνωσης/γραφης
# Χρηση: searching.sh <οκταδικος_αριθμος_δικαιωματων> <αριθμος_ημερων>

if [ $# -ne 2 ]; then
    echo "Χρηση::: $0 <οκταδικος_αριθμος_δικαιωματων> <αριθμος_ημερων>"
    exit 1
fi

PERMISSIONS=$1
DAYS=$2

# Ελεγχος οτι οι ορισμοι ειναι αριθμοι
if ! [[ "$PERMISSIONS" =~ ^[0-9]+$ ]] || ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
    echo "Σφαλμα::: Και τα δυο ορισματα πρεπει να ειναι ακεραιοι αριθμοι"
    exit 1
fi

# Αρχικοποιηση για τον συνολικο αριθμο
TOTAL_FILES_PERM=0
TOTAL_FILES_MOD=0
TOTAL_DIRS_ACCESS=0
TOTAL_FILES_READ=0
TOTAL_DIRS_WRITE=0

# main loop
while true; do
    # Ζητηση ονοματος Directory
    echo ""
    read -p "Εισαγετε το ονομα του Directory (η 'q' για εξοδο)::: " DIRECTORY
    
    # Ελεγχος εξοδου
    if [ "$DIRECTORY" = "q" ] || [ "$DIRECTORY" = "Q" ]; then
        break
    fi
    
    # Ελεγχος υπαρξης Directory
    if [ ! -d "$DIRECTORY" ]; then
        echo "Σφαλμα::: το directory '$DIRECTORY' δεν υπαρχει"
        continue
    fi
    echo ""
    echo "1. Αρχεια με permissions $PERMISSIONS (οκταδικα):::"
    FILES_PERM=$(find "$DIRECTORY" -type f -perm $PERMISSIONS 2>/dev/null | wc -l)
    echo "   Αριθμος αρχειων::: $FILES_PERM"
    if [ $FILES_PERM -gt 0 ]; then
        find "$DIRECTORY" -type f -perm $PERMISSIONS 2>/dev/null
    fi
    TOTAL_FILES_PERM=$((TOTAL_FILES_PERM + FILES_PERM))
    echo ""
    
    echo "2. Αρχεια που τροποποιηθηκαν τις τελευταιες $DAYS ημερες:::"
    FILES_MOD=$(find "$DIRECTORY" -type f -mtime -$DAYS 2>/dev/null | wc -l)
    echo "   Αριθμος αρχειων::: $FILES_MOD"
    if [ $FILES_MOD -gt 0 ]; then
        find "$DIRECTORY" -type f -mtime -$DAYS 2>/dev/null
    fi
    TOTAL_FILES_MOD=$((TOTAL_FILES_MOD + FILES_MOD))
    echo ""
    
    echo "3. sub-directory που προσπελαστηκαν τις τελευταιες $DAYS ημερες:::"
    
    
    # Εξαιρεση του root directory
    DIRS_ACCESS=$(find "$DIRECTORY" -mindepth 1 -type d -atime -$DAYS 2>/dev/null | wc -l)
    echo "   Αριθμος υποκαταλογων::: $DIRS_ACCESS"
    if [ $DIRS_ACCESS -gt 0 ]; then
        find "$DIRECTORY" -mindepth 1 -type d -atime -$DAYS 2>/dev/null
    fi
    TOTAL_DIRS_ACCESS=$((TOTAL_DIRS_ACCESS + DIRS_ACCESS))
    echo ""
    
    # 4. Αρχεια με δικαιωμα αναγνωσης για ολους τους χρηστες - selected directories only (ls + grep)
    echo "4. Αρχεια με δικαιωμα αναγνωσης για ολους τους χρηστες:::"
    FILES_READ=0
    
    # Ελεγχος αν υπαρχουν αρχεια στο directory
    shopt -s nullglob
    for file in "$DIRECTORY"/*; do
        if [ -f "$file" ]; then
            perms=$(ls -l "$file" 2>/dev/null | awk '{print $1}')
            # Ελεγχος αν owner (pos 2), group (pos 5), others (pos 8) εχουν read permissions
            if [ -n "$perms" ] && [ ${#perms} -ge 9 ]; then
                owner_read="${perms:1:1}"  # Pos 2
                group_read="${perms:4:1}"  # Pos 5
                others_read="${perms:7:1}" # Pos 8
                if [ "$owner_read" = "r" ] && [ "$group_read" = "r" ] && [ "$others_read" = "r" ]; then
                    FILES_READ=$((FILES_READ + 1))
                fi
            fi
        fi
    done
    shopt -u nullglob
    echo "   Αριθμος αρχειων::: $FILES_READ"z
    if [ $FILES_READ -gt 0 ]; then
        shopt -s nullglob
        for file in "$DIRECTORY"/*; do
            if [ -f "$file" ]; then
                perms=$(ls -l "$file" 2>/dev/null | awk '{print $1}')
                if [ -n "$perms" ] && [ ${#perms} -ge 9 ]; then
                    owner_read="${perms:1:1}"
                    group_read="${perms:4:1}"
                    others_read="${perms:7:1}"
                    if [ "$owner_read" = "r" ] && [ "$group_read" = "r" ] && [ "$others_read" = "r" ]; then
                        echo "$file"
                    fi
                fi
            fi
        done
        shopt -u nullglob
    fi
    TOTAL_FILES_READ=$((TOTAL_FILES_READ + FILES_READ))
    echo ""

    # 5. sub-directory με δικαιωμα αλλαγων για αλλους τους χρηστες - only on selected directories (ls + grep)
    echo "5. sub-directory με δικαιωμα αλλαγων για αλλους χρηστες (εκτος ιδιοκτητη):"
    DIRS_WRITE=0
    # Ελεγχος αν υπαρχουν sub-directories στο main directory
    shopt -s nullglob
    for dir in "$DIRECTORY"/*; do
        if [ -d "$dir" ]; then
            perms=$(ls -ld "$dir" 2>/dev/null | awk '{print $1}')
            # Ελεγχος αν 'others' (pos 9) εχουν write permission
            if [ -n "$perms" ] && [ ${#perms} -ge 9 ]; then
                others_write="${perms:8:1}"  # Pos 9 (0-indexed: 8)
                if [ "$others_write" = "w" ]; then
                    DIRS_WRITE=$((DIRS_WRITE + 1))
                fi
            fi
        fi
    done
    shopt -u nullglob
    echo "   Αριθμος υποκαταλογων::: $DIRS_WRITE"
    if [ $DIRS_WRITE -gt 0 ]; then
        shopt -s nullglob
        for dir in "$DIRECTORY"/*; do
            if [ -d "$dir" ]; then
                perms=$(ls -ld "$dir" 2>/dev/null | awk '{print $1}')
                if [ -n "$perms" ] && [ ${#perms} -ge 9 ]; then
                    others_write="${perms:8:1}"
                    if [ "$others_write" = "w" ]; then
                        echo "$dir"
                    fi
                fi
            fi
        done
        shopt -u nullglob
    fi
    TOTAL_DIRS_WRITE=$((TOTAL_DIRS_WRITE + DIRS_WRITE))
    echo ""
done

# Εμφανιση αποτελεσματων
echo ""
echo "=========================================="
echo "ΣΥΝΟΛΙΚΑ ΑΠΟΤΕΛΕΣΜΑΤΑ"
echo "=========================================="
echo ""
echo "1. Συνολικος αριθμος αρχειων με permissions $PERMISSIONS::: $TOTAL_FILES_PERM"
echo "2. Συνολικος αριθμος αρχειων που τροποποιηθηκαν τις τελευταιες $DAYS ημερες: $TOTAL_FILES_MOD"
echo "3. Συνολικος αριθμος υποκαταλογων που προσπελαστηκαν τις τελευταιες $DAYS ημερες: $TOTAL_DIRS_ACCESS"
echo "4. Συνολικος αριθμος αρχειων με δικαιωμα αναγνωσης για ολους::: $TOTAL_FILES_READ"
echo "5. Συνολικος αριθμος υποκαταλογων με δικαιωμα αλλαγων για αλλους::: $TOTAL_DIRS_WRITE"
echo ""
echo "Τελος προγραμματος."

