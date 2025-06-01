#!/bin/bash

# Cấu hình các đường dẫn
SRC_DIR="/home/pm3/cdpd/be-media/media-data"
BACKUP_DIR="/home/pm3/cdpd/backup/new/backup"
RESTORE_DIR="/home/pm3/cdpd/backup/new/restore"
TMP_DIR="$BACKUP_DIR/tmp"
RETENTION_DAYS=7
FULL_BACKUP_DAY=11    # Thử nghiệm tạo backup đầy đủ mỗi ngày
LOG_FILE="$BACKUP_DIR/incremental_backup.log"

# Lấy ngày và giờ hiện tại
CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M")
BACKUP_SUBDIR="$BACKUP_DIR/backup_$CURRENT_DATE"  # Thư mục riêng cho backup
SNAPSHOT_FILE="$BACKUP_SUBDIR/snapshot.snar"
INCR_BACKUP_FILE="$BACKUP_SUBDIR/incr_backup.tar.gz"

# Ghi log
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# giữ lại
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

# giữ lại
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
    # echo "$(find "$TMP_DIR" -type f | wc -l)"
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

# Thực hiện backup
perform_backup() {
    # echo $(find $BACKUP_DIR -type f -name "incr_backup_*.tar.gz")
    # mkdir -p "$BACKUP_SUBDIR"  # Tạo thư mục cho backup

    # Kiểm tra xem đã có full backup nào chưa
    if [ ! -f "$(ls ./backup/full_backup_*.tar.gz 2>/dev/null | head -n 1)" ]; then
        log "No full backup found. Creating the first full backup..."
        # tar -czf "./backup/full_backup_$CURRENT_DATE.tar.gz" -C "$TMP_DIR" . || {
        #     log "Error: Initial full backup failed."
        #     exit 1
        # }
        full_backup $TMP_DIR
        return 0
    fi

    if [ $(( $((10#$(date +"%H"))) % $FULL_BACKUP_DAY )) -eq 0 ] && \
    [ $(find $BACKUP_DIR -type f -name "incr_backup_*.tar.gz" | wc -l) -ge $RETENTION_DAYS ]; then
        # check full backup co ton tai khong
        # if [ -e "./backup/full_backup.gz" ]; then
        #     log "Full backup..."
        #     full_backup $TMP_DIR
        # else
        restore_backup

        full_backup $RESTORE_DIR

        # Xóa snapshot cũ
        log "Deleting old snapshot..."
        rm -f "./backup/snapshot.snar" || {
            log "Error: Failed to delete old snapshot."
            exit 1
        }

        incremental_backup
        # fi

    else
        incremental_backup
    fi
}


# Áp dụng chính sách lưu trữ
apply_retention_policy() {
    log "Applying retention policy. Rotation backup: $RETENTION_DAYS"
    # xoá các bản full backup cũ và chỉ để bản fullbackup mới nhất
    ls ./backup/full_backup_*.tar.gz 2>/dev/null | sort | head -n -1 | xargs -r rm -f

    # xoá các bản incremental có thời gian là 7 ngày về trước
    find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type f -mtime +$RETENTION_DAYS -exec rm -rf {} \;
    log "Old backups removed successfully: $BACKUP_DIR"
}

# Main Logic
log "Backup process started."
check_disk_space
sync_to_tmp
perform_backup
apply_retention_policy
log "Backup process completed successfully."
echo "=====================================================" >> $LOG_FILE
