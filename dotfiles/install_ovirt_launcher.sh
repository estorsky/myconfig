#!/bin/bash

set -e

target_home="${HOME}"
applications_dir="${target_home}/.local/share/applications"
desktop_path="${applications_dir}/ovirt.desktop"
tmp_desktop="$(mktemp)"

cleanup() {
    rm -f "${tmp_desktop}"
}
trap cleanup EXIT

mkdir -p "${applications_dir}"

cat > "${tmp_desktop}" <<EOF
[Desktop Entry]
Type=Application
Name=oVirt
Comment=Launch the oVirt work VM
Exec=${target_home}/myconfig/scripts/ovirt
TryExec=${target_home}/myconfig/scripts/ovirt
Icon=virt-viewer
Terminal=false
StartupNotify=true
Categories=Network;RemoteAccess;
Keywords=ovirt;remote-viewer;spice;vm;
EOF

install -Dm644 "${tmp_desktop}" "${desktop_path}"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${applications_dir}" >/dev/null 2>&1 || true
fi

echo "Installed ${desktop_path}"
