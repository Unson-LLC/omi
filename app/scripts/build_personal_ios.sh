#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <private-defines.json> [derived-data-path]" >&2
  exit 64
fi

defines_file=$1
derived_data_path=${2:-/tmp/omi-personal-derived}
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
ios_dir="$repo_dir/ios"
personal_build_root=$(mktemp -d /tmp/omi-personal-ios.XXXXXX)
personal_ios_dir="$personal_build_root/ios"
personal_project="$personal_ios_dir/Runner.xcodeproj"
personal_workspace="$personal_ios_dir/Runner.xcworkspace"

cleanup() {
  rm -r -- "$personal_build_root" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

# Flutter's Xcode backend expects exactly one .xcodeproj beside the workspace.
# Build from a disposable copy of the complete iOS directory so the upstream
# project remains untouched and project-relative Runner/Pods paths still work.
cp -R "$ios_dir" "$personal_ios_dir"

# Flutter's CocoaPods helper discovers plugin pods from this generated file in
# the parent directory of ios/. The disposable build root only contains the
# copied ios directory, so omitting it silently regenerates Pods without any
# Flutter plugin targets.
flutter_plugins_file="$repo_dir/.flutter-plugins-dependencies"
if [ ! -f "$flutter_plugins_file" ]; then
  echo "Missing $flutter_plugins_file. Run 'flutter pub get' before building." >&2
  exit 66
fi
cp "$flutter_plugins_file" "$personal_build_root/.flutter-plugins-dependencies"

# The checked-in Pods sandbox can lag behind Podfile.lock (for example after a
# dependency lock update that has not yet been installed on this machine).
# Repair only the disposable copy so personal builds stay reproducible without
# mutating the shared checkout.
if ! cmp -s "$personal_ios_dir/Podfile.lock" "$personal_ios_dir/Pods/Manifest.lock"; then
  (
    cd "$personal_ios_dir"
    pod install --no-repo-update
  )
fi

# CocoaPods records Flutter SDK source references relative to the original iOS
# directory. The disposable copy is shallower, so those references would point
# at /toolchains instead of the actual external toolchain. Resolve the Flutter
# root from CocoaPods' integration_test symlink and make only those SDK paths
# absolute in the disposable Pods project.
integration_test_link="$ios_dir/.symlinks/plugins/integration_test"
integration_test_root=$(readlink "$integration_test_link")
flutter_root=$(CDPATH= cd -- "$integration_test_root/../.." && pwd)
pods_project="$personal_ios_dir/Pods/Pods.xcodeproj/project.pbxproj"
ORIGINAL_FLUTTER_ROOT="$flutter_root" perl -0pi -e '
  my $root = $ENV{ORIGINAL_FLUTTER_ROOT};
  s#(?:\.\./)+toolchains/flutter-[^/]+/flutter#$root#g;
' "$pods_project"

# The shared scheme in the upstream project omits BuildActionEntries and relies
# on Xcode UI state. Make the disposable scheme explicit so command-line builds
# always select Runner.
scheme_file="$personal_project/xcshareddata/xcschemes/dev.xcscheme"
perl -0pi -e 's#(<BuildAction\b[^>]*>\s*(?:<PreActions>.*?</PreActions>)?)#$1\n      <BuildActionEntries>\n         <BuildActionEntry\n            buildForTesting = "YES"\n            buildForRunning = "YES"\n            buildForProfiling = "YES"\n            buildForArchiving = "YES"\n            buildForAnalyzing = "YES">\n            <BuildableReference\n               BuildableIdentifier = "primary"\n               BlueprintIdentifier = "97C146ED1CF9000F007C117D"\n               BuildableName = "Runner.app"\n               BlueprintName = "Runner"\n               ReferencedContainer = "container:RunnerPersonal.xcodeproj">\n            </BuildableReference>\n         </BuildActionEntry>\n      </BuildActionEntries>#s' "$scheme_file"
perl -0pi -e 's#container:RunnerPersonal\.xcodeproj#container:Runner.xcodeproj#g' \
  "$scheme_file"

# The upstream watch target is an old generic application target. Current Xcode
# tries to build it as iOS and fails before the personal iPhone app can install.
# Keep upstream intact and remove only the Runner -> watch dependency and embed
# phase from this disposable project copy.
project_file="$personal_project/project.pbxproj"
perl -0pi -e '
  s/^\s*42A7BA3E2E788BD400138969 \/\* omiWatchApp\.app in Embed Watch Content \*\/ = .*?;\n//m;
  s/^\s*422906722E75A21E00F49E67 \/\* Embed Watch Content \*\/ = \{.*?^\s*\};\n//ms;
  s/^\s*422906722E75A21E00F49E67 \/\* Embed Watch Content \*\/,\n//m;
  s/^\s*42A7BA3D2E788BD400138969 \/\* PBXTargetDependency \*\/,\n//m;
' "$project_file"

required_keys='BRAINBASE_FIREBASE_API_KEY BRAINBASE_FIREBASE_APP_ID BRAINBASE_FIREBASE_IOS_BUNDLE_ID BRAINBASE_FIREBASE_IOS_CLIENT_ID BRAINBASE_FIREBASE_MESSAGING_SENDER_ID BRAINBASE_FIREBASE_PROJECT_ID BRAINBASE_FIREBASE_STORAGE_BUCKET BRAINBASE_INGEST_TOKEN BRAINBASE_INGEST_URL'
for key in $required_keys; do
  jq -e --arg key "$key" '.[$key] | type == "string" and length > 0' "$defines_file" >/dev/null || {
    echo "missing required key: $key" >&2
    exit 65
  }
done

dart_defines=$({
  jq -r 'to_entries | map("\(.key)=\(.value|tostring)") | .[]' "$defines_file"
  printf '%s\n' \
    'OMI_PERSONAL_E2E_BUILD=true' \
    'OMI_FIXTURE_REPLAY_ENABLED=true' \
    'OMI_FIXTURE_REPLAY_ON_START=true' \
    'OMI_FIXTURE_REPLAY_ASSET=test/fixtures/audio/synthetic_pcm16_v1.json'
} | while IFS= read -r item; do
  printf '%s' "$item" | base64 | tr -d '\n'
  printf ','
done)
dart_defines=${dart_defines%,}

mkdir -p "$personal_ios_dir/Config/Personal"
if [ ! -f "$personal_ios_dir/Config/Personal/Minimal.entitlements" ]; then
  printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
    '<plist version="1.0"><dict/></plist>' >"$personal_ios_dir/Config/Personal/Minimal.entitlements"
fi

cd "$repo_dir"
# A Debug Flutter engine cannot start when the app is launched directly on a
# physical iPhone without an attached Flutter debugger. Personal installs must
# therefore use the standalone-capable release configuration.
xcodebuild \
  -workspace "$personal_workspace" \
  -scheme dev \
  -configuration Release-dev \
  -sdk iphoneos \
  -derivedDataPath "$derived_data_path" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=9585RQB8F7 \
  CODE_SIGN_STYLE=Automatic \
  APP_BUNDLE_IDENTIFIER=jp.brainbase.omi.ksato.dev \
  DART_DEFINES="$dart_defines" \
  CODE_SIGN_ENTITLEMENTS="$personal_ios_dir/Config/Personal/Minimal.entitlements" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=YES \
  build
