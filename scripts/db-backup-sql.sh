#!/bin/bash
BACKUP_DIR=$1

# ...
if [ "${BACKUP_DIR}" == "" ]; then
    echo "You must provide a path to backup dir"
    exit 1;
fi

# ...
export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}

# ...
SKIP_DATABASES=(
	Database
	information_schema
	apsc
	performance_schema
)

# ...
SKIP_TABLES=(
    cache_extensions
    cache_hash
    cache_pages
    cache_pagesection
    cache_imagesizes
    cache_md5params
    cache_typo3temp_log
    cache_treelist
    cachingframework_cache_hash
    cachingframework_cache_hash_tags
    cachingframework_cache_pagesection
    cachingframework_cache_pagesection_tags
    cachingframework_cache_pages
    cachingframework_cache_pages_tags
    cf_cache_hash
    cf_cache_hash_tags
    cf_cache_pagesection
    cf_cache_pagesection_tags
    cf_cache_pages
    cf_cache_pages_tags
    cf_cache_rootline
    cf_cache_rootline_tags
    cf_tt_news_cache
    cf_tt_news_cache_tags
    index_fulltext
    index_grlist
    index_phash
    index_rel
    index_section
    index_stat_search
    index_stat_word
    index_words
    index_debug
    sys_log
    tt_news_cache
    tx_realurl_chashcache
    tx_realurl_errorlog
    tx_realurl_pathcache
    tx_realurl_urldecodecache
    tx_realurl_urlencodecache
    tx_varadblog_query
    tx_wtspamshield_log
    tx_devlog
)

# create backupdir
if [ ! -e "$BACKUP_DIR" ]; then
	mkdir -p "$BACKUP_DIR"
fi

# lookup databases
DATABASES=`mysql --batch -e 'show databases' | sed 's/ /%/g'`

# cycle through databases
for DATABASE in ${DATABASES}; do
	# skip database if in SKIP array
	if ! [[ " ${SKIP_DATABASES[@]} " =~ " ${DATABASE} " ]]; then

        # create backupdir
        if [ ! -e "$BACKUP_DIR/${DATABASE}" ]; then
            mkdir -p "$BACKUP_DIR/${DATABASE}"
        fi

		# exclude tables from SKIP_TABLES array
		len=${#SKIP_TABLES[*]}
		EXCLUDE=""
		DATABASE_TABLES=`mysql --batch -D${DATABASE} -e 'show tables' | sed 's/ /%/g'`

        # ...
		for TABLE in $DATABASE_TABLES; do
            i=0
            while [ $i -lt $len ]; do
                    if [ "${TABLE}" = "${SKIP_TABLES[$i]}" ]; then
                        EXCLUDE="$EXCLUDE --ignore-table=${DATABASE}.${TABLE}"
                    fi
                let i++
            done
		done

        # exclude mysql event table
        if [ ${DATABASE} == 'mysql' ]; then
            EXCLUDE="$EXCLUDE --ignore-table=mysql.event"
        fi

		echo 'Dumping:' ${DATABASE}

        # data dump of database with mysqldump and pipe into file (compressed)
        mysqldump --no-create-db --no-create-info $EXCLUDE ${DATABASE} | pigz > $BACKUP_DIR/${DATABASE}/${DATABASE}-`date +%d`-`date +%m`-`date +%y`-`date +%H``date +%M`.sql.gz

		# structure dump of database with mysqldump and pipe into file (compressed)
		mysqldump -d ${DATABASE} | pigz > $BACKUP_DIR/${DATABASE}/${DATABASE}-`date +%d`-`date +%m`-`date +%y`-`date +%H``date +%M`.structureonly.sql.gz

        # delete databases older than 90 days
        find $BACKUP_DIR/${DATABASE} -type f -ctime +90 -print -exec rm -f {} \;
	fi
done
