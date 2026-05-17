#!/bin/bash
# Run on PC. Listens for each MTD partition sent by send_dumps.sh on the router.
# Usage: ./scripts/receive_dumps.sh

set -e

DUMPS_DIR="$(dirname "$0")/../dumps"
mkdir -p "$DUMPS_DIR"
cd "$DUMPS_DIR"

PARTITIONS=(boot boot-env factory config isp_config rom_file cloud radio config_bak firmware kernel rootfs rootfs_data)

for i in $(seq 0 12); do
    name="${PARTITIONS[$i]}"
    file="mtd${i}_${name}.bin"
    echo "==> [$((i+1))/13] Waiting for mtd${i} (${name})..."
    nc -l -p 9000 > "$file"
    size=$(wc -c < "$file")
    echo "    Received: $file ($size bytes)"
done

echo ""
echo "All done. Files in $DUMPS_DIR:"
ls -lh "$DUMPS_DIR"/*.bin
