# Get UUID of /dev/sda1
uuid_var=$(blkid -s UUID -o value /dev/sda1)
blkid_line=$(blkid -o list -w /dev/null | grep /dev/sda1)

# Check if /dev/sda1 is an ext4 partition
if [[ $blkid_line == *"ext4"* ]]; then
    echo "/dev/sda1 is ext4 partition. OK."
else
    echo "no ext4 partition found. aborting."
    exit 1
fi

# List all:  blkid -o list -w /dev/null
# Add to fstab if it is not contained already
if grep -q "$uuid_var" /etc/fstab; then
    echo "/etc/fstab already has an entry for this partition. Nothing to be done."
else
    echo "Created entry in /etc/fstab."
    echo "UUID=${uuid_var} /mnt/ssd ext4 defaults,nofail 0 0" >> /etc/fstab
fi

# Mount the device
mount -a
