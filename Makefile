XCODEPROJ := PasteCheck.xcodeproj
CONFIGURATION := Debug
# Keep build products inside the repository to fix their path and avoid cluttering the system DerivedData.
DERIVED_DATA := tmp/DerivedData

# A bare make is the entry point for a person to check behavior by hand.
.DEFAULT_GOAL := macos

.PHONY: build-macos test clean

# Build only. Does not install.
build-macos:
	xcodebuild -project $(XCODEPROJ) -scheme PasteCheck -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) -destination 'generic/platform=macOS' build

test:
	swift test --package-path PasteCheckCore

clean:
	rm -rf $(DERIVED_DATA)

# Install a Release build to /Applications for everyday use
# Why Release, why /Applications, and why run lsregister -f:
#   https://github.com/bannzai/PUTS/blob/main/documents/adr/0009-install-release-build-to-applications.md
# Does not launch the app automatically (assumes it may be run over ssh)
.PHONY: macos
INSTALL_APP := /Applications/PasteCheck.app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

macos:
	xcodebuild -project 'PasteCheck.xcodeproj' -scheme 'PasteCheck' \
		-configuration Release \
		-destination 'platform=macOS' \
		-derivedDataPath 'tmp/DerivedData' \
		-allowProvisioningUpdates -allowProvisioningDeviceRegistration \
		build
	rm -rf $(INSTALL_APP)
	ditto 'tmp/DerivedData/Build/Products/Release/PasteCheck.app' $(INSTALL_APP)
	$(LSREGISTER) -f $(INSTALL_APP)
	@echo "To launch: open $(INSTALL_APP)"

# Overwrite /Applications/PasteCheck.app, the same location as Release, with a Debug build.
# A temporary install for using Debug-only operations (developer menu and so on) on everyday data;
# go back to Release with make macos when done
# Does not launch the app automatically (assumes it may be run over ssh)
.PHONY: macos-debug

macos-debug:
	xcodebuild -project 'PasteCheck.xcodeproj' -scheme 'PasteCheck' \
		-configuration Debug \
		-destination 'platform=macOS' \
		-derivedDataPath 'tmp/DerivedData' \
		-allowProvisioningUpdates -allowProvisioningDeviceRegistration \
		build
	rm -rf $(INSTALL_APP)
	ditto 'tmp/DerivedData/Build/Products/Debug/PasteCheck.app' $(INSTALL_APP)
	$(LSREGISTER) -f $(INSTALL_APP)
	@echo "To launch: open $(INSTALL_APP)"
	@echo "To go back to Release: make macos"
