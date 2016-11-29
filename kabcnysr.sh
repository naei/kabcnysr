#!/bin/bash

# script for a rsync incremental local backup every day
#
# for the last week:    keep one backup by day
# for the last month:   keep one backup by week
# for the last year:    keep one backup by month

# return the number of folders in a directory
dir_count(){
    echo $(find $1/. -mindepth 1 -type d | wc -l)
}

# return the first folder when ordered alphabetically
# as our backups folders are named by YEAR|MONTH|DAY, the first one will be the oldest one
get_first_dir(){
    echo $(cd $1 && ls -d */ | sort -n | head -1)
}

# incremental sync
do_backup(){
    rsync \
    --archive           \
    --progress          \
    --verbose           \
    --one-file-system   \
    --delete            \
    --numeric-ids       \
    --link-dest=$1/latest $2 $3/$NOW
    unlink $3/latest
    ln -s $3/$NOW $3/latest
}

# check that the source and backup directories are defined
if (( $# == 2 )); then
    SOURCE=$1
    DEST=$2
    if [[ ! -d $SOURCE || ! -d $DEST ]]; then
        if [[ ! -d $SOURCE ]]; then
            printf "Invalid directory: $SOURCE\n"
        fi
        if [[ ! -d $DEST ]]; then
            printf "Invalid directory: $DEST\n"
        fi
        exit 1
    fi
else
    printf "Invalid arguments\nUsage: kabcnysr.sh [SOURCE-DIR] [BACKUP-DIR]\n"
    exit 1
fi

# current date UTC
NOW_YEAR=$(date -u +%Y)
NOW_MONTH=$(date -u +%m)
NOW_DAY=$(date -u +%d)
NOW_WEEKDAY=$(date -u +%u)
NOW=$NOW_YEAR$NOW_MONTH$NOW_DAY
# backups categories
PATH_DAILY=$DEST/daily
PATH_WEEKLY=$DEST/weekly
PATH_MONTHLY=$DEST/monthly

# create the directories if not exists
mkdir -p $PATH_DAILY $PATH_WEEKLY $PATH_MONTHLY

# daily backup
printf "\n>> Running daily backup\n"
do_backup $PATH_DAILY $SOURCE $PATH_DAILY
# do not keep more than the 7 last days
if [ $(dir_count $PATH_DAILY/.) -gt 7 ]; then
    DAILY_OLDEST=$(get_first_dir $PATH_DAILY)
    rm -rf $PATH_DAILY/$WEEKLY_OLDEST
fi

# weekly backup on Sunday
if [[ $NOW_WEEKDAY -eq 0 ]]; then
    printf "\n>> Running weekly backup\n"
    do_backup $PATH_DAILY $PATH_DAILY/$NOW/. $PATH_WEEKLY
    # do not keep more than the 4 last weeks
    if [ $(dir_count $PATH_WEEKLY/.) -gt 4 ]; then
        WEEKLY_OLDEST=$(get_first_dir $PATH_WEEKLY)
        rm -rf $PATH_WEEKLY/$WEEKLY_OLDEST
    fi
fi

# monthly backup on the 1st day of the month
if [[ $NOW_DAY -eq 01 ]]; then
    printf "\n>> Running monthly backup\n"
    do_backup $PATH_DAILY $PATH_DAILY/$NOW/. $PATH_MONTHLY
    # do not keep more than the 12 last months
    if [ $(dir_count $PATH_MONTHLY/.) -gt 12 ]; then
        MONTHLY_OLDEST=$(get_first_dir $PATH_MONTHLY)
        rm -rf $PATH_MONTHLY/$MONTHLY_OLDEST
    fi
fi
