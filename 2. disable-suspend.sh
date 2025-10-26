#!/usr/bin/env bash
set -e

echo "=== Disable Suspend on Linux Mint 22.2 ==="
echo
echo "This script will:"
echo "  • Disable all suspend actions (including suspend-then-hibernate)"
echo "  • Hide suspend from power menus"
echo "  • Prevent suspend on lid close or suspend key"
echo
read -rp "Press Enter to continue or Ctrl+C to cancel..."

# --- Step 1: Detect PolicyKit system ---
echo "Detecting PolicyKit system..."
if [ -d /etc/polkit-1/rules.d ]; then
  PKTYPE="rules"
  echo "Detected .rules-based PolicyKit"
elif [ -d /etc/polkit-1/localauthority/50-local.d ]; then
  PKTYPE="pkla"
  echo "Detected .pkla-based PolicyKit"
else
  echo "❌ Could not detect PolicyKit version. Exiting."
  exit 1
fi

# --- Step 2: Disable suspend via PolicyKit ---
if [ "$PKTYPE" = "rules" ]; then
  echo "Creating PolicyKit rules to disable suspend..."
  sudo tee /etc/polkit-1/rules.d/11-disable-suspend.rules >/dev/null <<'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.upower.suspend" ||
         action.id == "org.freedesktop.login1.suspend" ||
         action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
         action.id == "org.freedesktop.login1.suspend-then-hibernate")) {
        return polkit.Result.NO;
    }
});
EOF
else
  echo "Creating PolicyKit .pkla file to disable suspend..."
  sudo tee /etc/polkit-1/localauthority/50-local.d/com.ubuntu.disable-suspend.pkla >/dev/null <<'EOF'
[Disable Suspend]
Identity=unix-user:*
Action=org.freedesktop.upower.suspend;org.freedesktop.login1.suspend;org.freedesktop.login1.suspend-multiple-sessions;org.freedesktop.login1.suspend-then-hibernate
ResultActive=no
EOF
fi

# --- Step 3: Disable suspend system-wide via logind.conf ---
echo
echo "Disabling suspend system-wide..."
sudo sed -i '/^HandleSuspendKey/d;/^HandleLidSwitch/d;/^HandleLidSwitchDocked/d' /etc/systemd/logind.conf
echo -e "\nHandleSuspendKey=ignore\nHandleLidSwitch=ignore\nHandleLidSwitchDocked=ignore" | sudo tee -a /etc/systemd/logind.conf >/dev/null
sudo systemctl restart systemd-logind

echo
echo "✅ Suspend has been disabled and hidden from power menus."
echo "You may need to reboot or log out and back in for changes to take full effect."