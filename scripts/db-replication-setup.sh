#!/bin/bash
if [ "${MYSQL_REPLICATION_ROLE}" == "" ]; then
    exit;
fi

if [ "${MYSQL_REPLICATION_ROLE}" == "master" ]; then
    # create and prepare a backup for the slave
    if [ "$1" != "" ]; then
        # backup database
        xtrabackup --backup --user=root --password=${MYSQL_ROOT_PASSWORD} --target-dir=$1

        # prepare backup
        xtrabackup --prepare --user=root --password=${MYSQL_ROOT_PASSWORD} --target-dir=$1
    else
        echo "No xtrabackup backup files was created, are you sure you know what you are doing?"
    fi

    # TODO: check if user already exists
    mysql --user=root --password=${MYSQL_ROOT_PASSWORD} -e "GRANT REPLICATION SLAVE ON *.*  TO 'replication'@'%' IDENTIFIED BY 'noitacilper';"
elif [ "${MYSQL_REPLICATION_ROLE}" == "slave" ]; then
    if [ -f /var/lib/mysql/xtrabackup_binlog_info ]; then
        export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}

        # ...
        cat /var/lib/mysql/xtrabackup_binlog_info

        # ...
        read -p 'Enter master log file name (eg. "mysql-bin.000003"): ' masterFile

        # ...
        read -p 'Enter master log pos (eg. "143"): ' masterPos

        # ...
        read -p 'Enter master host (eg. "10.21.50.1"): ' masterHost

        # ...
        mysql --user=root -e "STOP SLAVE;"

        # ...
        mysql --user=root -e "CHANGE MASTER TO MASTER_HOST='${masterHost}', MASTER_USER='replication', MASTER_PASSWORD='noitacilper', MASTER_LOG_FILE='${masterFile}', MASTER_LOG_POS=${masterPos};"

        # ...
        mysql --user=root -e "START SLAVE;"

        # ...
        sleep 5

        # ...
        db-replication-status
    else
        echo "Did you forget to mount the xtrabackup files?"
    fi
fi
