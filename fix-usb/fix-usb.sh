#!/usr/bin/env bash
# Bring the Intel xHCI controller back without rebooting when USB freezes
set -e
DEV="0000:00:14.0"
echo "Resetting xHCI $DEV ..."
echo -n "$DEV" | sudo tee /sys/bus/pci/drivers/xhci_hcd/unbind > /dev/null
sleep 2
echo -n "$DEV" | sudo tee /sys/bus/pci/drivers/xhci_hcd/bind > /dev/null
echo "OK. USB restarted."
