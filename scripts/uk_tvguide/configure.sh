#!/usr/bin/env bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

channelsFile="$dir/channels.txt"

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

get_channel_list() {
  sed -r -e 's/([^[:alnum:]])/\\\1/g' -e 's/^/,/' -e 's/$/\$/' "$channelsFile" | grep -E -f - <(get_all_channels)
}

get_allowed_channels() {
  local id channel content

  while read -r channel; do
    id="$(awk -F',' '{print $1}' <<<"$channel" | xargs)"
    name="$(awk -F',' '{print $2}' <<<"$channel" | xargs)"
    content="$(curl --fail --silent --show-error --location --no-buffer "https://www.tvguide.co.uk/channellistings.asp?ch=${id}&cTime=$(date +'%-m/%-d/%Y%%20%-I:00:00%%20%p')&thisTime=&thisDay=")"
    if ! grep -qF '/HighlightImages/' <<<"$content"; then
      printf >&2 "channel %s (name=%s) does not seem to have valid pages. Skipping..\n" "$id" "$name"
      continue
    fi

    printf >&2 'channel %s (name=%s) is valid!\n' "$id" "$name"

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
  local id name epg_id conf_file
  conf_file="${1:-}"

  while IFS=, read -r id name; do
    id="$(awk -F',' '{print $1".tvguide.co.uk"}' <<<"$id" | xargs)"
    epg_id="$(get_channel_id "$name")"
    printf "map==%s==%s\n" "$id" "$epg_id"
  done < <(
    if [[ -n "$conf_file" ]]; then
      awk -F'=' '/^channel=/{print "^"$2","}' "$conf_file" | grep -E -f - <(get_channel_list)
    else
      get_allowed_channels
    fi
  )
}

get_tv_grab_channels() {
  [[ -n "${1:-}" ]] && printf "cachedir=%s\n" "$(realpath "$1")"

  awk -F',' '{print "channel="$1}' < <(get_allowed_channels) | sort -u
}

main() {
  mkdir -p "$HOME/.xmltv/supplement/tv_grab_uk_tvguide"
  get_tv_grab_channels "$HOME/.xmltv/cache" >"$HOME/.xmltv/tv_grab_uk_tvguide.conf"
  get_id_channel_mapping "$HOME/.xmltv/tv_grab_uk_tvguide.conf" >"$HOME/.xmltv/supplement/tv_grab_uk_tvguide/tv_grab_uk_tvguide.map.conf"
}

main
