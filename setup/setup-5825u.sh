#!/bin/bash

set -euo pipefail

echo "[1/3] Editing Grub..."
sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash processor.max_cstate=1"/' /etc/default/grub

echo "[2/3] Updating Grub..."
sudo update-grub

echo "[3/3] Rebooting..."
sudo reboot