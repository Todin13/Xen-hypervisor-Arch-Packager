# Xen Arch Linux Development Packager

This repository contains a highly flexible, configurable `PKGBUILD` designed specifically for **developing, patching, and testing the Xen hypervisor on Arch Linux with GRUB Boot Loader**.

Rather than hardcoding build variables into the `PKGBUILD`, this project uses a modular configuration system (`build-conf/`) that allows you to easily switch between building upstream releases, compiling your local working directories, and generating side-by-side "hypervisor-only" packages for safe testing.

For this I used and inspired myself of the xen official doc [here](https://wiki.xenproject.org/wiki/Getting_Started) and the [AUR Xen package for arch-linux](https://aur.archlinux.org/xen.git)

## Key Features for Developers

* **Local Source Compilation:** Point the build system directly at your local Xen Git repository to test uncommitted changes or local branches.
* **Side-by-Side Installation:** Define a custom `_build_suffix` (e.g., `-test`) to rename the output package and the Xen EFI/GRUB binary (e.g., `xen-test.gz`), preventing conflicts with your daily-driver hypervisor.
* **Hypervisor-Only Mode:** Strip out all `dom0` userspace tools (`xl`, `xenstored`, QEMU) from the final package. This allows you to install and boot a modified hypervisor alongside your stable host tools without pacman file conflicts.
* **Automated Patching:** Drop patch files into the root directory, add them to the config, and they will be applied automatically during the `prepare()` phase.
* **Debug Builds:** One-line toggle to enable debug symbols and verbose hypervisor output.
* **Modern Toolchain Fixes:** Built-in compiler flags (`-Wno-error`) to successfully compile Xen and its bundled QEMU device model with modern Arch Linux GCC versions.

## Project Structure

    .
    ├── PKGBUILD                        # The main Arch Linux package build script
    ├── build-conf/
    │   ├── xen-build-template.conf     # Template for build variables
    │   └── xen-build.conf              # Current Upstream stable xen version and build
    ├── xen.conf                        # systemd modules-load configuration
    ├── xen.install                     # Post-install pacman hooks
    ├── xen-log-separator.sh            # Script for managing/separating Xen boot logs
    └── xen-log-separator.service       # systemd service for the log separator

## Quick Start

### 1. Prepare your build configuration
Copy the template to create your local active configuration file:
    cp build-conf/xen-build-template.conf build-conf/xen-custom.conf


### 2. Configure your development scenario
Edit `build-conf/xen-custom.conf`. Here are two common development workflows:

**Scenario A: Testing a local code branch safely**
You have a local clone of Xen at `/home/user/code/xen` and want to test a hypervisor change without breaking your host `dom0` tools.
    _use_local_code="true"
    _local_source_path="/home/user/code/xen"
    _build_debug="true"
    _build_suffix="-mybranch"
    _hypervisor_only="true"   # Extremely important for side-by-side installs

**Scenario B: Building a specific upstream version with a custom patch**
You want to build Xen 4.22 with an experimental patch you downloaded.
    _use_local_code="false"
    _xen_version="4.22.0"
    _xen_branch="stable-4.22"
    _custom_patches=("experimental-feature.patch")

### 3. Build the package
Ensure you have the Arch `base-devel` group installed, then run:
    makepkg -s

*Note: If you want to use a config file with a different name/path, you can pass it via an environment variable: `XEN_BUILD_CONF=./my-custom.conf makepkg -s`*
### 4. Check for Conflicts (Optional but Recommended)
Before installing the newly built package, you can verify if it will cause file or package conflicts without actually touching your system.

**The Dry-Run Method (Fastest)**
The closest thing to a true dry run is using the `--print` flag. It goes through normal dependency and conflict resolution and prints what it would do, without committing the transaction.

    sudo pacman -U --print xen-mybranch-4.22.0-1-x86_64.pkg.tar.zst

If it errors out complaining about a conflicting file or package, you have a conflict. If it prints a clean plan, you are clear.

**Manual File-Level Conflict Check**
To see if the package tries to write a file another package already owns:

    pacman -Qlp xen-mybranch-*.pkg.tar.zst | awk '{print $2}' | while read -r f; do [ -f "$f" ] && owner=$(pacman -Qo "$f" 2>/dev/null) && echo "CONFLICT: $f -> $owner"; done

**Manual Metadata Conflict Check**
To see what conflicts the package explicitly declares in its metadata:

    pacman -Qip xen-mybranch-*.pkg.tar.zst | grep -E '^(Conflicts|Provides|Replaces)'

You can cross-reference the output by checking installed Xen packages with `pacman -Qs '^xen'`.

### 5. Install and Test
Once you have verified the package is clean, install it using `pacman`:

    sudo pacman -U xen-mybranch-4.22.0-1-x86_64.pkg.tar.zst

Because of the side-by-side features in the `PKGBUILD`, this will install `/boot/xen-mybranch.gz` without overwriting `/boot/xen.gz`. Update your GRUB configuration to add a boot entry for your new hypervisor binary and reboot!

## Notes on the Build Process

* **QEMU Traditional:** `--disable-qemu-traditional` is strictly enforced. The obsolete 2009-era QEMU fork will not compile on modern Arch Linux.
* **libnfs Conflicts:** Arch Linux's modern `libnfs` API is incompatible with Xen's bundled `qemu-upstream`. The `PKGBUILD` explicitly passes `--disable-libnfs` to QEMU to prevent compilation failures.
* **Clean Workspaces:** If you switch between local and upstream builds, or change major flags, it is highly recommended to clean your workspace first using `rm -rf src/ pkg/`.
