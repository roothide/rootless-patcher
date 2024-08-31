#!/bin/sh

set -e

WORKING_DIR="${1}"

find "${WORKING_DIR}" -type f | while read -r file; do
  if file -b "${file}" | grep -q "Mach-O"; then
    echo "[+] Script handling file: ${file}"

    LOAD_COMMANDS="$(otool -L "${file}")"
    INSTALL_NAME="$(otool -D "${file}" | grep -v -e ":$" -e "^Archive :" | head -n1)"

    echo "${LOAD_COMMANDS}" | tail -n +2 | grep /usr/lib/'[^/]'\*.dylib | cut -d' ' -f1 | tr -d "[:blank:]" > "${WORKING_DIR}"/._lib_cache
    echo "${LOAD_COMMANDS}" | tail -n +2 | grep /usr/local/lib/'[^/]'\*.dylib | cut -d' ' -f1 | tr -d "[:blank:]" >> "${WORKING_DIR}"/._lib_cache

    if [ -n "${INSTALL_NAME}" ]; then
        install_name_tool -id @rpath/"$(basename "${INSTALL_NAME}")" "$file" >/dev/null 2>&1
    fi

    if echo "${LOAD_COMMANDS}" | grep -q CydiaSubstrate; then
        install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/libsubstrate.dylib "${file}" >/dev/null 2>&1
    fi

    if echo "${LOAD_COMMANDS}" | grep -q CepheiPrefs.framework; then
        install_name_tool -change /usr/lib/CepheiPrefs.framework/CepheiPrefs @rpath/CepheiPrefs.framework/CepheiPrefs "${file}" >/dev/null 2>&1
    fi

    if echo "${LOAD_COMMANDS}" | grep -q Cephei.framework; then
        install_name_tool -change /usr/lib/Cephei.framework/Cephei @rpath/Cephei.framework/Cephei "${file}" >/dev/null 2>&1
    fi

    echo "${LOAD_COMMANDS}" | grep "/Library/PreferenceBundles" | grep -E '/[^/]*/[^/]*\.bundle' | cut -d' ' -f1  | cut -d':' -f1 | while read -r BUNDLE_PATH; do
        BUNDLE_NAME=$(basename "${BUNDLE_PATH}")
        install_name_tool -change "${BUNDLE_PATH}" "@rpath/${BUNDLE_NAME}.bundle/${BUNDLE_NAME}" "${file}" >/dev/null 2>&1
    done

    echo "${LOAD_COMMANDS}" | grep "/Library/Frameworks" | grep -E '/[^/]*/[^/]*\.framework' | grep -v "/System/Library/Frameworks" | cut -d' ' -f1  | cut -d':' -f1 | while read -r FRAMEWORK_PATH; do
        FRAMEWORK_NAME=$(basename "${FRAMEWORK_PATH}")
        install_name_tool -change "${FRAMEWORK_PATH}" "@rpath/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}" "${file}" >/dev/null 2>&1
    done

    if [ -f "${WORKING_DIR}"/._lib_cache ]; then
        cat "${WORKING_DIR}"/._lib_cache | while read line; do
            install_name_tool -change "${line}" @rpath/"$(basename "${line}")" "${file}" >/dev/null 2>&1
        done
    fi

    install_name_tool -add_rpath "/usr/local/lib" "${file}" >/dev/null 2>&1
    install_name_tool -add_rpath "/usr/lib" "${file}" >/dev/null 2>&1
    install_name_tool -add_rpath "/var/jb/usr/lib" "${file}" >/dev/null 2>&1
    install_name_tool -add_rpath "/var/jb/usr/local/lib" "${file}" >/dev/null 2>&1
    install_name_tool -add_rpath "/var/jb/Library/Frameworks" "${file}" >/dev/null 2>&1
    install_name_tool -add_rpath "/var/jb/Library/PreferenceBundles" "${file}" >/dev/null 2>&1

    echo "[+] Success!"
  fi
done

echo "[+] Cleaning up script portion"