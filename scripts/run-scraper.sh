#!/usr/bin/env bash

set -euxo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

grabber="$1"
event_name="$2"
event_input_days="${3:-}"

mkdir -p "xmltv" "$HOME/.xmltv"

if [[ ! -d "$dir/$grabber" ]]; then
  printf "invalid grabber"
  exit 1
fi

if [[ -f "$dir/$grabber/configure.sh" ]]; then
  "$dir/$grabber/configure.sh"
fi

latest_release="$(git tag -l | sort -V | tail -n1)"
# need to get the first release going before we can remove this if statement
if curl --fail --silent --show-error --location \
  --output "$latest_release.xml" \
  "https://github.com/fugkco/xmltv/releases/download/${latest_release}/$grabber.xml"; then
  tv_split --output "xmltv/${grabber}-split-%Y%m%d.xml" "$latest_release.xml"
fi

days=1
offset=0
case "$event_name" in
push) true ;;
workflow_dispatch) days=$event_input_days ;;
schedule)
  offset=7
  days=1
  new_release_start="$(date '+%Y%m%d')"

  echo "latest_release < new_release_start"
  while ((new_release_start > latest_release)); do
    echo "$latest_release < $new_release_start"
    new_release_start="$(date -d "${new_release_start} - 1 day" +%Y%m%d)"
    : $((offset--))
    : $((days++))
  done
  ;;
esac

# ignore errors as it will still output the XML for valid channels
"/usr/bin/tv_grab_$grabber" --days "$days" --offset "$offset" --quiet >"xmltv/$grabber.xml" || true

tv_sort --by-channel --output "xmltv/$grabber.xml" "xmltv/$grabber.xml" || true
find xmltv -name "${grabber}-split-*" -print0 | sort --zero-terminated --version-sort | tail --zero-terminated --lines=6 | xargs -r -t -0 tv_sort --by-channel --output "xmltv/${grabber}_hist.xml"

tv_count -i "xmltv/$grabber.xml"
if [[ -f "xmltv/${grabber}_hist.xml" ]]; then
  tv_merge -t -i "xmltv/${grabber}_hist.xml" -m "xmltv/$grabber.xml" -o "xmltv/$grabber.xml"
  tv_count -i "xmltv/$grabber.xml"
fi
