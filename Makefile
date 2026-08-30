SCHEME := Astra
PROJECT := Astra.xcodeproj
DERIVED := DerivedData

.PHONY: gen icon project test build archive ipa clean

gen: icon project

icon:
	python3 Scripts/generate_icon.py

project:
	xcodegen generate

test:
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) \
		-destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
		-derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO

build:
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) \
		-destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
		-derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO

archive:
	xcodebuild archive -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Release -destination "generic/platform=iOS" \
		-archivePath build/Astra.xcarchive -derivedDataPath $(DERIVED) \
		CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

ipa: archive
	mkdir -p build/Payload
	cp -R build/Astra.xcarchive/Products/Applications/Astra.app build/Payload/
	cd build && /usr/bin/ditto -c -k --sequesterRsrc --keepParent Payload Astra-unsigned.ipa

clean:
	rm -rf build DerivedData
	xcodegen clean
