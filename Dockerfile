FROM percona:latest

# update repositories
RUN apt-get update

# install percona-xtrabackup requirements
RUN apt-get install -y \
    libdbd-mysql-perl \
    rsync \
    libcurl3 \
    libev4 \
    libmysqlclient18 \
    libdbi-perl \
    libpopt0 \
    pigz \
    curl

# percona-xtrabackup from debian repo isn't up-to-date
ADD https://www.percona.com/downloads/XtraBackup/Percona-XtraBackup-2.4.10/binary/debian/jessie/x86_64/percona-xtrabackup-24_2.4.10-1.jessie_amd64.deb /tmp/percona-xtrabackup-24_2.4.10-1.jessie_amd64.deb

# install percona-xtrabackup and remove install file
RUN dpkg -i /tmp/percona-xtrabackup-24_2.4.10-1.jessie_amd64.deb
RUN rm -rf /tmp/percona-xtrabackup-24_2.4.10-1.jessie_amd64.deb

# copy scripts to sbin
COPY scripts/db-backup-innobackupex.sh /usr/local/sbin/db-backup-innobackupex
COPY scripts/db-backup-sql.sh          /usr/local/sbin/db-backup-sql
COPY scripts/db-backup.sh              /usr/local/sbin/db-backup
COPY scripts/db-create-update.sh       /usr/local/sbin/db-create-update
COPY scripts/db-replication-setup.sh   /usr/local/sbin/db-replication-setup
COPY scripts/db-replication-status.sh  /usr/local/sbin/db-replication-status

# make sure they are executable
RUN chmod +x /usr/local/sbin/db-*
