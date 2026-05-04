APP_NAME    = VoiceScribe
BUNDLE_ID   = com.voicescribe.app
SRC_DIR     = Sources/VoiceScribe
BUILD_DIR   = build
APP_BUNDLE  = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR = /Applications

SWIFTC      = swiftc
SDK         = $(shell xcrun --sdk macosx --show-sdk-path)

SOURCES     = $(wildcard $(SRC_DIR)/*.swift)

SWIFTFLAGS  = \
	-sdk $(SDK) \
	-target arm64-apple-macosx14.0 \
	-framework AppKit \
	-framework AVFoundation \
	-framework Speech \
	-framework Carbon \
	-framework QuartzCore \
	-O

ENTITLEMENTS_FILE = /tmp/$(APP_NAME).entitlements

.PHONY: build run install clean sign help

## Default target
all: build

## Build release .app bundle
build: $(SOURCES)
	@echo "▶ Compiling $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	$(SWIFTC) $(SWIFTFLAGS) $(SOURCES) -o $(BUILD_DIR)/$(APP_NAME) 2>&1 | grep -v "SwiftBridging\|redefinition of module\|previously defined here\|bridging.modulemap\|module.modulemap" || true
	@echo "▶ Bundling .app..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp $(BUILD_DIR)/$(APP_NAME) "$(APP_BUNDLE)/Contents/MacOS/"
	@cp $(SRC_DIR)/Resources/Info.plist "$(APP_BUNDLE)/Contents/"
	@cp $(SRC_DIR)/Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/"
	@$(MAKE) --no-print-directory sign
	@echo "✓ Built: $(APP_BUNDLE)"

## Sign the app bundle (ad-hoc, no developer account needed)
sign:
	@printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>com.apple.security.device.audio-input</key>\n\t<true/>\n\t<key>com.apple.security.speech-recognition</key>\n\t<true/>\n</dict>\n</plist>\n' > $(ENTITLEMENTS_FILE)
	@codesign --force --deep --sign - \
		--entitlements $(ENTITLEMENTS_FILE) \
		--preserve-metadata=identifier \
		"$(APP_BUNDLE)" 2>/dev/null && echo "✓ Signed (ad-hoc)" || echo "⚠ Sign skipped"

## Build debug binary and run it directly (no .app bundle)
run:
	@echo "▶ Building debug binary..."
	@mkdir -p $(BUILD_DIR)
	@$(SWIFTC) $(SWIFTFLAGS) $(SOURCES) -o $(BUILD_DIR)/$(APP_NAME) 2>&1 | \
		grep -v "SwiftBridging\|redefinition of module\|previously defined here\|bridging.modulemap\|module.modulemap" || true
	@echo "▶ Running..."
	@$(BUILD_DIR)/$(APP_NAME)

## Install .app to /Applications
install: build
	@echo "▶ Installing to $(INSTALL_DIR)/$(APP_NAME).app..."
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@cp -r "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "✓ Installed. Launch with:"
	@echo "  open '$(INSTALL_DIR)/$(APP_NAME).app'"

## Remove build artifacts
clean:
	@rm -rf $(BUILD_DIR)
	@echo "✓ Cleaned"

help:
	@echo "Targets:"
	@echo "  make build    – Compile and create .app bundle"
	@echo "  make run      – Compile and run immediately"
	@echo "  make install  – Build and install to /Applications"
	@echo "  make clean    – Remove build output"
