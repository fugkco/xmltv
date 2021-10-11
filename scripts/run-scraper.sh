#!/usr/bin/env bash

set -euxo pipefail

event_name="$1"
event_input_days="${2:-}"

mkdir -p xmltv

./scripts/get-guide-channels.sh generate-config "$HOME/.xmltv/cache" > "$HOME/.xmltv/tv_grab_uk_tvguide.conf"
./scripts/get-guide-channels.sh generate-mapping "$HOME/.xmltv/tv_grab_uk_tvguide.conf" > "$HOME/.xmltv/supplement/tv_grab_uk_tvguide/tv_grab_uk_tvguide.map.conf"

days=1
offset=0
case "$event_name" in
  workflow_dispatch) days=$event_input_days; ;;
  schedule)
    offset=7
    days=0
    latest_release="$(git tag -l | sort -V | tail -n1)"
    new_release_start="$(date '+%Y%m%d')"

    curl --fail --silent --show-error --location \
       --output "$latest_release.xml" \
        "https://github.com/fugkco/xmltv/releases/download/${latest_release}/uk_tvguide.xml"
    tv_split --output 'xmltv/split-%Y%m%d.xml' "$latest_release.xml"

    echo "latest_release < new_release_start"
    while (( new_release_start > latest_release )); do
      echo "$latest_release < $new_release_start"
      new_release_start="$(date -d "${new_release_start} - 1 day" +%Y%m%d)"
      : $(( offset-- ))
      : $(( days++ ))
    done
esac

# ignore errors as it will still output the XML for valid channels
/usr/bin/tv_grab_uk_tvguide --days "$days" --offset "$offset" --quiet > "xmltv/uk_tvguide.xml" || true

tv_sort --by-channel --output xmltv/uk_tvguide.xml xmltv/uk_tvguide.xml
find xmltv -name "split-*" -print0 | sort --zero-terminated --version-sort | tail --zero-terminated --lines=6 | xargs -t -0 tv_sort --by-channel --output xmltv/uk_tvguide_hist.xml

tv_count -i xmltv/uk_tvguide.xml
tv_merge -t -i "xmltv/uk_tvguide_hist.xml" -m xmltv/uk_tvguide.xml -o xmltv/uk_tvguide.xml
tv_count -i xmltv/uk_tvguide.xml
