#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <private-defines.json> <output.plist>" >&2
  exit 64
fi

defines_file=$1
output_file=$2
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
template_file="$script_dir/../setup/prebuilt/GoogleService-Info-Local.plist"

require_value() {
  value=$(jq -er --arg key "$1" '.[$key] | select(type == "string" and length > 0)' "$defines_file") || {
    echo "missing required key: $1" >&2
    exit 65
  }
  printf '%s' "$value"
}

api_key=$(require_value BRAINBASE_FIREBASE_API_KEY)
app_id=$(require_value BRAINBASE_FIREBASE_APP_ID)
sender_id=$(require_value BRAINBASE_FIREBASE_MESSAGING_SENDER_ID)
project_id=$(require_value BRAINBASE_FIREBASE_PROJECT_ID)
storage_bucket=$(require_value BRAINBASE_FIREBASE_STORAGE_BUCKET)
bundle_id=$(require_value BRAINBASE_FIREBASE_IOS_BUNDLE_ID)
client_id=$(require_value BRAINBASE_FIREBASE_IOS_CLIENT_ID)

case "$client_id" in
  *.apps.googleusercontent.com)
    client_prefix=${client_id%.apps.googleusercontent.com}
    reversed_client_id="com.googleusercontent.apps.$client_prefix"
    ;;
  *)
    echo "invalid BRAINBASE_FIREBASE_IOS_CLIENT_ID format" >&2
    exit 65
    ;;
esac

mkdir -p "$(dirname "$output_file")"
cp "$template_file" "$output_file"

/usr/libexec/PlistBuddy -c "Set :API_KEY $api_key" "$output_file"
/usr/libexec/PlistBuddy -c "Set :GOOGLE_APP_ID $app_id" "$output_file"
/usr/libexec/PlistBuddy -c "Set :GCM_SENDER_ID $sender_id" "$output_file"
/usr/libexec/PlistBuddy -c "Set :PROJECT_ID $project_id" "$output_file"
/usr/libexec/PlistBuddy -c "Set :STORAGE_BUCKET $storage_bucket" "$output_file"
/usr/libexec/PlistBuddy -c "Set :BUNDLE_ID $bundle_id" "$output_file"
/usr/libexec/PlistBuddy -c "Add :CLIENT_ID string $client_id" "$output_file"
/usr/libexec/PlistBuddy -c "Add :REVERSED_CLIENT_ID string $reversed_client_id" "$output_file"
plutil -lint "$output_file" >/dev/null

echo "generated personal Firebase plist at $output_file"
