#!/bin/bash
BACKUP_DIR="router-backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backing up router configurations to $BACKUP_DIR..."

for i in {1..13}; do
    echo "Backing up router$i..."
    docker exec clab-frr01-router$i vtysh -c "show running-config" > "$BACKUP_DIR/router$i-config.txt"
done

# Backup topology files
cp *.yml *.clab.yml *.sh "$BACKUP_DIR/" 2>/dev/null || true

echo "Backup completed in $BACKUP_DIR"
ls -la "$BACKUP_DIR"