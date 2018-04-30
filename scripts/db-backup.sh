#!/bin/bash
BACKUP_DIR=$1

# ...
if [ "${BACKUP_DIR}" == "" ]; then
    echo "You must provide a path to backup dir"
    exit 1;
fi

db-backup-innobackupex "${BACKUP_DIR}/innobackupex"
db-backup-sql "${BACKUP_DIR}/sql"
