# rootless-patcher
A CLI rootful to rootless patcher. Utilizes a technique that does not require Xina-style symlinks.
### How to download
- Find the latest release in the [Releases](https://github.com/NightwindDev/rootless-patcher/releases) tab
- Download the correct file for your device configuration:
	- iOS rootless: `com.nightwind.rootless-patcher_<version>_iphoneos-arm64.deb`
	- iOS rootful: `com.nightwind.rootless-patcher_<version>_iphoneos-arm.deb`
	- macOS: `com.nightwind.rootless-patcher_<version>.pkg`
- Install via a package manager on iOS or double click the `.pkg` file on macOS to install.
### How to use
- iOS:
	- Open a terminal application and run `rootless-patcher <path/to/deb>`. This method is faster.
	- Locate the .deb in Filza and run the `rootless-patcher` script on it by long pressing on the file, pressing `Scripts`, and finding `rootless-patcher`. This method is slower.
- macOS:
	- Open a terminal application and run `rootless-patcher <path/to/deb>`.
### How to build manually
- Make sure [Theos](https://theos.dev) is installed
- Clone the repo: `git clone https://github.com/NightwindDev/rootless-patcher.git`
- `cd rootless-patcher`
- Build via `make`:
	- iOS rootless: `make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless TARGET_OS=ios`
	- iOS rootful: `make clean package FINALPACKAGE=1 TARGET_OS=ios`
	- macOS: `make clean package FINALPACKAGE=1 TARGET_OS=macos`
#### License
This project is licensed under [MIT](LICENSE).
###### Copyright (c) 2024 Nightwind