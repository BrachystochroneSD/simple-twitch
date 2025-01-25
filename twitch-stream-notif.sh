. "/usr/share/simple-twitch/simple-twitch-lib.sh"

CHANNELS_FILE="$CONFIG_DIR/listchanneltwitch"

CACHE_CHANNEL_LIVE="$CACHE_DIR/channel_live"

touch "$CACHE_CHANNEL_LIVE"

get_all_saved_live_channel() {
    params=$(awk '{printf "user_login="$1"&"}' "$CHANNELS_FILE")
    twitch_data=$(curl_get "streams" "$params")
    length=$(echo "$twitch_data" | jq -r '.data | length')
    [ "$length" = 0 ] && return 0
    echo "$twitch_data" | jq -r '.data[] | .user_name'
}

streams=$(get_all_saved_live_channel)

if [ -n "$streams" ]; then
    filter=$(cat $CACHE_CHANNEL_LIVE)
    [ -z "$filter" ] && filter="Quelque chose qui sera jamais filtré"
    echo "$streams" | grep -v "$filter" | while read channel; do
        echo "$channel"
        notif "$channel is now streaming!"
    done
else
    echo "Nobody is streaming"
fi

echo "$streams" > "$CACHE_CHANNEL_LIVE"
