#!/bin/bash
# Fix for MediaTek WiFi/Bluetooth combo card misidentification
# This script prevents GVFS/GIO from mounting the device as a media player
# which causes Bluetooth functionality to crash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

echo -e "${GREEN}MediaTek WiFi/Bluetooth Fix Script${NC}"
echo "===================================="
echo

# Vendor and Device IDs
VENDOR_ID="0489"
DEVICE_ID="e111"

# Check if device is present
echo -e "${YELLOW}Checking for MediaTek device (${VENDOR_ID}:${DEVICE_ID})...${NC}"
if lsusb | grep -q "${VENDOR_ID}:${DEVICE_ID}"; then
    echo -e "${GREEN}✓ Device found${NC}"
    lsusb | grep "${VENDOR_ID}:${DEVICE_ID}"
else
    echo -e "${YELLOW}⚠ Device not currently detected${NC}"
    echo "The fix will still be applied and will work when the device is connected."
fi
echo

# Create udev rules directory if it doesn't exist
mkdir -p /etc/udev/rules.d

# Udev rule file path
RULE_FILE="/etc/udev/rules.d/99-mediatek-wifi-bluetooth.rules"

echo -e "${YELLOW}Creating udev rule...${NC}"

# Create the udev rule
cat > "$RULE_FILE" << 'EOF'
# MediaTek WiFi/Bluetooth combo card - prevent misidentification
# Vendor: 0489 (Foxconn/Hon Hai), Device: e111
#
# This device is incorrectly identified as a camera/media player by GVFS,
# causing it to be mounted and interfering with Bluetooth functionality.

# Remove incorrect device identifications and prevent GVFS from mounting
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0489", ATTRS{idProduct}=="e111", \
    ENV{UDISKS_IGNORE}="1", \
    ENV{GVFS_IGNORE}="1", \
    ENV{ID_GPHOTO2}="", \
    ENV{GPHOTO2_DRIVER}="", \
    ENV{ID_MEDIA_PLAYER}="", \
    ENV{ID_MTP_DEVICE}="", \
    ENV{COLORD_DEVICE}="", \
    ENV{COLORD_KIND}=""
EOF

if [ -f "$RULE_FILE" ]; then
    echo -e "${GREEN}✓ Udev rule created at: $RULE_FILE${NC}"
else
    echo -e "${RED}✗ Failed to create udev rule${NC}"
    exit 1
fi
echo

# Reload udev rules
echo -e "${YELLOW}Reloading udev rules...${NC}"
udevadm control --reload-rules
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Udev rules reloaded${NC}"
else
    echo -e "${RED}✗ Failed to reload udev rules${NC}"
    exit 1
fi
echo

# Trigger udev for the device
echo -e "${YELLOW}Triggering udev for MediaTek device...${NC}"
udevadm trigger --action=add --subsystem-match=usb --attr-match=idVendor="$VENDOR_ID" --attr-match=idProduct="$DEVICE_ID"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Udev triggered${NC}"
else
    echo -e "${YELLOW}⚠ Udev trigger completed with warnings (this is normal if device is not present)${NC}"
fi
echo

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Fix applied successfully!${NC}"
echo -e "${GREEN}================================${NC}"
echo
echo "What to do next:"
echo "1. If the device is currently connected, unplug and replug it"
echo "2. Alternatively, reboot your system"
echo "3. Your WiFi/Bluetooth combo card should now work correctly"
echo
echo "To verify the fix:"
echo "  udevadm info /dev/bus/usb/*/$(lsusb | grep ${VENDOR_ID}:${DEVICE_ID} | awk '{print $4}' | sed 's/://') 2>/dev/null | grep -E 'ID_GPHOTO2|ID_MTP|ID_MEDIA'"
echo "  (Should return empty if fix is working)"
echo
echo "To remove this fix:"
echo "  sudo rm $RULE_FILE"
echo "  sudo udevadm control --reload-rules"
echo
