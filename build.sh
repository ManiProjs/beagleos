#!/bin/bash
set -e

# === CONFIG ===
DISTRO_NAME="BeagleOS"
DISTRO_VERSION="0.1"
CODENAME="basenji"
ARCH="arm64"
ROOTFS_DIR="./chroot"
ISO_DIR="./iso_root"
IMAGE_NAME="${DISTRO_NAME,,}-${DISTRO_VERSION}-${CODENAME}-${ARCH}.iso"

# === 1. Bootstrap minimal Debian system ===
echo "🚀 Bootstrapping Debian $ARCH..."
sudo debootstrap --arch=$ARCH bookworm "$ROOTFS_DIR" http://deb.debian.org/debian

# === 2. Prepare ISO root structure ===
echo "📂 Preparing ISO root..."
mkdir -p "$ISO_DIR/boot/grub"
mkdir -p "$ISO_DIR/install"

# === 3. Copy kernel and initrd from chroot ===
echo "📦 Copying kernel and initrd..."
cp "$ROOTFS_DIR/boot/vmlinuz"* "$ISO_DIR/boot/vmlinuz"
cp "$ROOTFS_DIR/boot/initrd.img"* "$ISO_DIR/boot/initrd.img"

# === 4. Download Debian Installer ===
echo "📥 Downloading Debian Installer files..."
curl -o "$ISO_DIR/install/vmlinuz" "https://deb.debian.org/debian/dists/bookworm/main/installer-arm64/current/images/netboot/debian-installer/arm64/linux"
curl -o "$ISO_DIR/install/initrd.gz" "https://deb.debian.org/debian/dists/bookworm/main/installer-arm64/current/images/netboot/debian-installer/arm64/initrd.gz"

# === 5. Create grub.cfg ===
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

# === 6. Add GRUB EFI bootloader ===
echo "⚙️  Installing GRUB EFI bootloader..."
mkdir -p "$ISO_DIR/EFI/BOOT"
grub-mkimage -o "$ISO_DIR/EFI/BOOT/BOOTAA64.EFI" -O arm64-efi -p /boot/grub efi_gop efi_uga fat iso9660 part_gpt part_msdos normal linux configfile loopback search search_fs_uuid search_label terminal cat gfxterm gfxmenu

# === 7. Build the ISO ===
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
