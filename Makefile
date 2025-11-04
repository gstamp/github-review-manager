.PHONY: help build run clean sign sign-dev sign-dist install dmg open check

# Configuration
APP_NAME = GitHubReviewManager
APP_BUNDLE = GitHubReviewManager/.build/$(APP_NAME).app
APP_PATH = $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
INSTALL_PATH = /Applications/$(APP_NAME).app
DMG_NAME = $(APP_NAME).dmg
DMG_VOLNAME = "GitHub Review Manager"

# Default target
help:
	@echo "GitHub Review Manager - Build and Development Commands"
	@echo ""
	@echo "Available targets:"
	@echo "  make build       - Build the application"
	@echo "  make run         - Build and run the application"
	@echo "  make open        - Open the built app (without building)"
	@echo "  make clean       - Remove build artifacts"
	@echo "  make sign        - Code sign with ad-hoc signature (development)"
	@echo "  make sign-dist   - Code sign with Developer ID (requires SIGNING_IDENTITY)"
	@echo "  make install     - Install to /Applications"
	@echo "  make dmg         - Create a DMG for distribution"
	@echo "  make check       - Check if build artifacts exist"
	@echo ""
	@echo "Examples:"
	@echo "  make run                    # Quick build and run"
	@echo "  make sign-dist SIGNING_IDENTITY='Developer ID Application: Your Name (TEAM_ID)'"
	@echo ""

# Build the application
build:
	@echo "Building $(APP_NAME)..."
	@cd GitHubReviewManager && ./build.sh
	@echo ""
	@echo "Build complete: $(APP_BUNDLE)"

# Run the application (builds first)
run: build
	@echo "Running $(APP_NAME)..."
	@if [ -d "$(APP_BUNDLE)" ]; then \
		xattr -cr "$(APP_BUNDLE)" 2>/dev/null || true; \
		open "$(APP_BUNDLE)"; \
	else \
		echo "Error: $(APP_BUNDLE) not found. Run 'make build' first."; \
		exit 1; \
	fi

# Open the app without building
open:
	@if [ -d "$(APP_BUNDLE)" ]; then \
		xattr -cr "$(APP_BUNDLE)" 2>/dev/null || true; \
		open "$(APP_BUNDLE)"; \
	else \
		echo "Error: $(APP_BUNDLE) not found. Run 'make build' first."; \
		exit 1; \
	fi

# Code sign with ad-hoc signature (for development)
sign: $(APP_BUNDLE)
	@echo "Code signing with ad-hoc signature..."
	@codesign --deep --force --sign - "$(APP_BUNDLE)"
	@echo "Signed: $(APP_BUNDLE)"

# Code sign with Developer ID (for distribution)
sign-dist: $(APP_BUNDLE)
	@if [ -z "$(SIGNING_IDENTITY)" ]; then \
		echo "Error: SIGNING_IDENTITY is required for distribution signing."; \
		echo "Example: make sign-dist SIGNING_IDENTITY='Developer ID Application: Your Name (TEAM_ID)'"; \
		exit 1; \
	fi
	@echo "Code signing with Developer ID: $(SIGNING_IDENTITY)"
	@codesign --deep --force --sign "$(SIGNING_IDENTITY)" "$(APP_BUNDLE)"
	@codesign --verify --verbose "$(APP_BUNDLE)"
	@echo "Signed: $(APP_BUNDLE)"

# Create DMG for distribution
dmg: $(APP_BUNDLE)
	@echo "Creating DMG: $(DMG_NAME)..."
	@rm -f "$(DMG_NAME)"
	@hdiutil create -volname $(DMG_VOLNAME) \
		-srcfolder "$(APP_BUNDLE)" \
		-ov -format UDZO \
		"$(DMG_NAME)"
	@echo "DMG created: $(DMG_NAME)"

# Install to /Applications
install: $(APP_BUNDLE)
	@echo "Installing $(APP_NAME) to $(INSTALL_PATH)..."
	@rm -rf "$(INSTALL_PATH)"
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_PATH)"
	@echo "Installed: $(INSTALL_PATH)"
	@echo "You can now launch it from Applications or Spotlight."

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf GitHubReviewManager/.build
	@rm -f $(DMG_NAME)
	@echo "Clean complete."

# Check if app bundle exists
check:
	@if [ -d "$(APP_BUNDLE)" ]; then \
		echo "✓ $(APP_BUNDLE) exists"; \
		ls -lh "$(APP_BUNDLE)"; \
	else \
		echo "✗ $(APP_BUNDLE) not found"; \
		echo "Run 'make build' to create it."; \
		exit 1; \
	fi

