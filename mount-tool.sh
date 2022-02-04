# Get UUID of /dev/sda1
uuid_var=$(blkid -s UUID -o value /dev/sda1)

# Add to fstab if it is not contained already
if grep -q "$uuid_var" /etc/fstab; then
    echo "/etc/fstab already contains UUID of usb ext4 partition."
else
    echo "Created entry in /etc/fstab."
    echo "UUID=${uuid_var} /mnt/ssd ext4 defaults,nofail 0 0" >> /etc/fstab
fi
