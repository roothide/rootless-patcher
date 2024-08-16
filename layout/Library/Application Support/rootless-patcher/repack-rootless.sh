#!/bin/sh

set -e

LDID="ldid -Hsha256"

if [ -z "$1" ] || ! file "$1" | grep -q "Debian binary package" ; then
    echo "[+] Usage: $0 [/path/to/deb]"
    exit 1;
fi

echo "[+] Creating temporary workspace!"

DEB_NAME=$(basename "$1" .deb)

rm -rf $(dirname $1)/old_$DEB_NAME
rm -rf $(dirname $1)/patch_$DEB_NAME

mkdir -p "$(dirname "$1")/old_$DEB_NAME"
mkdir -p "$(dirname "$1")/patch_$DEB_NAME"

TEMPDIR_OLD="$(dirname "$1")/old_$DEB_NAME"
TEMPDIR_NEW="$(dirname "$1")/patch_$DEB_NAME"

if [ ! -d "$TEMPDIR_OLD" ] || [ ! -d "$TEMPDIR_NEW" ]; then
    echo "[+] Creating temporary directories failed."
    rm -rf "$TEMPDIR_OLD" "$TEMPDIR_NEW"
    exit 1;
fi

### Real script start

dpkg-deb -R "$1" "$TEMPDIR_OLD"

if [ -d "$TEMPDIR_OLD/var/jb" ]; then
    echo "[+] Deb already rootless. Skipping and exiting cleanly."
    rm -rf "$TEMPDIR_OLD" "$TEMPDIR_NEW"
    exit 0;
fi

mkdir -p "$TEMPDIR_NEW"/var/jb
cp -a "$TEMPDIR_OLD"/DEBIAN "$TEMPDIR_NEW"
sed 's|iphoneos-arm|iphoneos-arm64|' < "$TEMPDIR_OLD"/DEBIAN/control > "$TEMPDIR_NEW"/DEBIAN/control

rm -rf "$TEMPDIR_OLD"/DEBIAN
mv -f "$TEMPDIR_OLD"/.* "$TEMPDIR_OLD"/* "$TEMPDIR_NEW"/var/jb >/dev/null 2>&1 || true
mv -f "$TEMPDIR_OLD"/* "$TEMPDIR_OLD"/* "$TEMPDIR_NEW"/var/jb >/dev/null 2>&1 || true

find "$TEMPDIR_NEW" -type f | while read -r file; do
  if file -b "$file" | grep -q "Mach-O"; then
    echo "[+] Script handling file: $file"

    INSTALL_NAME=$(otool -D "$file" | grep -v -e ":$" -e "^Archive :" | head -n1)
    otool -L "$file" | tail -n +2 | grep /usr/lib/'[^/]'\*.dylib | cut -d' ' -f1 | tr -d "[:blank:]" > "$TEMPDIR_OLD"/._lib_cache
    otool -L "$file" | tail -n +2 | grep /usr/local/lib/'[^/]'\*.dylib | cut -d' ' -f1 | tr -d "[:blank:]" >> "$TEMPDIR_OLD"/._lib_cache

    if [ -n "$INSTALL_NAME" ]; then
        install_name_tool -id @rpath/"$(basename "$INSTALL_NAME")" "$file" >/dev/null 2>&1
    fi
    if otool -L "$file" | grep -q CydiaSubstrate; then
        install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/libsubstrate.dylib "$file" >/dev/null 2>&1
    fi
    if otool -L "$file" | grep -q CepheiPrefs.frame; then
        install_name_tool -change /Library/Frameworks/CepheiPrefs.framework/CepheiPrefs @rpath/CepheiPrefs.framework/CepheiPrefs "$file" >/dev/null 2>&1
        install_name_tool -change /usr/lib/CepheiPrefs.framework/CepheiPrefs @rpath/CepheiPrefs.framework/CepheiPrefs "$file" >/dev/null 2>&1
    fi
    if otool -L "$file" | grep -q Cephei.frame; then
        install_name_tool -change /Library/Frameworks/Cephei.framework/Cephei @rpath/Cephei.framework/Cephei "$file" >/dev/null 2>&1
        install_name_tool -change /usr/lib/Cephei.framework/Cephei @rpath/Cephei.framework/Cephei "$file" >/dev/null 2>&1
    fi

    otool -L "$file" | grep "/Library/PreferenceBundles" | grep -E '/[^/]*/[^/]*\.bundle' | cut -d' ' -f1  | cut -d':' -f1 | while read -r BUNDLE_PATH; do
        BUNDLE_NAME=$(basename "$BUNDLE_PATH")
        install_name_tool -change "$BUNDLE_PATH" "@rpath/$BUNDLE_NAME.bundle/$BUNDLE_NAME" "$file" >/dev/null 2>&1
    done

    otool -L "$file" | grep "/Library/Frameworks" | grep -E '/[^/]*/[^/]*\.framework' | grep -v "/System/Library/Frameworks" | cut -d' ' -f1  | cut -d':' -f1 | while read -r FRAMEWORK_PATH; do
        FRAMEWORK_NAME=$(basename "$FRAMEWORK_PATH")
        install_name_tool -change "$FRAMEWORK_PATH" "@rpath/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME" "$file" >/dev/null 2>&1
    done

    if [ -f "$TEMPDIR_OLD"/._lib_cache ]; then
        cat "$TEMPDIR_OLD"/._lib_cache | while read line; do
            install_name_tool -change "$line" @rpath/"$(basename "$line")" "$file" >/dev/null 2>&1
        done
    fi

    install_name_tool -add_rpath "/usr/local/lib" "$file" >/dev/null 2>&1
    install_name_tool -add_rpath "/usr/lib" "$file" >/dev/null 2>&1
    install_name_tool -add_rpath "/var/jb/usr/lib" "$file" >/dev/null 2>&1
    install_name_tool -add_rpath "/var/jb/usr/local/lib" "$file" >/dev/null 2>&1
    install_name_tool -add_rpath "/var/jb/Library/Frameworks" "$file" >/dev/null 2>&1
    install_name_tool -add_rpath "/var/jb/Library/PreferenceBundles" "$file" >/dev/null 2>&1

    $LDID -S "$file"

    echo "[+] Success!"
  fi
done

echo "[+] Cleaning up script portion"
rm -rf "$TEMPDIR_OLD"

### Real script end