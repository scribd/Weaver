DESTDIR := /usr/local

build:
	@swift build --disable-sandbox --configuration release

clean:
	rm -rf .build

install: build
	install -d "$(DESTDIR)/bin"
	install -d "$(DESTDIR)/share/weaver/Resources"
	install -C "Resources/dependency_resolver.stencil" "$(DESTDIR)/share/weaver/Resources"
	install -C -m 755 ".build/release/WeaverCommand" "$(DESTDIR)/bin/weaver"

uninstall:
	rm "$(DESTDIR)/bin/weaver"
	rm -rf "$(DESTDIR)/share/weaver"
