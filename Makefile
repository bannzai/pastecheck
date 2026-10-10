XCODEPROJ := PasteCheck.xcodeproj
CONFIGURATION := Debug
# ビルド成果物のパスを固定し、システムの DerivedData を汚さないためリポジトリ内に置く。
DERIVED_DATA := tmp/DerivedData

# 引数なしの make は、人が手で動作確認する入口にする。
.DEFAULT_GOAL := macos

.PHONY: build-macos test clean

# ビルドだけを行う。配置はしない。
build-macos:
	xcodebuild -project $(XCODEPROJ) -scheme PasteCheck -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) -destination 'generic/platform=macOS' build

test:
	swift test --package-path PasteCheckCore

clean:
	rm -rf $(DERIVED_DATA)

# Release ビルドを /Applications に配置して普段使いできるようにする
# Release にする理由・/Applications に置く理由・lsregister -f を打つ理由:
#   https://github.com/bannzai/PUTS/blob/main/documents/adr/0009-install-release-build-to-applications.md
# 起動は自動では行わない (ssh 越しの実行を想定)
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
	@echo "起動するには: open $(INSTALL_APP)"

# Debug ビルドを Release と同じ /Applications/PasteCheck.app に上書き配置する。
# Debug ビルドにしか無い操作 (開発者メニュー等) を普段使いのデータに対して行うための一時的な配置で、
# 終わったら make macos で Release に戻す
# 起動は自動では行わない (ssh 越しの実行を想定)
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
	@echo "起動するには: open $(INSTALL_APP)"
	@echo "Release に戻すには: make macos"
