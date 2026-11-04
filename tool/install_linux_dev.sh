#!/bin/sh
# Installs the Linux release build for daily use on a development machine
# (distrobox): a copy of the bundle, a `poulplan` command, the menu entry,
# the icon and the KDE widgets. The Flatpak replaces all this for users.
# Usage: tool/install_linux_dev.sh   (after `flutter build linux --release`)
set -eu
cd "$(dirname "$0")/.."
bundle=build/linux/x64/release/bundle
dest="$HOME/.local/share/poulplan-app"
bin="$HOME/.local/bin/poulplan"

[ -x "$bundle/poulplan" ] || { echo "Construire d'abord : flutter build linux --release" >&2; exit 1; }

rm -rf "$dest.new"
cp -r "$bundle" "$dest.new"
rm -rf "$dest"
mv "$dest.new" "$dest"

mkdir -p "$(dirname "$bin")"
if [ -n "${CONTAINER_ID:-}" ]; then
  run="distrobox enter $CONTAINER_ID -- \"$dest/poulplan\""
else
  run="\"$dest/poulplan\""
fi
printf '#!/bin/sh\nexec %s "$@"\n' "$run" > "$bin"
chmod +x "$bin"

apps="$HOME/.local/share/applications"
mkdir -p "$apps"
sed "s|^Exec=.*|Exec=$bin|" linux/packaging/org.poulapp.poulplan.desktop > "$apps/org.poulapp.poulplan.desktop"

for size in linux/packaging/icons/hicolor/*/; do
  size=$(basename "$size")
  mkdir -p "$HOME/.local/share/icons/hicolor/$size/apps"
  cp linux/packaging/icons/hicolor/$size/apps/* "$HOME/.local/share/icons/hicolor/$size/apps/"
done

if [ -n "${CONTAINER_ID:-}" ]; then kpt="distrobox-host-exec kpackagetool6"; else kpt=kpackagetool6; fi
for widget in linux/plasmoid/*/; do
  $kpt -t Plasma/Applet -u "$widget" 2>/dev/null || $kpt -t Plasma/Applet -i "$widget"
done
echo "Installé : menu « Poulplan », commande $bin, widgets KDE."
