flutter build xcarchive --release
if [ -d "./build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app" ]; then
    echo "build success"
    mkdir Payload
    cp -r ./build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app ./Payload/
    zip -r ftp-manager.ipa Payload
    rm -rf Payload
else
    echo "build failed"
fi