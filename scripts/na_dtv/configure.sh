#!/usr/bin/env bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

zip=30016
timezone=America/New_York
channelsFile="$dir/channels.txt"

siteBase="http://www.directv.com"
channelListURL="$siteBase/json/channels"

get_tv_grab_channels() {
  channelsJson="$(jq <"$channelsFile" --slurp -R -c 'split("\n")[:-1]')"

  cat <<EOF
zip=${zip}
timezone=${timezone}
EOF
  curl -fsSL "$channelListURL" | jq -r --argjson channels "${channelsJson}" '.channels[] | "channel\(if .chName | IN($channels[]) then "=" else "!" end)\(("0" * (4-(.chId|tostring|length)))+(.chId|tostring)).directv.com" '
}

main() {
  get_tv_grab_channels "$HOME/.xmltv/cache" >"$HOME/.xmltv/tv_grab_na_dtv.conf"
}

main
