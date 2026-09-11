# Installing Arch on a new runner box

A copy-paste walkthrough for taking an identical machine (Intel N100 mini PC,
~477 GB SATA SSD, UEFI) from the Arch ISO to the point where
`scripts/bootstrap-arch-runner.sh` takes over. It reproduces the layout of
`builder-linux1` with one simplification, explained at the end.

Target layout:

| Partition / volume | Size | Filesystem | Mount |
|---|---|---|---|
| `/dev/sda1` | 1 GB | FAT32 (EFI System) | `/boot` |
| `/dev/sda2` | rest of disk | LVM physical volume, volume group `volgroup0` | |
| `volgroup0/lv_root` | 100 GB | ext4 | `/` |
| `volgroup0/lv_home` | rest of the VG | ext4 | `/home` |

`builder-linux1` has a 70 GB root. `/nix` lives on root and 70 GB has needed
regular garbage collection, so 100 GB is the recommended size for the new box.
Adjust the `-L 100G` below if you want something else.

**Everything below runs as root from the Arch live ISO and wipes `/dev/sda`.**
Check `lsblk` first and make sure `/dev/sda` is the internal SSD, not the USB
stick.

## 1. Boot the ISO and get online

Boot the USB in UEFI mode. Ethernet comes up on its own.

```bash
cat /sys/firmware/efi/fw_platform_size   # must print 64
ping -c 2 archlinux.org
timedatectl                              # confirm NTP is synchronised
lsblk                                    # confirm /dev/sda is the SSD
```

## 2. Partition, LVM, filesystems

```bash
DISK=/dev/sda
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1G -t1:ef00 -c1:EFI "$DISK"
sgdisk -n2:0:0   -t2:8e00 -c2:LVM "$DISK"

pvcreate "${DISK}2"
vgcreate volgroup0 "${DISK}2"
lvcreate -L 100G     -n lv_root volgroup0
lvcreate -l 100%FREE -n lv_home volgroup0

mkfs.fat -F32 "${DISK}1"
mkfs.ext4 /dev/volgroup0/lv_root
mkfs.ext4 /dev/volgroup0/lv_home

mount /dev/volgroup0/lv_root /mnt
mount --mkdir "${DISK}1" /mnt/boot
mount --mkdir /dev/volgroup0/lv_home /mnt/home
```

## 3. Install the base system

Only what is needed to boot, get online, and clone this repo. The bootstrap
script installs the rest from `pkglist-native.txt`.

```bash
pacstrap -K /mnt base base-devel linux linux-headers linux-lts linux-lts-headers \
    linux-firmware intel-ucode lvm2 grub efibootmgr networkmanager sudo git nano
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

## 4. Configure inside the chroot

Change `HOSTNAME` to the next free `builder-linuxN`.

```bash
HOSTNAME=builder-linux2

ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname

# Same hook set as builder-linux1; lvm2 before filesystems is what matters.
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard keymap sd-vconsole block lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

passwd                                   # root password
useradd -m -G wheel kourtni
passwd kourtni
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

systemctl enable NetworkManager

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
exit
```

## 5. Reboot

```bash
umount -R /mnt
reboot
```

Pull the USB stick when the screen goes blank. Log in as `kourtni`, then
continue from step 2 of [README.md](README.md).

## How this differs from builder-linux1

`builder-linux1` was installed by hand with three partitions: a 1 GB FAT32
partition holding only the GRUB EFI binary, a separate 1 GB ext4 `/boot`, and
the LVM volume. The EFI partition is not in its `fstab` and is not flagged as
an EFI System Partition, which works but makes `grub-install` reruns awkward.
The layout above merges the two into one properly flagged EFI partition
mounted at `/boot`, which is the Arch wiki's standard arrangement. Nothing in
this repo depends on the difference.

`builder-linux1` also has no `intel-ucode` installed. The new box gets it in
`pacstrap`; run `sudo pacman -S intel-ucode && sudo grub-mkconfig -o
/boot/grub/grub.cfg` on the old box to match.
