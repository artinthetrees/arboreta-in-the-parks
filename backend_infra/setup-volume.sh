#!/bin/bash
# 1. Wait until the host block storage driver registers /dev/xvdf
while [ ! -b /dev/xvdf ]; do sleep 1; done

# 2. Check if a filesystem already exists (prevents formatting if re-attaching a used disk)
if ! blkid /dev/xvdf; then
  mkfs -t ext4 /dev/xvdf
fi

# 3. Generate the directory mount target
mkdir -p /mnt/postgres_data
mount /dev/xvdf /mnt/postgres_data

# 4. Safely pull the volume's unique UUID to construct the fstab layout
UUID=$(blkid -s UUID -o value /dev/xvdf)

# 5. Configure fstab persistence so it re-mounts on unexpected instance reboots
echo "UUID=${UUID} /mnt/postgres_data ext4 defaults,nofail 0 2" >> /etc/fstab