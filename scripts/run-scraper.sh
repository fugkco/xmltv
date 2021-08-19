#!/usr/bin/env bash

set -euxo pipefail

event_name="$1"
event_input_days="${2:-}"

./scripts/get-guide-channels.sh generate-config /config/.xmltv/cache > /config/.xmltv/tv_grab_uk_tvguide.conf
./scripts/get-guide-channels.sh generate-mapping > /config/.xmltv/supplement/tv_grab_uk_tvguide/tv_grab_uk_tvguide.map.conf

days=1
offset=0
case "$event_name" in
  workflow_dispatch) days=$event_input_days; ;;
  schedule)
    offset=7
    days=0
    latest_release="$(git tag -l | sort -V | tail -n1)"
    new_release="$(date '+%Y%m%d')"

    echo "latest_release < new_release"
    while (( new_release > latest_release )); do
      echo "$latest_release < $new_release"
      new_release="$(date -d "${new_release} - 1 day" +%Y%m%d)"
      : $(( offset-- ))
      : $(( days++ ))
    done
esac

mkdir -p xmltv
# ignore errors as it will still output the XML for valid channels
/usr/bin/tv_grab_uk_tvguide --days "$days" --offset "$offset" --quiet > xmltv/uk_tvguide.xml || true
cat xmltv/uk_tvguide.xml
