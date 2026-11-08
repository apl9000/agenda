# Release build plus the ad-hoc signature that binds the embedded Info.plist.
# See Scripts/sign-adhoc.sh. No Developer ID.

BINARY ?= .build/release/agenda

.PHONY: release sign-adhoc

release:
	swift build -c release
	$(MAKE) sign-adhoc

sign-adhoc:
	./Scripts/sign-adhoc.sh "$(BINARY)"
