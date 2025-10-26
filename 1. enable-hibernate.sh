#!/usr/bin/env bash
set -e

echo "=== Enable Hibernate on Linux Mint 22.2 (using swap partition) ==="
echo
echo "This script will:"
echo "  • Disable any active swapfile"
echo "  • Configure your swap partition for hibernation"
echo "  • Add the correct resume=UUID to GRUB and initramfs"
echo "  • Enable Hibernate and disable Suspend in menus (depending on PolicyKit version)"
echo
read -rp "Press Enter to continue or Ctrl+C to cancel..."

# --- Step 1: Ask user to confirm or provide swap UUID ---
echo
echo "Step 1: Identify your swap partition"
lsblk -fp | grep swap || true
echo
read -rp "Enter the UUID of your swap partition (as shown above - belt and braces): " SWAPUUID

if [[ -z "$SWAPUUID" ]]; then
  echo "❌ No UUID entered. Exiting."
  exit 1
fi

echo "Using swap UUID: $SWAPUUID"
echo

# --- Step 2: Disable any existing swapfile ---
echo "Disabling any existing swapfile..."
if grep -q "/swapfile" /etc/fstab; then
  sudo swapoff /swapfile 2>/dev/null || true
  sudo sed -i '/\/swapfile/d' /etc/fstab
  echo "Swapfile removed from /etc/fstab."
else
  echo "No swapfile entry found in /etc/fstab."
fi

# --- Step 3: Ensure swap partition is in /etc/fstab ---
if ! grep -q "$SWAPUUID" /etc/fstab; then
  echo "Adding swap partition to /etc/fstab..."
  echo "UUID=$SWAPUUID none swap sw 0 0" | sudo tee -a /etc/fstab
else
  echo "Swap partition already in /etc/fstab."
fi

sudo swapon -a
echo "Current active swap:"
swapon --show

# --- Step 4: Configure GRUB for resume ---
echo "Configuring GRUB..."
if [ -f /etc/default/grub ]; then
  sudo cp /etc/default/grub /etc/default/grub.backup.$(date +%s)
  if grep -q "resume=UUID" /etc/default/grub; then
    sudo sed -i "s#resume=UUID=[^ ]*#resume=UUID=$SWAPUUID#g" /etc/default/grub
  else
    sudo sed -i "s#GRUB_CMDLINE_LINUX=\"#GRUB_CMDLINE_LINUX=\"resume=UUID=$SWAPUUID #g" /etc/default/grub
  fi
fi
sudo update-grub

# --- Step 5: Configure initramfs resume ---
echo "Configuring initramfs resume..."
echo "RESUME=UUID=$SWAPUUID" | sudo tee /etc/initramfs-tools/conf.d/resume >/dev/null
sudo update-initramfs -u

# --- Step 6: Detect PolicyKit system ---
echo
echo "Detecting PolicyKit system..."
if [ -d /etc/polkit-1/rules.d ]; then
  PKTYPE="rules"
  echo "Using .rules-based PolicyKit"
elif [ -d /etc/polkit-1/localauthority/50-local.d ]; then
  PKTYPE="pkla"
  echo "Using .pkla-based PolicyKit"
else
  echo "❌ Could not detect PolicyKit version. Exiting."
  exit 1
fi

# --- Step 7: Apply hibernate and disable suspend rules ---
if [ "$PKTYPE" = "rules" ]; then
  echo "Creating PolicyKit rules..."
  sudo tee /etc/polkit-1/rules.d/10-enable-hibernate.rules >/dev/null <<'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.upower.hibernate" ||
         action.id == "org.freedesktop.login1.hibernate") &&
        subject.isInGroup("users")) {
        return polkit.Result.YES;
    }
});
EOF

  sudo tee /etc/polkit-1/rules.d/11-disable-suspend.rules >/dev/null <<'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.upower.suspend" ||
         action.id == "org.freedesktop.login1.suspend")) {
        return polkit.Result.NO;
    }
});
EOF
else
  echo "Creating PolicyKit .pkla files..."
  sudo tee /etc/polkit-1/localauthority/50-local.d/com.ubuntu.enable-hibernate.pkla >/dev/null <<'EOF'
[Enable Hibernate]
Identity=unix-user:*
Action=org.freedesktop.upower.hibernate;org.freedesktop.login1.hibernate
ResultActive=yes
EOF

  sudo tee /etc/polkit-1/localauthority/50-local.d/com.ubuntu.disable-suspend.pkla >/dev/null <<'EOF'
[Disable Suspend]
Identity=unix-user:*
Action=org.freedesktop.upower.suspend;org.freedesktop.login1.suspend
ResultActive=no
EOF
fi

# --- Step 8: Final checks ---
echo
echo "Verifying configuration..."
grep resume /etc/default/grub
grep RESUME /etc/initramfs-tools/conf.d/resume
swapon --show
echo
echo "✅ Hibernate should now be available in your Mint power menu."
echo "   If not, reboot and test using:"
echo "      systemctl hibernate"
