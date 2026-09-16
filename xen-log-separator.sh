#!/bin/sh

# Safety check: Exit immediately if not booted into a Xen Dom0 environment
if [ ! -f "/proc/xen/capabilities" ]; then
    exit 0
fi

# Extract the base version and your custom suffix (e.g., 4.21.2pre and -testbuild)
XEN_VERSION=$(xl info | grep '^xen_version' | awk '{print $3}')
XEN_EXTRA=$(xl info | grep '^xen_extra' | awk '{print $3}')
FULL_VERSION="${XEN_VERSION}${XEN_EXTRA}"

# Create the version-specific directory
LOG_DIR="/var/log/xen-custom/${FULL_VERSION}"
mkdir -p "${LOG_DIR}"

# Dump the hypervisor log with a timestamp
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
xl dmesg > "${LOG_DIR}/boot_${TIMESTAMP}.log"
