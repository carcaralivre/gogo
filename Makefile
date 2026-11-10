APP     := GoGo
VERSION := $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
BUNDLE  := build/$(APP).app
BIN     := .build/release/$(APP)
UBIN    := .build/out/Products/Release/$(APP)
ICNS    := Resources/AppIcon.icns
SOURCES := $(wildcard Sources/GoGo/*.swift) Package.swift
DIST    := dist
DMG     := $(DIST)/$(APP)-$(VERSION).dmg
ZIP     := $(DIST)/$(APP)-$(VERSION).zip

.PHONY: build universal app icon install run dist clean

build: $(BIN)

$(BIN): $(SOURCES)
	swift build -c release

# Binário universal (Apple Silicon + Intel) para distribuir a outros Macs.
# Sempre refaz: o build normal grava no mesmo caminho, só com arm64.
universal:
	swift build -c release --arch arm64 --arch x86_64
	@lipo -archs $(UBIN) | grep -q x86_64 || (echo "binário não é universal"; exit 1)

$(ICNS): Scripts/make-icon.swift
	swift Scripts/make-icon.swift build/icon $(ICNS)

icon:
	rm -f $(ICNS)
	$(MAKE) $(ICNS)

# Monta o .app a partir de um binário ($(1)) numa pasta destino ($(2)).
define bundle
	rm -rf $(2)
	mkdir -p $(2)/Contents/MacOS $(2)/Contents/Resources
	cp $(1) $(2)/Contents/MacOS/$(APP)
	cp Resources/Info.plist $(2)/Contents/Info.plist
	cp $(ICNS) $(2)/Contents/Resources/AppIcon.icns
	printf 'APPL????' > $(2)/Contents/PkgInfo
	xattr -cr $(2)
	codesign --force --deep --sign - $(2)
endef

app: $(BIN) $(ICNS)
	$(call bundle,$(BIN),$(BUNDLE))
	@echo "✓ $(BUNDLE)"

install: app
	-pkill -x $(APP)
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/$(APP).app
	open /Applications/$(APP).app
	@echo "✓ GoGo instalado e aberto"

run: app
	-pkill -x $(APP)
	open $(BUNDLE)

# DMG (arraste para Aplicativos) + zip, binário universal, assinatura ad-hoc.
# Tudo é montado numa pasta temporária: dentro de pastas sincronizadas (iCloud Drive,
# ~/Documents) o file provider grava FinderInfo no .app e isso invalida a assinatura.
# O DMG também não usa -srcfolder pelo mesmo motivo; é imagem vazia + ditto + convert.
dist: universal $(ICNS)
	rm -rf $(DIST) && mkdir -p $(DIST)
	set -e; \
	STAGE=$$(mktemp -d "$${TMPDIR:-/tmp}/gogo-dist.XXXXXX"); \
	APPDIR="$$STAGE/$(APP).app"; \
	mkdir -p "$$APPDIR/Contents/MacOS" "$$APPDIR/Contents/Resources" "$$STAGE/mnt" "$$STAGE/zip"; \
	cp $(UBIN) "$$APPDIR/Contents/MacOS/$(APP)"; \
	cp Resources/Info.plist "$$APPDIR/Contents/Info.plist"; \
	cp $(ICNS) "$$APPDIR/Contents/Resources/AppIcon.icns"; \
	printf 'APPL????' > "$$APPDIR/Contents/PkgInfo"; \
	xattr -cr "$$APPDIR"; \
	codesign --force --deep --sign - "$$APPDIR"; \
	codesign --verify --deep --strict "$$APPDIR"; \
	ditto -c -k --keepParent "$$APPDIR" "$$STAGE/$(APP).zip"; \
	hdiutil create -quiet -fs APFS -size 32m -volname "$(APP) $(VERSION)" -ov "$$STAGE/rw.dmg"; \
	hdiutil attach -quiet -nobrowse -mountpoint "$$STAGE/mnt" "$$STAGE/rw.dmg"; \
	ditto "$$APPDIR" "$$STAGE/mnt/$(APP).app"; \
	ln -s /Applications "$$STAGE/mnt/Aplicativos"; \
	hdiutil detach -quiet "$$STAGE/mnt"; \
	hdiutil convert -quiet -format UDZO -ov -o "$$STAGE/$(APP).dmg" "$$STAGE/rw.dmg"; \
	hdiutil attach -quiet -readonly -nobrowse -mountpoint "$$STAGE/mnt" "$$STAGE/$(APP).dmg"; \
	codesign --verify --deep --strict "$$STAGE/mnt/$(APP).app" && echo "✓ assinatura ok no DMG"; \
	hdiutil detach -quiet "$$STAGE/mnt"; \
	ditto -x -k "$$STAGE/$(APP).zip" "$$STAGE/zip"; \
	codesign --verify --deep --strict "$$STAGE/zip/$(APP).app" && echo "✓ assinatura ok no zip"; \
	echo "arquiteturas: $$(lipo -archs "$$STAGE/zip/$(APP).app/Contents/MacOS/$(APP)")"; \
	cp "$$STAGE/$(APP).dmg" $(DMG); \
	cp "$$STAGE/$(APP).zip" $(ZIP); \
	rm -rf "$$STAGE"
	@echo "✓ $(DMG)"
	@echo "✓ $(ZIP)"

clean:
	rm -rf build .build $(DIST)
