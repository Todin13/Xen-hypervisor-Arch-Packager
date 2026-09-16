# Maintainer: ODIN Thomas <thomas2.odin@gmail.com>

# ============================================================================
# BUILD OPTIONS IMPORTED
# You can use the template file (build-conf/xen-build-template.conf)
# to do yours
# ============================================================================

_config_file="${XEN_BUILD_CONF:-./build-conf/xen-build.conf}"

if [[ -f "${_config_file}" ]]; then
    source "${_config_file}"
else
    echo "Error: Configuration file ${_config_file} not found!"
    exit 1
fi

# ============================================================================

pkgname="xen${_build_suffix}"
pkgver=${_xen_version}
pkgrel=1
pkgdesc="Custom Open-source type-1 hypervisor (${_xen_branch})"
arch=('x86_64')
url='https://xenproject.org/'
license=('GPL3')
options=(!buildflags)
install="xen.install"


# Dependencies
makedepends=('zlib' 'python' 'ncurses' 'openssl' 'libx11' 'libuuid.so' 'yajl' 'libaio' 'glib2' 'pkgconf' 'git' 'iproute2' 'inetutils' 'acpica' 'lib32-glibc' 'gnutls' 'vde2' 'lzo' 'pciutils' 'sdl2' 'systemd-libs' 'systemd' 'wget' 'pandoc' 'valgrind' 'git' 'bison' 'gettext' 'flex' 'pixman' 'fig2dev' 'python-setuptools')
depends=('zlib' 'python' 'ncurses' 'openssl' 'libx11' 'libuuid.so' 'yajl' 'libaio' 'glib2' 'pkgconf' 'iproute2' 'inetutils' 'acpica' 'lib32-glibc' 'gnutls' 'vde2' 'lzo' 'pciutils' 'sdl2' 'pixman' 'libseccomp' 'libpng' 'libjpeg-turbo')

_source=(
    "${_xen_repo}#branch=${_xen_branch}"
    "xen.conf"
    "xen-log-separator.sh"
    "xen-log-separator.service"
)

source=( "${_source[@]}" "${_custom_patches[@]}" )

# Using SKIP for rapid local development
sha512sums=()
for _ in "${source[@]}"; do
    sha512sums+=('SKIP')
done

for file in "${_custom_patches[@]}"; do
    noextract+=("$(basename "${file}")")
done

prepare() {
    cd "${srcdir}/xen"

    # Apply custom patches automatically
    for patchurl in "${_custom_patches[@]}"; do
        patch=$(basename "$patchurl")
        msg2 "Applying custom patch '${patch}'..."
        patch -p1 < "../${patch}"
    done

    # Fix hardcoded paths
    sed 's,/var/run,/run,g' -i tools/hotplug/Linux/locking.sh
    sed 's,/var/run,/run,g' -i tools/pygrub/src/pygrub
    sed 's,/var/run,/run,g' -i tools/xenmon/xenmon.py
    sed 's,/var/run,/run,g' -i tools/xenmon/xenbaked.c
    sed 's,/var/run,/run,g' -i tools/include/libxl_event.h
    sed 's,/var/run,/run,g' -i docs/designs/qemu-deprivilege.md
    sed 's,/var/run,/run,g' -i docs/designs/qemu-deprivilege.md
    sed 's,/var/run,/run,g' -i docs/designs/qemu-deprivilege.md
}

build() {
    cd "${srcdir}/xen"

    local _config_stubdom='--disable-stubdom'
    if [[ "${_build_stubdom}" == "true" ]]; then
        _config_stubdom='--enable-stubdom --disable-vtpm-stubdom --disable-vtpmmgr-stubdom'
    fi

    # We pass Arch Linux's system-wide CFLAGS to ensure optimal compilation
    _make_flags=(
        "BOOT_DIR=${_boot_dir}"
        "XEN_VENDORVERSION=-${pkgrel}${_build_suffix}"
        "EXTRA_CFLAGS_XEN_TOOLS=${CFLAGS}"
        "EXTRA_CFLAGS_QEMU_XEN=${CFLAGS} -Wno-error"
    )

    local _debug_flag="--disable-debug"
    if [[ "${_build_debug}" == "true" ]]; then
        _debug_flag="--enable-debug"
        _make_flags+=("debug=y")
    fi

    local _hypervisor_flags=""
    if [[ "${_hypervisor_only}" == "true" ]]; then
        _hypervisor_flags="--disable-tools --disable-docs"
    fi

    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc \
        --localstatedir=/var \
        --sbindir=/usr/bin \
        --libdir=/usr/lib \
        --libexecdir=/usr/lib \
        --with-rundir=/run \
        --enable-systemd \
        --with-systemd=/usr/lib/systemd/system \
        --with-systemd-modules-load=/usr/lib/modules-load.d \
        --disable-qemu-traditional \
        --with-extra-qemuu-configure-args="--disable-libnfs" \
        ${_config_stubdom} \
        ${_debug_flag} \
        ${_hypervisor_flags} \
        --with-sysconfig-leaf-dir=conf.d \
        --with-xenstored=xenstored \
        --disable-ocamltools \
        --disable-pygrub

    make "${_make_flags[@]}"
}

package() {
    local _make_flags=(
        "BOOT_DIR=${_boot_dir}"
        "XEN_VENDORVERSION=-${pkgrel}${_build_suffix}"
        "EXTRA_CFLAGS_XEN_TOOLS=${CFLAGS}"
        "EXTRA_CFLAGS_QEMU_XEN=${CFLAGS} -Wno-error"
    )

    if [[ "${_build_debug}" == "true" ]]; then
        _make_flags+=("debug=y")
    fi

    cd "${srcdir}/xen"

    # Install everything into the temporary package sandbox
    make "${_make_flags[@]}" DESTDIR="$pkgdir" install

    # Clean up legacy runtime directories
    rm -rf "$pkgdir"/var/run

    install -D -m 0644 "${srcdir}/xen.conf" "${pkgdir}/usr/lib/modules-load.d/xen.conf"
    install -D -m 0755 "${srcdir}/xen-log-separator.sh" "${pkgdir}/usr/bin/xen-log-separator.sh"
    install -D -m 0644 "${srcdir}/xen-log-separator.service" "${pkgdir}/usr/lib/systemd/system/xen-log-separator.service"


    # --- SIDE-BY-SIDE RENAMING FOR GRUB ---

    if [ -f "${pkgdir}/${_boot_dir}/xen.gz" ]; then
        # Move the real file and give it our custom suffix (e.g., xen-testbuild.gz)
        mv "$(realpath "${pkgdir}/${_boot_dir}/xen.gz")" "${pkgdir}/${_boot_dir}/xen${_build_suffix}.gz"
        # Clean up all the messy default symlinks Xen creates (like xen-4.21.gz)
        find "${pkgdir}/${_boot_dir}" -name "xen*.gz" -type l -delete
    fi

    if [[ "${_hypervisor_only}" == "true" ]]; then
        msg2 "Stripping userspace tools for side-by-side installation..."
        rm -rf "${pkgdir}/usr"
        rm -rf "${pkgdir}/var"
        rm -rf "${pkgdir}/run"
        rm -rf "${pkgdir}/etc"
    fi
}
