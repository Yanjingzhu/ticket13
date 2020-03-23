#!/bin/bash

PROVISIONING_PROFILE="MyApp"
CODE_SIGN_IDENTITY="Apple Development: MyApp (XXXXXXXXXX)"
DOMAIN="MyApp.com"
PRODUCT_BUNDLE_IDENTIFIER="com.MyApp.app"

# Get dependencies
function get_dependencies()
{
    yarn
    cd ios
    pod install
    cd ..
}

function decrypt
{
    INPUT=$1
    OUTPUT="${1%.*}"
    openssl aes-256-cbc -salt -a -d -in $INPUT -out $OUTPUT -pass pass:$SECRET_KEY
}

# Decrypt secrets
function decrypt_secrets
{
    export SECRET_KEY=$1
    decrypt .github/ios/secrets/MyApp.mobileprovision.encrypted
    decrypt .github/ios/secrets/MyApp.p12.encrypted
    decrypt .github/ssh/id_rsa.encrypted
}

# Set up code signing
function setup_code_signing()
{
    mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles

    # provisioning
    cp .github/ios/secrets/MyApp.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/$PROVISIONING_PROFILE.mobileprovision

    # keychain
    security create-keychain -p "MyApp" build.keychain
    security import ./.github/ios/secrets/MyApp.p12 -t agg -k ~/Library/Keychains/build.keychain -P "" -A

    security list-keychains -s ~/Library/Keychains/build.keychain
    security default-keychain -s ~/Library/Keychains/build.keychain
    security unlock-keychain -p "MyApp" ~/Library/Keychains/build.keychain

    security set-key-partition-list -S apple-tool:,apple: -s -k "MyApp" ~/Library/Keychains/build.keychain
}

# Build
function build_app()
{
    # dev environment
    echo "API_URL=https://backend.$DOMAIN/" > .env

    # build number
    BUILD_NUMBER=${GITHUB_RUN_NUMBER:-1}

    # ExportOptions.plist
    sed -e "s/__BUILD_NUMBER__/$BUILD_NUMBER/g" \
        -e "s/__PRODUCT_BUNDLE_IDENTIFIER__/$PRODUCT_BUNDLE_IDENTIFIER/g" \
        -e "s/__CODE_SIGN_IDENTITY__/$CODE_SIGN_IDENTITY/g" \
        .github/ios/ExportOptions.plist > ios/ExportOptions.plist

    cd ios

    set -e
    set -o pipefail

    # archive
    xcodebuild archive \
        -workspace MyApp.xcworkspace \
        -scheme MyApp \
        -sdk iphoneos13.2 \
        -configuration Release \
        -archivePath "$PWD/build/MyApp.xcarchive" \
        PRODUCT_BUNDLE_IDENTIFIER="$PRODUCT_BUNDLE_IDENTIFIER" \
        PROVISIONING_PROFILE="$PROVISIONING_PROFILE" \
        CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

    # export
    xcodebuild \
        -exportArchive \
        -archivePath "$PWD/build/MyApp.xcarchive" \
        -exportOptionsPlist "$PWD/ExportOptions.plist" \
        -exportPath "$PWD/build"
}

# Upload artifacts
function upload_artifacts()
{
    chmod 600 .github/ssh/id_rsa
    BUILD_PATH="www/app/builds/$GITHUB_RUN_NUMBER"
    ssh -i .github/ssh/id_rsa -o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' ubuntu@MyApp.dev "mkdir -p $BUILD_PATH"
    scp -i .github/ssh/id_rsa -o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' -r ios/build/Apps/* ubuntu@MyApp.dev:$BUILD_PATH
    scp -i .github/ssh/id_rsa -o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' -r ios/build/manifest.plist ubuntu@MyApp.dev:$BUILD_PATH
}
