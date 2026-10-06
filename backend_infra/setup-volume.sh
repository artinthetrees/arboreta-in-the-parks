#!/bin/bash

# 1. Wait until the host block storage driver registers /dev/xvdf
while [ ! -b /dev/xvdf ]; do 
  sleep 1
done

# 2. Check if a filesystem already exists (prevents formatting if re-attaching a used disk)
if ! sudo blkid /dev/xvdf; then
  sudo mkfs -t ext4 /dev/xvdf
fi

# 3. Safely pull the volume's unique UUID FIRST (while unmounted)
UUID=$(sudo blkid -s UUID -o value /dev/xvdf)

# 4. Generate the directory mount target and mount it
sudo mkdir -p /mnt/postgres_data
sudo mount /dev/xvdf /mnt/postgres_data

# 5. Configure fstab persistence ONLY if a valid UUID was successfully fetched
if [ -n "$UUID" ]; then
  echo "UUID=${UUID} /mnt/postgres_data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
else
  # Fallback to the raw device path if UUID resolution failed for some reason
  echo "/dev/xvdf /mnt/postgres_data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi
