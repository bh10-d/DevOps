#!/bin/bash

# Khóa file để tránh chạy nhiều phiên bản script cùng lúc
LOCKFILE="/tmp/backup.lock"

if [ -f $LOCKFILE ]; then
  echo "Backup process already running. Exiting..."
  exit 1
fi


# Tạo file lock
touch $LOCKFILE
trap "rm -f $LOCKFILE; exit" INT TERM EXIT

# Kiểm tra các tham số đầu vào
C_NAME=$1
DB_USER=$2

if [ -z "$C_NAME" ] || [ -z "$DB_USER" ]; then
    echo "Error: Missing arguments."
    echo "Usage: $0 <container_name> <db_user>"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^$C_NAME\$"; then
    echo "Error: Docker container $C_NAME is not running."
    rm -f $LOCKFILE
    exit 1
fi

# Thư mục đích để lưu trữ backup
ROOT_PATH="/home/pm3/cdpd/backup/postgres"
TMP_DIR="$ROOT_PATH/tmp"

# Backup logging
LOG_FILE="$ROOT_PATH/backup.log"

# Tạo tên file backup với timestamp
TIMESTAMP=$(date +"%Y-%m-%d")
BACKUP_NAME="backup_$TIMESTAMP.tar.gz"

# Số lượng bản backup cần giữ lại
BACKUP_RETAIN_COUNT=7

# Ensure backup root directory and temp directory exist
mkdir -p $ROOT_PATH
mkdir -p $TMP_DIR

# Xóa các file cũ trong thư mục tạm
rm -rf $TMP_DIR/*


log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" >> $LOG_FILE
}


# Ghi log bắt đầu backup
log "Starting database backup for $TIMESTAMP"

# Lấy danh sách database cần backup
docker exec $C_NAME psql -U $DB_USER -d template1 -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('template1', 'postgres', 'template0');" > $ROOT_PATH/db_list.txt
sed -i 's/^[ \t]*//;s/[ \t]*$//' $ROOT_PATH/db_list.txt
sed -i '/^[[:space:]]*$/d' $ROOT_PATH/db_list.txt

#test

# Biến đếm số lượng lệnh đang chạy
max_concurrent_jobs=8
current_jobs=0

# Thực hiện backup từng database trong nền, tối đa 8 lệnh một lần
while read dbname; do
    {
        docker exec $C_NAME pg_dump -U $DB_USER "$dbname" > "$TMP_DIR/${dbname}_$TIMESTAMP.sql"
        if [ $? -ne 0 ]; then
            log "Error backing up database: $dbname"
        fi
    } &  # Chạy trong nền

    current_jobs=$((current_jobs + 1))

    # Nếu đạt giới hạn 8 lệnh, chờ các lệnh hiện tại hoàn tất
    if [[ $current_jobs -ge $max_concurrent_jobs ]]; then
        wait  # Chờ tất cả các lệnh nền hiện tại hoàn tất
        current_jobs=0  # Đặt lại bộ đếm
    fi
done < $ROOT_PATH/db_list.txt

# Chờ các lệnh còn lại sau vòng lặp hoàn tất
wait

# Tạo file tar.gz cho backup
tar -czvf $ROOT_PATH/$BACKUP_NAME $TMP_DIR
if [ $? -eq 0 ]; then
    log "Backup $BACKUP_NAME created successfully"
else
    log "Error creating backup archive"
    rm -f $LOCKFILE
    exit 1
fi

# Xóa thư mục tạm sau khi backup
rm -rf $TMP_DIR/*

# Xoay vòng backup, giữ lại $BACKUP_RETAIN_COUNT bản gần nhất
find $ROOT_PATH -name "backup_*.tar.gz" -mtime +$BACKUP_RETAIN_COUNT -exec rm -f {} \;

if [ $? -eq 0 ]; then
    log "Old backups cleaned up successfully"
else
    log "Error during backup rotation"
fi

#end test

# Xóa file lock khi hoàn thành
# rm -f $LOCKFILE

# Ghi log kết thúc
echo "=====================================================" >> $LOG_FILE
