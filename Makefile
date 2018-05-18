.PHONY: clean build install package generate_sources test codecov

build:
	$(call build)

generate_sources:
	$(call generate_sources)

clean:
	rm -rf .build

install:
	$(call build)
	$(call install_files,/usr/local) 

package:
	$(call build)
	$(call install_files,./build/package/weaver)
	cd ./build/package/ && zip -r ../../weaver.zip ./weaver

uninstall:
	rm "$(DESTDIR)/bin/weaver"
	rm -rf "$(DESTDIR)/share/weaver"

test:
	@swift test 
	@(call install)
	bash -c "cd Sample && fastlane test"

codecov:
	$(call build)
	xcodebuild test -scheme Tests -enableCodeCoverage YES
	bash -c "bash <(curl -s https://codecov.io/bash) -J Weaver -t eaa7c4af-5ca2-4e08-8f07-38a44671e5e0"
	rm *.coverage.txt

define generate_sources
    .sourcery/bin/sourcery
endef

define build
	$(call generate_sources)
	@swift build --disable-sandbox --configuration release
endef

define install_files
	install -d $(1)/bin
	install -d $(1)/share/weaver/Resources
	install -C Resources/dependency_resolver.stencil $(1)/share/weaver/Resources
	install -C -m 755 .build/release/WeaverCommand $(1)/bin/weaver
endef
