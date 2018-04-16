# Percona with replication on docker

**1: Build docker image**

```
# docker build -t urlund/percona:replication .
```

**2: Start master DB**

```
# docker run -d -e MYSQL_ROOT_PASSWORD=my-secret-pass -e MYSQL_REPLICATION_ROLE=master -v /path/to/mysql/:/var/lib/mysql/ -v /path/to/master.cnf:/etc/mysql/conf.d/master.cnf --name db-master urlund/percona:replication
```

*or, use docker-compose:*

```
# docker-compose up -d db-master
```

**3: Setup replication on master DB**

```
# docker exec -it db-master bash
# ./replication-setup.sh /var/tmp/
```

Example:

```
# ./replication-setup.sh /var/tmp/
180416 15:02:13  version_check Connecting to MySQL server with DSN 'dbi:mysql:;mysql_read_default_group=xtrabackup' as 'root'  (using password: YES).
180416 15:02:13  version_check Connected to MySQL server
180416 15:02:13  version_check Executing a version check against the server...
180416 15:02:13  version_check Done.
... (please wait) ...
180416 15:02:19 completed OK!
```

**4: Sync files to replication slave host**

```
# rsync -a /var/tmp/ root@HOST_IP:/path/to/mysql/
```

**5: Start slave DB**

```
# docker run -d -e MYSQL_ROOT_PASSWORD=my-secret-pass -e MYSQL_REPLICATION_ROLE=slave -v /path/to/slave.cnf:/etc/mysql/conf.d/slave.cnf -v /path/to/mysql/:/var/lib/mysql/ --name db-slave urlund/percona:replication
```

*or, use docker-compose:*

```
# docker-compose up -d db-slave
```

**6: Setup replication on slave DB**

```
# docker exec -it db-slave bash
# ./replication-setup.sh
```

Example:

```
# ./replication-setup.sh
mysql-bin.000003	444
Enter master log file name (eg. "mysql-bin.000003"): mysql-bin.000003
Enter master log pos (eg. "143"): 444
Enter master host (eg. "10.0.1.10"): 10.0.1.10
... (wait 5 sec) ...
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
```
