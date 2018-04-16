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
    libpopt0

# percona-xtrabackup from debian repo isn't up-to-date
ADD https://www.percona.com/downloads/XtraBackup/Percona-XtraBackup-2.4.10/binary/debian/jessie/x86_64/percona-xtrabackup-24_2.4.10-1.jessie_amd64.deb /tmp/percona-xtrabackup-24_2.4.10-1.jessie_amd64.deb

# install percona-xtrabackup
RUN dpkg -i /tmp/percona-xtrabackup-24_2.4.10-1.jessie_amd64.deb

# remove install file
RUN rm -rf /tmp/percona-xtrabackup-24_2.4.10-1.jessie_amd64.deb

# copy replication setup script
COPY scripts/replication-setup.sh /replication-setup.sh

# make it executable
RUN chmod +x /replication-setup.sh
