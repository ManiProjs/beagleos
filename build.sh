#!/bin/bash
set -e

# === CONFIG ===
DISTRO_NAME="BeagleOS"
DISTRO_VERSION="0.1"
CODENAME="basenji"
ARCH="arm64"
RELEASE="bookworm"
ROOTFS_DIR="./chroot"
ISO_DIR="./iso_root"
IMAGE_NAME="${DISTRO_NAME,,}-${DISTRO_VERSION}-${CODENAME}-live-${ARCH}.iso"

# === 1. Install required packages ===
echo "💻 Installing required packages..."
sudo apt install debootstrap grub-efi-arm64 qemu-user-static xorriso

if ![ -e $ROOTFS_DIR ]; then
  # === 2. Bootstrap minimal Debian system ===
  echo "🚀 Bootstrapping Debian $ARCH..."
  echo "👨‍🏫 We're gonna bootstrap a super duper minimal Debian system."
  echo "👨‍🏫 Then we do other stuff that we need. Sleeping for 2 seconds then start bootstrapping..."
  sleep 2
  sudo debootstrap --arch=$ARCH $RELEASE "$ROOTFS_DIR" http://deb.debian.org/debian
fi

# === 3. Prepare ISO root structure ===
echo "📂 Preparing ISO root..."
echo "👨‍🏫 We're gonna create some directory for booting. We're gonna need it for GRUB (GRand Unified Bootloader) and installer"
echo "👨‍🏫 Installer helps you install BeagleOS without doing it manually."
sleep 2
mkdir -p "$ISO_DIR/boot/grub"
mkdir -p "$ISO_DIR/install"

echo "💾 Mounting special filesystems..."
sudo mount --bind /dev "$ROOTFS_DIR/dev"
sudo mount --bind /proc "$ROOTFS_DIR/proc"
sudo mount --bind /sys "$ROOTFS_DIR/sys"

echo "🐧 Installing Linux kernel and some additional packages"
sudo cp /usr/bin/qemu-aarch64-static "chroot/usr/bin/qemu-aarch64-static"
sudo chroot "$ROOTFS_DIR" /bin/bash -c "
  apt-get update &&
  apt-get install -y linux-image-arm64 systemd-sysv grub-efi-arm64 shim-signed zsh fish bash-completion neofetch 
"

# === 4. Copy kernel and initrd from chroot ===
echo "📦 Copying kernel and initrd..."
echo "👨‍🏫 This gonna copy the Linux kernel (yes, Linux!) and initrd.img to the ISO root."
cp "$ROOTFS_DIR/boot/vmlinuz"* "$ISO_DIR/boot/vmlinuz"
cp "$ROOTFS_DIR/boot/initrd.img"* "$ISO_DIR/boot/initrd.img"

# === 5. Download Debian Installer ===
echo "📥 Downloading Debian Installer files..."
curl -o "$ISO_DIR/install/vmlinuz" "https://deb.debian.org/debian/dists/bookworm/main/installer-arm64/current/images/netboot/debian-installer/arm64/linux"
curl -o "$ISO_DIR/install/initrd.gz" "https://deb.debian.org/debian/dists/bookworm/main/installer-arm64/current/images/netboot/debian-installer/arm64/initrd.gz"

# === 6. Create grub.cfg ===
echo "📝 Creating GRUB config..."
cat > "$ISO_DIR/boot/grub/grub.cfg" <<EOF
set timeout=5
set default=0

menuentry "$DISTRO_NAME Live ($ARCH)" {
    linux /boot/vmlinuz root=/dev/ram0
    initrd /boot/initrd.img
}

menuentry "Install $DISTRO_NAME (Debian Installer)" {
    linux /install/vmlinuz
    initrd /install/initrd.gz
}
EOF

# === 7. Add GRUB EFI bootloader ===
echo "⚙️  Installing GRUB EFI bootloader..."
mkdir -p "$ISO_DIR/EFI/BOOT"
grub-mkimage -o "$ISO_DIR/EFI/BOOT/BOOTAA64.EFI" -O arm64-efi -p /boot/grub efi_gop efi_uga fat iso9660 part_gpt part_msdos normal linux configfile loopback search search_fs_uuid search_label terminal cat gfxterm gfxmenu

# === 8. Build the ISO ===
echo "💿 Building ISO image..."
xorriso -as mkisofs \
  -iso-level 3 \
  -o "$IMAGE_NAME" \
  -full-iso9660-filenames \
  -volid "$DISTRO_NAME $DISTRO_VERSION $CODENAME $ARCH" \
  -eltorito-alt-boot \
  -e EFI/BOOT/BOOTAA64.EFI \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  "$ISO_DIR"

echo "✅ ISO created: $IMAGE_NAME"
