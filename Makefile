# Special Kids — build and release (same flow as ../darksurf).
#
#   make check              verify everything a release needs
#   make release            next patch version (or VERSION=x.y.z): signed APK + update feed → dist/<app>/<version>/
#   make publish            upload the last release; installed copies offer the update in the parent area
#   make ship               release + publish in one go          (NOTES="..." sets the release notes)
#   make testflight         iPhone/iPad: archive and upload to App Store Connect for TestFlight
#   make install            install the last release APK on the connected Android device (adb)
#   make test               all tests (packages + apps)
#   make android-keys       create the Android release signing key (once; back it up!)
#
#   APP=snackbeats (default) | specialkids | colorbeats   picks the app; each has its own VERSION file.
#
# Releases go to the public repo shared by all apps, so everything is namespaced by APP:
#   <APP>-v<version>   one release per version, holding the APK
#   <APP>-feed         a fixed release holding latest.json, replaced on every publish
# Installed apps poll FEED_URL (Android). Android installs an update only if it is signed with the same
# key as the installed app. Never rename APP, FEED_TAG, the application ids, or lose the signing key.

APP            ?= snackbeats
RELEASES_REPO  ?= giapnguyen74/app-releases
TEAM_ID        ?= 99S4H9W8U5
FEED_TAG       := $(APP)-feed
FEED_URL       := https://github.com/$(RELEASES_REPO)/releases/download/$(FEED_TAG)/latest.json
KEYSTORE       ?= $(HOME)/.special-kids/android-release.jks
KEY_SERVICE    := special-kids-android-keystore
ADB            ?= $(HOME)/Library/Android/sdk/platform-tools/adb
export ANDROID_HOME ?= $(HOME)/Library/Android/sdk

ifeq ($(APP),snackbeats)
  DIR := apps/snack_beats
  NAME := SnackBeats
  TITLE := Snack Beats
else ifeq ($(APP),colorbeats)
  DIR := apps/color_beats
  NAME := ColorBeats
  TITLE := Color Beats
else ifeq ($(APP),specialkids)
  DIR := apps/special_kids
  NAME := SpecialKids
  TITLE := Special Kids
else
  $(error APP must be snackbeats, specialkids or colorbeats)
endif

CURRENT := $(shell cat $(DIR)/VERSION)
NEXT    := $(shell awk -F. '{ printf "%d.%d.%d", $$1, $$2, $$3 + 1 }' $(DIR)/VERSION)
VERSION ?= $(NEXT)
NOTES   ?=

.PHONY: check release publish ship testflight install test android-keys clean

check:
	@ok=1; \
	if [ -f "$(KEYSTORE)" ]; then echo "✓ android signing key"; else echo "✗ signing key missing: make android-keys"; ok=0; fi; \
	if security find-generic-password -s $(KEY_SERVICE) -w >/dev/null 2>&1; then echo "✓ key password in Keychain"; \
	else echo "✗ key password not in Keychain ($(KEY_SERVICE))"; ok=0; fi; \
	if gh auth status >/dev/null 2>&1; then echo "✓ gh logged in"; else echo "✗ gh not logged in: gh auth login -h github.com"; ok=0; fi; \
	if gh repo view $(RELEASES_REPO) >/dev/null 2>&1; then echo "✓ releases repo $(RELEASES_REPO)"; \
	else echo "✗ releases repo $(RELEASES_REPO) not reachable"; ok=0; fi; \
	[ $$ok = 1 ]

release: check
	@echo "Releasing $(TITLE) $(CURRENT) → $(VERSION)"
	APP=$(APP) DIR=$(DIR) NAME=$(NAME) VERSION=$(VERSION) FEED_URL="$(FEED_URL)" KEYSTORE="$(KEYSTORE)" \
	KEY_SERVICE=$(KEY_SERVICE) DOWNLOAD_PREFIX="https://github.com/$(RELEASES_REPO)/releases/download/$(APP)-v$(VERSION)/" \
	scripts/release.sh
	echo "$(VERSION)" > $(DIR)/VERSION

# Upload the APK first, then swap the feed, so the feed never points at a missing file.
publish:
	@v=$$(cat $(DIR)/VERSION); dir=dist/$(APP)/$$v; apk=$$dir/$(NAME)-$$v.apk; \
	if [ ! -f $$apk ] || [ ! -f $$dir/latest.json ]; then echo "No release in $$dir. Run: make release APP=$(APP)"; exit 1; fi; \
	if gh release view $(APP)-v$$v --repo $(RELEASES_REPO) >/dev/null 2>&1; then \
		echo "$(TITLE) $$v is already published. For a new version run: make ship APP=$(APP)"; exit 1; fi; \
	notes="$(NOTES)"; notes="$${notes:-$(TITLE) $$v}"; \
	python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["notes"]=sys.argv[2]; json.dump(d,open(p,"w"),ensure_ascii=False,indent=2)' $$dir/latest.json "$$notes" && \
	gh release create $(APP)-v$$v $$apk --repo $(RELEASES_REPO) \
		--title "$(TITLE) $$v (Android)" --notes "$$notes" --latest=false && \
	{ gh release view $(FEED_TAG) --repo $(RELEASES_REPO) >/dev/null 2>&1 || \
	  gh release create $(FEED_TAG) --repo $(RELEASES_REPO) --title "$(TITLE) update feed" --latest=false \
		--notes "Update feed for $(TITLE). Do not delete or rename: installed copies check it for updates."; } && \
	gh release upload $(FEED_TAG) $$dir/latest.json --repo $(RELEASES_REPO) --clobber && \
	echo "Published $(TITLE) $$v: https://github.com/$(RELEASES_REPO)/releases/tag/$(APP)-v$$v" && \
	echo "Installed copies show the update in the parent area on their next check."

ship:
	$(MAKE) release APP=$(APP) VERSION=$(VERSION)
	$(MAKE) publish APP=$(APP) NOTES="$(NOTES)"

# App Store Connect API key for uploads (shared with ../darksurf). The .p8 stays in ~/.appstoreconnect/private_keys.
ASC_KEY_ID    ?= WA7S7UNP5G
ASC_ISSUER_ID ?= 69a6de7f-ce2f-47e3-e053-5b8c7c11a4d1

testflight:
	APP=$(APP) DIR=$(DIR) TEAM_ID=$(TEAM_ID) VERSION=$(CURRENT) ASC_KEY_ID=$(ASC_KEY_ID) ASC_ISSUER_ID=$(ASC_ISSUER_ID) \
	scripts/ios.sh testflight

install:
	@v=$$(cat $(DIR)/VERSION); $(ADB) install -r dist/$(APP)/$$v/$(NAME)-$$v.apk

test:
	@for d in packages/sk_core packages/snack_beats_game packages/color_beats_game apps/special_kids apps/snack_beats apps/color_beats; do \
		printf '%-28s ' $$d; (cd $$d && flutter test 2>&1 | tail -1) || exit 1; done

android-keys:
	scripts/android-keys.sh

clean:
	rm -rf apps/*/build packages/*/build
