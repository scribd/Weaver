VERSION := $(shell /bin/cat .version)
PREFIX=/usr/local
SWIFT_BUILD_FLAGS=--configuration release

.PHONY: clean build install package codecov

init:
	@swift package generate-xcodeproj

build:
	@swift build --disable-sandbox $(SWIFT_BUILD_FLAGS)

clean:
	rm -rf .build

install: build
	$(call install_files,$(PREFIX)) 

uninstall:
	rm "$(PREFIX)/bin/weaver"
	rm -rf "$(PREFIX)/share/weaver"

package: build
	$(call install_files,./build/package/weaver)
	mv ./build/package/weaver/bin/weaver ./build/package/weaver/bin/weaver_command
	install -C ./tools/weaver.sh ./build/package/weaver/bin/weaver
	install -C LICENSE ./build/package/weaver/LICENSE
	
	cd ./build/package/ && zip -r ../../weaver-$(VERSION).zip ./weaver

codecov: build
	xcodebuild test -scheme Weaver-Package -enableCodeCoverage YES
	bash -c "bash <(curl -s https://codecov.io/bash) -J Weaver -t eaa7c4af-5ca2-4e08-8f07-38a44671e5e0"
	rm *.coverage.txt

define install_files
	install -d $(1)/bin
	install -C .build/release/Weaver $(1)/bin/weaver
endef