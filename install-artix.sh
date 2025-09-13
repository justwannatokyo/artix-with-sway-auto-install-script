#!/bin/bash
set -e

# === НАСТРОЙКИ ===
DISK_ROOT="/dev/sda3"       # КУДА ставим Artix root
EFI_MNT="/boot/efi"
HOSTNAME="artix-sway"
USERNAME="justwannatokyo"
LOCALE="en_US.UTF-8"
TIMEZONE="Europe/Moscow"

# === МОНТИРУЕМ ФАЙЛОВЫЕ СИСТЕМЫ ===
mkfs.ext4 -L ARTIX "$DISK_ROOT"
mount "$DISK_ROOT" /mnt

mkdir -p /mnt$EFI_MNT
mount /dev/sda1 /mnt$EFI_MNT

# === БАЗОВАЯ УСТАНОВКА ===
basestrap /mnt base base-devel runit elogind-runit linux linux-firmware git fish

fstabgen -U /mnt >> /mnt/etc/fstab

artix-chroot /mnt /bin/bash <<EOF
set -e

# === ВРЕМЯ/ЛОКАЛЬ ===
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

sed -i "s/^#\\($LOCALE UTF-8\\)/\\1/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOT
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT

# === ПОЛЬЗОВАТЕЛЬ ===
passwd <<PSW
artix
artix
PSW

useradd -m -G wheel -s /usr/bin/fish $USERNAME
passwd $USERNAME <<PSW
artix
artix
PSW

# sudo для wheel
pacman -S --noconfirm sudo
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# === ЗАГРУЗЧИК (EFI общий с CachyOS) ===
pacman -S --noconfirm grub efibootmgr os-prober
grub-install --target=x86_64-efi --efi-directory=$EFI_MNT --bootloader-id=Artix
grub-mkconfig -o /boot/grub/grub.cfg

# === СЕТЬ ===
pacman -S --noconfirm connman-runit connman-gtk
ln -s /etc/runit/sv/connmand /etc/runit/runsvdir/default

# === SWAY STACK ===
pacman -S --noconfirm sway waybar wlroots swaybg swayidle swaylock \
    foot wofi mako grim slurp wl-clipboard xdg-desktop-portal-wlr \
    xorg-xwayland pavucontrol

# === PIPEWIRE ===
pacman -S --noconfirm pipewire pipewire-pulse wireplumber pipewire-alsa \
    lib32-pipewire lib32-alsa-plugins

# === NVIDIA (GTX 1050) ===
pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils \
    vulkan-icd-loader lib32-vulkan-icd-loader

# === ИНСТРУМЕНТЫ ===
pacman -S --noconfirm code neovim libreoffice-fresh steam gamemode \
    lib32-gamemode git

# === RUNIT СЕРВИСЫ ===
ln -s /etc/runit/sv/seatd /etc/runit/runsvdir/default || true

EOF

echo "УСТАНОВКА ЗАВЕРШЕНА! Перезагрузи систему."
