#!/usr/bin/env bash

#set -euo pipefail

#./get-guide-channels.sh generate-config  > /media/ext/services/tvheadend/config/.xmltv/tv_grab_uk_tvguide.conf
#./get-guide-channels.sh generate-mapping > /media/ext/services/tvheadend/config/.xmltv/supplement/tv_grab_uk_tvguide/tv_grab_uk_tvguide.map.conf

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
block_list_file=""
#block_list_file="$dir/guide-block-list.txt"
allow_list_file="$dir/guide-allow-list.txt"

get_guides() {
  for systemid in 3 5 25; do
    curl --fail --silent --show-error --location \
      --header 'Content-Type: application/x-www-form-urlencoded' \
      --data-raw "thisDay=&thisTime=&gridSpan=&emailaddress=&regionid=9&systemid=${systemid}&xn=Show+me+the+channels" \
      'https://www.tvguide.co.uk/mychannels.asp'
  done
}

get_all_channels() {
  get_guides |
    grep -Eo "(add|delete)Channel\(([0-9]+),\s*'([^']+)'\)" |
    sed -r "s/^(add|delete)Channel\(([0-9]+),\s*'([^']+)'\)/\2,\3/" |
    sort -u |
    sort -t, -k2
}

get_blocked_channels() {
  awk -F, '{print $2}' "$block_list_file"
}

get_channel_list() {
  if [[ -n "$allow_list_file" ]] && [[ -r "$allow_list_file" ]]; then
    sed -r -e 's/([^[:alnum:]])/\\\1/g' -e 's/^/,/' -e 's/$/\$/' "$allow_list_file" | grep -E -f - <(get_all_channels)
  elif [[ -n "$block_list_file" ]] && [[ -r "$block_list_file" ]]; then
    sed -r -e 's/([^[:alnum:]])/\\\1/g' -e 's/^/,/' -e 's/$/\$/' "$block_list_file" | grep -E -v -f - <(get_all_channels)
  else
    get_all_channels
  fi
}
1012
get_allowed_channels() {
  local id channel

  while read -r channel; do
    id="$(awk -F, '{print $1}' <<<"$channel" | xargs)"
    name="$(awk -F, '{print $2}' <<<"$channel" | xargs)"
    if ! curl --fail --silent --show-error --location --no-buffer "https://www.tvguide.co.uk/channellistings.asp?ch=${id}&cTime=$(date +'%-m/%-d/%Y%%20%-I:00:00%%20%p')&thisTime=&thisDay=" 2>/dev/null | grep -qF '/HighlightImages/'; then
      >&2 printf "channel %s (name=%s) does not seem to have valid pages. Skipping..\n" "$id" "$name"
      continue
    fi

    >&2 printf "channel %s (name=%s) is valid!\n" "$id" "$name"

    echo "$channel"
  done < <(get_channel_list | grep -vE ',$')
}

get_channel_id() {
  sed <<<"$1" -r \
    -e 's/\+1/Plus1/g' \
    -e 's/E!/EEntertainment/g' \
    -e 's/[^a-zA-Z0-9]+//g' \
    -e 's/$/.uk/'
}

get_id_channel_mapping() {
  local channel id name epg_id

  while read -r channel; do
    id="$(awk -F, '{print $1".tvguide.co.uk"}' <<<"$channel" | xargs)"
    name="$(awk -F, '{$1=""; print}' <<<"$channel" | xargs)"
    epg_id="$(get_channel_id "$name")"
    printf "map==%s==%s\n" "$id" "$epg_id"
  done < <(get_allowed_channels)
}

get_tv_grab_channels() {
  [[ -n "${1:-}" ]] && printf "cachedir=%s\n" "$(realpath "$1")"

  awk -F, '{print "channel="$1}' < <(get_allowed_channels) | sort -u
}

case "${1:-}" in
"list-channels") get_channel_list ;;
"generate-config") shift && get_tv_grab_channels "$@" ;;
"generate-mapping") get_id_channel_mapping ;;
*)
  echo "what do with argument '${1:-unspecified}'? I can only do generate-config | generate-mapping"
  exit 1
  ;;
esac
