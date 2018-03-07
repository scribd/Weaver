DESTDIR := /usr/local

build:
	@swift build --configuration release

clean:
	rm -rf .build

install: build
	install -d "$(DESTDIR)/bin"
	install -d "$(DESTDIR)/share/beaverdi"
	cp -r "Resources" "$(DESTDIR)/share/beaverdi"
	install -C -m 755 ".build/release/BeaverDICommand" "$(DESTDIR)/bin/beaverdi"

uninstall:
	rm "$(DESTDIR)/bin/beaverdi"
	rm -rf "$(DESTDIR)/share/beaverdi"
