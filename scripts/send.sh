#!/bin/sh
PC=192.168.1.2
PORT=9000
i=0
for mtd in boot boot-env factory config isp_config rom_file cloud radio config_bak firmware kernel rootfs rootfs_data; do
  echo "==> Sending mtd${i} (${mtd})..."
  dd if=/dev/mtd${i} 2>/dev/null | nc $PC $PORT
  i=$((i+1))
  sleep 1
done
echo "All MTDs sent."
