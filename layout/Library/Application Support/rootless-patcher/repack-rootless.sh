#!/bin/sh

set -e

FILE=${1}
WORKING_DIR="$(dirname ${FILE})"

echo "[+] Script handling file: ${FILE}"

# Fakesign in order to be able to fix load commands
ldid -S "${FILE}"

LOAD_COMMANDS="$(otool -L "${FILE}")"
INSTALL_NAME="$(otool -D "${FILE}" | grep -v -e ":$" -e "^Archive :" | head -n1)"

echo "${LOAD_COMMANDS}" | tail -n +2 | grep /usr/lib/'[^/]'\*.dylib | cut -d' ' -f1 | tr -d "[:blank:]" > "${WORKING_DIR}"/._lib_cache
echo "${LOAD_COMMANDS}" | tail -n +2 | grep /usr/local/lib/'[^/]'\*.dylib | cut -d' ' -f1 | tr -d "[:blank:]" >> "${WORKING_DIR}"/._lib_cache

if [ -n "${INSTALL_NAME}" ]; then
    install_name_tool -id @rpath/"$(basename "${INSTALL_NAME}")" "${FILE}" > /dev/null 2>&1
fi

if echo "${LOAD_COMMANDS}" | grep -q CydiaSubstrate; then
    install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/libsubstrate.dylib "${FILE}" > /dev/null 2>&1
fi

if echo "${LOAD_COMMANDS}" | grep -q CepheiPrefs.framework; then
    install_name_tool -change /usr/lib/CepheiPrefs.framework/CepheiPrefs @rpath/CepheiPrefs.framework/CepheiPrefs "${FILE}" > /dev/null 2>&1
fi

if echo "${LOAD_COMMANDS}" | grep -q Cephei.framework; then
    install_name_tool -change /usr/lib/Cephei.framework/Cephei @rpath/Cephei.framework/Cephei "${FILE}" > /dev/null 2>&1
fi

echo "${LOAD_COMMANDS}" | grep "/Library/PreferenceBundles" | grep -E '/[^/]*/[^/]*\.bundle' | cut -d' ' -f1  | cut -d':' -f1 | while read -r BUNDLE_PATH; do
    BUNDLE_NAME=$(basename "${BUNDLE_PATH}")
    install_name_tool -change "${BUNDLE_PATH}" "@rpath/${BUNDLE_NAME}.bundle/${BUNDLE_NAME}" "${FILE}" > /dev/null 2>&1
done

echo "${LOAD_COMMANDS}" | grep "/Library/Frameworks" | grep -E '/[^/]*/[^/]*\.framework' | grep -v "/System/Library/Frameworks" | cut -d' ' -f1  | cut -d':' -f1 | while read -r FRAMEWORK_PATH; do
    FRAMEWORK_NAME=$(basename "${FRAMEWORK_PATH}")
    install_name_tool -change "${FRAMEWORK_PATH}" "@rpath/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}" "${FILE}" > /dev/null 2>&1
done

if [ -f "${WORKING_DIR}"/._lib_cache ]; then
    cat "${WORKING_DIR}"/._lib_cache | while read line; do
        install_name_tool -change "${line}" @rpath/"$(basename "${line}")" "${FILE}" > /dev/null 2>&1
    done
fi

install_name_tool -add_rpath "/usr/local/lib" "${FILE}" > /dev/null 2>&1
install_name_tool -add_rpath "/usr/lib" "${FILE}" > /dev/null 2>&1
install_name_tool -add_rpath "/var/jb/usr/lib" "${FILE}" > /dev/null 2>&1
install_name_tool -add_rpath "/var/jb/usr/local/lib" "${FILE}" > /dev/null 2>&1
install_name_tool -add_rpath "/var/jb/Library/Frameworks" "${FILE}" > /dev/null 2>&1
install_name_tool -add_rpath "/var/jb/Library/PreferenceBundles" "${FILE}" > /dev/null 2>&1

rm -rf "${WORKING_DIR}/._lib_cache"

echo "[+] Success!"