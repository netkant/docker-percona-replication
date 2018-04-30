#!/bin/bash
if [ "${MYSQL_REPLICATION_ROLE}" == "slave" ]; then
    echo "Please create your DB on replication master."
    exit 1;
fi

# ...
if [ "$1" == "" ]; then
    echo "You must provide a DB name"
    exit 1;
fi

# ...
if [ "$2" == "" ]; then
    echo "You must provide a username"
    exit 1;
fi

# ...
if [ "$3" == "" ]; then
    echo "You must provide a password"
    exit 1;
fi

# ...
export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}

# create database, if not already present
mysql --user=root -e "CREATE DATABASE IF NOT EXISTS \`$1\`;"

# create a MySQL user and grants privileges, changes the password if user already exists
mysql --user=root -e "GRANT ALL PRIVILEGES ON \`$1\`.* TO '$2'@'%' IDENTIFIED BY '$3';"

# reloads the privileges from the grant tables in the mysql system database
mysql --user=root -e "FLUSH PRIVILEGES;"
