#!/bin/bash

# Cấu hình các đường dẫn
SRC_DIR="/home/pm3/cdpd/be-media/media-data"
BACKUP_DIR="/home/pm3/cdpd/backup/new/backup"
RESTORE_DIR="/home/pm3/cdpd/backup/new/restore"
TMP_DIR="$BACKUP_DIR/tmp"
RETENTION_DAYS=7
LOG_FILE="$BACKUP_DIR/incremental_backup.log"

# Lấy ngày và giờ hiện tại
CURRENT_DATE=$(date +"%Y-%m-%d")
BACKUP_SUBDIR="$BACKUP_DIR/backup_$CURRENT_DATE"  # Thư mục riêng cho backup
SNAPSHOT_FILE="$BACKUP_SUBDIR/snapshot.snar"
INCR_BACKUP_FILE="$BACKUP_SUBDIR/incr_backup.tar.gz"

# Ghi log
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Đo thời gian chạy
time_elapsed() {
    local start_time=$1
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    echo "$elapsed"
}

# Kiểm tra dung lượng đĩa
check_disk_space() {
    local required_space=$(du -s "$SRC_DIR" | awk '{print $1}') # Kích thước tính bằng KB (blocks 1K)
    local available_space=$(df "$BACKUP_DIR" --output=avail -k | tail -n1) # Dung lượng trống tính bằng KB

    log "Available space: $available_space KB."

    if [ "$available_space" -lt $((required_space * 5)) ]; then
        log "Error: Not enough disk space. Required: $((required_space * 5)) KB, Available: $available_space KB."
        exit 1
    fi
}

# Đồng bộ dữ liệu vào thư mục tạm
sync_to_tmp() {
    log "Syncing data to temporary directory: $TMP_DIR"
    mkdir -p "$TMP_DIR"
    rsync -a --delete "$SRC_DIR/" "$TMP_DIR/"
    if [ $? -ne 0 ]; then
        log "Error: Sync to temporary directory failed."
        exit 1
    fi
    log "Sync to temporary directory completed successfully."
}

# tạo full backup
full_backup() {
    tar -czf "$BACKUP_DIR/full_backup_$CURRENT_DATE.tar.gz" -C $1 . || {
        log "Error: Initial full backup failed."
        exit 1
    }
}

# tạo incre backup
incremental_backup() {
    log "Performing incremental backup..."
    tar --listed-incremental="$BACKUP_DIR/snapshot.snar" -czf "$BACKUP_DIR/incr_backup_$CURRENT_DATE.tar.gz" -C "$TMP_DIR" . || {
        log "Error: Incremental backup failed."
        exit 1
    }
    log "New backup incremental file: $BACKUP_DIR/incr_backup_$CURRENT_DATE.tar.gz"
}

restore_backup() {
    log "Full Backup Exist."
    log "Restoring from full backup and incremental backups..."
    mkdir -p "$RESTORE_DIR"
    local LATEST_FULL_BACKUP=$(ls $BACKUP_DIR/full_backup_*.tar.gz 2>/dev/null | sort | tail -n 1)

    tar -xzf $LATEST_FULL_BACKUP -C "$RESTORE_DIR" || {
        log "Error: Full backup restore failed."
        exit 1
    }

    for incr_file in $(ls $BACKUP_DIR/incr_backup_*.tar.gz | sort); do
        log "Restoring from $incr_file"
        tar --incremental -xzf "$incr_file" -C "$RESTORE_DIR" || {
            log "Error: Incremental backup restore failed for $incr_file."
            exit 1
        }
    done
}

# Áp dụng chính sách lưu trữ
remove_all_incr_backup() {
    log "Deleting old incremental backups..."
    # xoá các bản full backup cũ và chỉ để bản fullbackup mới nhất
    ls $BACKUP_DIR/full_backup_*.tar.gz 2>/dev/null | sort | head -n -1 | xargs -r rm -f

    # xoá các bản incremental sau khi đã restore và tạo bản full backup mới
    ls $BACKUP_DIR/incr_backup_*.tar.gz 2>/dev/null | xargs -r rm -f
    log "Old incremental backups removed successfully: $BACKUP_DIR"
}

# Thực hiện backup
perform_backup() {
    # Kiểm tra xem đã có full backup nào chưa
    if [ ! -f "$(ls $BACKUP_DIR/full_backup_*.tar.gz 2>/dev/null | head -n 1)" ]; then
        log "No full backup found. Creating the first full backup..."
        full_backup $TMP_DIR
        return 0
    fi

    if [ $(find $BACKUP_DIR -type f -name "incr_backup_*.tar.gz" | wc -l) -eq $RETENTION_DAYS ] || [ $(find $BACKUP_DIR -type f -name "incr_backup_*.tar.gz" | wc -l) -ge    $RETENTION_DAYS ]; then
        restore_backup
        full_backup $RESTORE_DIR

        # Xóa snapshot cũ
        log "Deleting old snapshot..."
        rm -f "$BACKUP_DIR/snapshot.snar" || {
            log "Error: Failed to delete old snapshot."
            exit 1
        }
        log "Old snapshot removed successfully"


        # Xoá các bản incremental cũ
        remove_all_incr_backup

        incremental_backup
    else
        incremental_backup
    fi
}

# Main Logic
log "Backup process started."
start_time=$(date +%s)
check_disk_space
sync_to_tmp
perform_backup
end_time=$(date +%s) # Lấy thời gian kết thúc
elapsed=$((end_time - start_time)) # Tính thời gian chạy
log "Backup process completed successfully in ${elapsed}s."
echo "=====================================================" >> $LOG_FILE