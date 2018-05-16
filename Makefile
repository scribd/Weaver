
.PHONY: clean

build:
	$(call build)

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

define build
	@swift build --disable-sandbox --configuration release
endef

define install_files
	install -d $(1)/bin
	install -d $(1)/share/weaver/Resources
	install -C Resources/dependency_resolver.stencil $(1)/share/weaver/Resources
	install -C -m 755 .build/release/WeaverCommand $(1)/bin/weaver
endef
