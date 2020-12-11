#!/usr/bin/env bash

#set -euo pipefail

#./get-guide-channels.sh generate-config  > /media/ext/services/tvheadend/config/.xmltv/tv_grab_uk_tvguide.conf
#./get-guide-channels.sh generate-mapping > /media/ext/services/tvheadend/config/.xmltv/supplement/tv_grab_uk_tvguide/tv_grab_uk_tvguide.map.conf

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
block_list_file=""
#block_list_file="$dir/guide-block-list.txt"
allow_list_file="$dir/guide-allow-list.txt"

get_guides() {
  wget -qO- 'https://www.tvguide.co.uk' |
    grep -Eo "loadSystem\('[^\']+'\)" |
    awk -F\' '{print $2}' |
    while read -r systemId; do
      echo "-----------------------------"
      echo "$systemId"
      wget -qO- "https://www.tvguide.co.uk/?systemid=$systemId"
      echo "-----------------------------"
    done
}

get_all_channels() {
  # todo maybe better:
  #  awk -e '/\s*<select name="channelid">/,/<\/select>\s*/' guides | grep -F '<option' | perl -CIO -pe 's/<option value=([^>]+)>([^<]+)<\/option>/$1,$2\n/g'
  get_guides |
    grep -Eo 'channellistings.asp\?ch=[0-9]+.*title="[^"]+"' |
    sed -r \
      -e 's/.*ch=([0-9]+).*title="([^"]+)".*/\1,\2/' \
      -e 's/ TV listings$//' |
    sort -t, -k2 -u
}

get_blocked_channels() {
  awk -F, '{print $2}' "$block_list_file"
}

get_allowed_channels() {
  if [[ -n "$allow_list_file" ]] && [[ -r "$allow_list_file" ]]; then
    cat "$allow_list_file"
  elif [[ -n "$block_list_file" ]] && [[ -r "$block_list_file" ]]; then
    grep -v -f <(get_blocked_channels) <(get_all_channels)
  else
    get_all_channels
  fi
}

get_channel_id() {
  channel_id="$1"
  channel_id="$(sed -r -e 's/\+1/Plus1/g' <<<"$channel_id")"
  channel_id="$(sed -r -e 's/E!/EEntertainment/g' <<<"$channel_id")"
  channel_id="$(sed -r -e 's/[^a-zA-Z0-9]+//g' <<<"$channel_id")"
  printf "%s.uk" "$channel_id" | xargs
}

get_id_channel_mapping() {
  while read -r channel; do
    id="$(awk -F, '{print $1}' <<<"$channel" | xargs)"
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
"generate-config") shift; get_tv_grab_channels "$@" ;;
"generate-mapping") get_id_channel_mapping ;;
*)
  echo "what do with argument '${1:-unspecified}'? I can only do generate-config | generate-mapping"
  exit 1
  ;;
esac
