#!/bin/bash
USAGE="
Usage:
    [OPTIONS] $(basename "$0") BACKUP_PATH
eg.:
    BASE_COUNT=4 INCREMENTAL_COUNT=7 $(basename "$0") /some/backup/path/

OPTIONS:
    BASE_DIR             Name of the directory for the backup 'root' (default: base)
    BASE_COUNT           Number of backups to be stored (default: 12)
    INCREMENTAL_COUNT    Number of incrementals to be taken of each base (default: 7)
    MYSQL_USER           Username used when connecting to the server (default: root)
    MYSQL_HOST           Host to use when connecting to the server (default: localhost)
"

# display usage message if BACKUP_PATH is missing
if [ $# -eq 0 ]; then
    echo "$USAGE"
    exit 412
fi

log() {
    TIMESTAMP=$(date "+%F %T")
    echo "$TIMESTAMP > $1"
}

fatal() {
    log "$1"
    exit 412
}

export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}

log "Starting the backup operation"

# ...
BACKUP_PATH=$(echo $1 | sed 's:/*$::')
CONFIG_FILE="$BACKUP_PATH/backup.cfg"
BASE_DIR="${BASE_DIR:-base}"
MYSQL_USER="${MYSQL_USER:-root}"

# ensure BACKUP_PATH is created
if [ ! -d $BACKUP_PATH ]; then
    mkdir -p $BACKUP_PATH
fi

# if BACKUP_PATH already contains a configuration, use it
if [ -f $CONFIG_FILE ]; then
    if [ -n "$BASE_COUNT" ]; then
        OVERRIDE_BASE_COUNT=$BASE_COUNT
    fi

    if [ -n "$INCREMENTAL_COUNT" ]; then
        OVERRIDE_INCREMENTAL_COUNT=$INCREMENTAL_COUNT
    fi

    log "Backup configuration: $CONFIG_FILE"
    source "$CONFIG_FILE"

    if [ -n "$OVERRIDE_BASE_COUNT" ] && [ $OVERRIDE_BASE_COUNT -ne $BASE_COUNT ]; then
        log "Configuration override: BASE_COUNT changed from $BASE_COUNT to $OVERRIDE_BASE_COUNT"
        BASE_COUNT=$OVERRIDE_BASE_COUNT
    fi

    if [ -n "$OVERRIDE_INCREMENTAL_COUNT" ] && [ $OVERRIDE_INCREMENTAL_COUNT -ne $INCREMENTAL_COUNT ]; then
        log "Configuration override: INCREMENTAL_COUNT changed from $INCREMENTAL_COUNT to $OVERRIDE_INCREMENTAL_COUNT"
        INCREMENTAL_COUNT=$OVERRIDE_INCREMENTAL_COUNT
    fi
fi

# if config file was found, or variables was not set, use default value
if [ -z $BASE_COUNT ]; then
    BASE_COUNT=12
elif [ $BASE_COUNT -le 0 ]; then
    fatal "BASE_COUNT must be greater than 0"
fi

# if config file was found, or variables was not set, use default value
if [ -z $INCREMENTAL_COUNT ]; then
    INCREMENTAL_COUNT=7
elif [ $INCREMENTAL_COUNT -le 0 ]; then
    fatal "INCREMENTAL_COUNT must be greater than 0"
fi

# if no base was read from the config file, define it
if [ -z $BASE ]; then
    BASE=$(date +%Y%m%d%H%M%S)
else
    # if a base was found, check if maximum number of incrementals has been reached, if so, "reset" current state
    if [ ! -d $BACKUP_PATH/$BASE ] || [ $(find $BACKUP_PATH/$BASE/* -maxdepth 0 -type d | wc -l) -ge $INCREMENTAL_COUNT ]; then
        BASE=$(date +%Y%m%d%H%M%S)
        unset INCREMENTAL
    fi
fi

BACKUP_LOG_PATH=$BACKUP_PATH/$BASE

USERNAME="unknown"
if [ -f /etc/gotmpl/data.json ]; then
    USERNAME=$(jq -r .username /etc/gotmpl/data.json)
fi

if [ ! -d $BACKUP_LOG_PATH ]; then
    mkdir -p $BACKUP_LOG_PATH
fi

# if no incremental state has been defined - we need a new base
if [ -z $INCREMENTAL ]; then
    innobackupex --incremental --no-timestamp --user="$MYSQL_USER" "$BACKUP_PATH/$BASE/$BASE_DIR" > $BACKUP_LOG_PATH/${BASE_DIR}.log 2>&1
    if [ $(grep -c "completed OK!" $BACKUP_LOG_PATH/${BASE_DIR}.log) -eq 2 ]; then
        log "Backup completed: $BACKUP_PATH/$BASE/$BASE_DIR"
        log "Backup log: $BACKUP_PATH/$BASE/$BASE_DIR.log"
        INCREMENTAL="$BASE_DIR"
    else
        log "Backup failed: $BACKUP_PATH/$BASE/$BASE_DIR"
        if [ "${SLACK_CHANNEL}" != "" ]; then
            curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"db_backup failed for ${USERNAME}, log path: ${BACKUP_PATH}/${BASE}/${BASE_DIR}.log\"}" ${SLACK_CHANNEL} > /dev/null 2>&1
        fi

        if [ -d $BACKUP_PATH/$BASE/$BASE_DIR ]; then
            rm -rf $BACKUP_PATH/$BASE/$BASE_DIR
        fi
    fi
else
    # check if the incremental we are about to use still exist, if so - make an incremental backup
    if [ -d $BACKUP_PATH/$BASE/$INCREMENTAL ]; then
        NEXT_INCREMENTAL=$(date +%Y%m%d%H%M%S)
        innobackupex --incremental --no-timestamp --user="$MYSQL_USER" "$BACKUP_PATH/$BASE/$NEXT_INCREMENTAL" --incremental-basedir="$BACKUP_PATH/$BASE/$INCREMENTAL" > $BACKUP_LOG_PATH/${NEXT_INCREMENTAL}.log 2>&1

        if [ $(grep -c "completed OK!" $BACKUP_LOG_PATH/${NEXT_INCREMENTAL}.log) -eq 2 ]; then
            log "Backup completed: $BACKUP_PATH/$BASE/$NEXT_INCREMENTAL"
            log "Backup log: $BACKUP_PATH/$BASE/$NEXT_INCREMENTAL.log"
            INCREMENTAL="$NEXT_INCREMENTAL"
        else
            log "Backup failed: $BACKUP_PATH/$BASE/$NEXT_INCREMENTAL"
            if [ "${SLACK_CHANNEL}" != "" ]; then
                curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"db_backup failed for ${USERNAME}, log path: ${BACKUP_PATH}/${BASE}/${NEXT_INCREMENTAL}.log\"}" ${SLACK_CHANNEL} > /dev/null 2>&1
            fi

            if [ -d $BACKUP_PATH/$BASE/$NEXT_INCREMENTAL ]; then
                rm -rf $BACKUP_PATH/$BASE/$NEXT_INCREMENTAL
            fi
        fi
    else
        fatal "Backup error: Cannot use $BACKUP_PATH/$BASE/$INCREMENTAL as --incremental-basedir: No such directory"
    fi
fi

# check if the number of backups have reached the maximum of backups we want to store
while [ $(find $BACKUP_PATH/* -maxdepth 0 -type d | sort | wc -l) -gt $BASE_COUNT ]; do
    # find and delete the oldest base
    OLDEST_BASE=$(find $BACKUP_PATH/* -maxdepth 0 -type d | sort | sed -n 1p)
    if [ -d $OLDEST_BASE/$BASE_DIR ]; then
        log "Backup deleted: $OLDEST_BASE"
        rm -rf $OLDEST_BASE
    fi
done

# save current state and OPTIONS to $CONFIG_FILE
CONFIG="BASE=$BASE\n"
CONFIG="${CONFIG}BASE_COUNT=$BASE_COUNT\n"
CONFIG="${CONFIG}INCREMENTAL=$INCREMENTAL\n"
CONFIG="${CONFIG}INCREMENTAL_COUNT=$INCREMENTAL_COUNT\n"
printf $CONFIG > $CONFIG_FILE

log "Finished the backup operation"
