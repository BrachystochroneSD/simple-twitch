#!/bin/sh

. "/usr/share/simple-twitch/simple-twitch-lib.sh"

CONFIG_FILE="/etc/simple-twitch.conf"

. "$CONFIG_FILE"

[ -z "$MENU_CMD" ] && MENU_CMD="dmenu"
[ -z "$CHAT_CMD" ] && CHAT_CMD="firefox --new-window"
[ -z "$MAX_VID" ] && MAX_VID=100

TIME_FILE="$CACHE_DIR/vod_histo"
TEMP_TIME=$(mktemp)

CACHE_CHANNEL_LIVE="$CACHE_DIR/channel_live"
CHANNELS_FILE="$CONFIG_DIR/listchanneltwitch"
GAMES_FILE="$CONFIG_DIR/listgamestwitch"

touch $GAMES_FILE
touch $CHANNELS_FILE

LOGROOT="$APPNAME:MENU"

LAST_STREAM_FILE="$CACHE_DIR/last_streamer"
touch "$LAST_STREAM_FILE"

OFFSET=0

search_categories() {
    query=$1
    curl_data=$(curl_get "search/categories" "query=$1" t)
    echo "$curl_data" | jq -r '.data[] | "\(.id);\(.name);\(.box_art_url)" '
}

search_channels() {
    query=$1
    curl_data=$(curl_get "search/channels" "query=$1" t)
    echo "$curl_data" | jq -r '.data[] | "\(.id);\(.broadcaster_language);\(.display_name);\(.thumbnail_url)"'
}

get_user_id() {
    log "Get User ID"
    local user_id="$1" key1= key2= curl_data=
    echo "$input" | grep -q "^[0-9]+$" && { key1="id";key2="login"; } || { key1="login";key2="id"; }
    curl_data=$(curl_get "users" "$key1=$user_id" t)
    echo "$curl_data" | jq -r ".data[] | .$key2"
}

launch_stream() {
    stream=$1
    echo "Launching Stream $stream"
    exec $CHAT_CMD "https://www.twitch.tv/popout/$stream/chat?darkpopout" & mpv "https://www.twitch.tv/$(echo $stream | tr [A-Z] [a-z])"
}

choose_stream() {
    twitch_data=$1 auto_launch=$2

    log "twitch_data: $1" 2
    length=$(echo "$twitch_data" | jq -r '.data | length')
    [ "$length" = 0 ] && aborted "Nothing found"

    streams=$(echo "$twitch_data" | jq -r '.data[] | "\(.user_name);\(.game_name);\(.title);\(.language);\(.viewer_count)"') || aborted "Problem during parsing of jq data"

    log "streams: $streams"
    log "length: $length"

    if [ -n "$auto_launch" ] && [ "$length" = 1 ]; then
        log "Only one streamer found, launching it"
        echo "$streams" | awk -F ";" '{print $1}'
        return 0
    fi

    stream_list=$(echo "$streams" | awk -F ";" '{printf "(%s) %20s : %s \"%s\" %s\n",$4,$1,$2,$3,$5}')

    log "stream_list: $stream_list"
    chosen_stream=$(echo "$stream_list" | $MENU_CMD -l 10 -i -p "Streams: ") || return 1
    chosen_stream=$(echo "$chosen_stream" | sed 's/(.*) * \([^ ]*\) : .*/\1/')
    [ -z "$chosen_stream" ] && return 1
    echo "$chosen_stream"
}

check_and_launch () {
    local game_name=$1 game_id=$2 twitch_data= stream_list= stream=
    log "Checking connected streams for $game_name ..."
    twitch_data=$(curl_get "streams" "game_id=$game_id" t)
    chosen_stream=$(choose_stream "$twitch_data") || aborted
    echo "$chosen_stream" > "$LAST_STREAM_FILE"
    launch_stream "$chosen_stream"
    exit
}

choose_from_list() {
    # Unique ID should always be at first col in list
    list=$1 format=$2 prompt=$3 separator=$4 ensure=$5
    length=$(echo "$list" | wc -l)
    [  "$length" = 1 ] && [ -n "$ensure" ] && echo "$list" && return 0
    print_format=$(echo "$format" | sed 's/%/$/g')
    chosen=$(echo "$list" | awk -F "$separator" "{print $print_format}" | $MENU_CMD -l 15 -i -p "$prompt") || return 1
    if [ -z "$ensure" ]; then
        echo "$chosen"
    else
        echo "$list" | grep -E "$separator$chosen$separator"
    fi
}

twitch_game () {
    game_list=$(cat "$GAMES_FILE")
    query=$(choose_from_list "$game_list" "%2" "Search For Category: " ";") || aborted
    game=$(cat "$GAMES_FILE" | grep ";$query;")
    if [ -z "$game" ]; then
        category_list=$(search_categories "$query")
        [  -z "$category_list" ] && aborted "Nothing found for $query"
        game=$(choose_from_list "$category_list" "%2" "Choose Game" ";" t) || aborted "Need existing category name"
        if ! __is_in_file "$game" "$GAMES_FILE"; then
            game_name=${game#*;}
            game_name=${game_name%%;*}
            if __confirm "Add $game_name to fav?"; then
                echo "$game" >> "$GAMES_FILE"
            fi
        fi
    fi
    game_id=${game%%;*}
    game_name=${game#*;}
    game_name=${game_name%%;*}
    check_and_launch "$game_name" "$game_id"
}

twitch_live() {
    streamer=$1 LOGROOT="$LOGROOT:live"
    if [ -n "$streamer" ]; then
        params="user_login=$streamer"
    else
        params=$(awk '{printf "user_login="$1"&"}' "$CHANNELS_FILE")
    fi

    echo "Checking connected streams ..."

    twitch_data=$(curl_get "streams" "$params")
    chosen_stream=$(choose_stream "$twitch_data") || aborted
    launch_stream "$chosen_stream"
    exit
}

twitchvod_search() {
    searchingshit=$(sort "$CHANNELS_FILE" | $MENU_CMD -i -l 10 -p "TwitchVOD Channel: ") || aborted
    printf "Searching for video on %s\n" "$searchingshit"
    curl_choose_and_watch
}

__is_in_file() {
    local text=$1 file=$2
    grep -q "$text" "$file"
}

__confirm() {
    local prompt=$1 default_ok=$2 check
    [ -n "$default_ok" ] && opts="(Y/n)" || opts="(y/N)"
    check=$(echo | $MENU_CMD -i -p "$prompt $opts") || return 1
    [ "$check" = "Y" ] && return 0
    [ "$check" = "y" ] && return 0
    [ -n "$default_ok" ] && [ -z "$check" ] && return 0
    return 1
}

curl_choose_and_watch() {
    local user_id last_time content start_opt video_id
    #curl the api twitch vod search for a channel
    user_id=$(get_user_id "$searchingshit")
    [ -z "$user_id" ] && aborted "user id not found"
    twitchvod=$(curl_get "videos" "user_id=$user_id&first=$MAX_VID")
    total_vod=$(echo $twitchvod | sed 's/\\n//g' | jq -r '.data | length')
    [ "$total_vod" = "null" ] || [ "$total_vod" = 0 ] && twitchvod_search

    #create a table with all of the videos and get the url of the chosen one
    : $(( borne_max=total_vod - MAX_VID ))

    video=$(echo $twitchvod | jq -r '.data[] | .title, .created_at' | awk -v bm=$borne_max -v offs="$offset" 'BEGIN{ if (offs > 0 ) { printf "Prev\n" } }!               (NR%2){printf ("%3d: %-100s %.10s\n", FNR/2+offs, p, $0)}{p=$0}END{ if (offs < bm) { printf "Next" } }' | $MENU_CMD -i -l 30 -p "Which video: " | sed 's/:.*//')

    if [ -z "$video" ];then
        twitchvod_search
    elif [ "$video" = "Next" ];then
        : $(( OFFSET=OFFSET+100 ))
        curl_choose_and_watch
    elif [ "$video" = "Prev" ];then
        : $(( OFFSET=OFFSET-100 ))
        curl_choose_and_watch
    else
        : $(( num=video-1-offset ))
        videourl=$(echo $twitchvod | jq -r '.data['$num'].url')
        video_id=${videourl##*/}
        # ask for the resolution and launch the video with mpv
        if start_opt=$(grep "^$video_id" "$TIME_FILE");then
            start_opt=${start_opt#* }
            __confirm "Start at $start_opt ?" 1 && {
                start_opt="--start=$start_opt"
            } || start_opt=
        fi

        res=$(printf "720\n1080\n360" | $MENU_CMD -i -p "Which resolution? (if avalaible): ") || twitchvod_search
        log "Command: mpv $start_opt --ytdl-format=\"[height<=?$res]\" $videourl"
        mpv "$start_opt" --ytdl-format="[height<=?$res]" "$videourl" > $TEMP_TIME || twitchvod_search

        log "TEMP_TIME_FILE_CONTENT: $(cat $TEMP_TIME)"
        last_time=$(grep "AV:" $TEMP_TIME | tail -n1)
        rm -f "$TEMP_TIME"
        last_time=${last_time#* }
        last_time=${last_time%% *}
        content=$(cat "$TIME_FILE")
        _is_time_hhmmss "$last_time" && _save_time_on_file "$video_id" "$last_time" "$TIME_FILE"
        exit
    fi
}

_save_time_on_file() {
    local video_id=$1 time=$2 file=$3 content
    content=$(grep -v "^$video_id" "$file")
    log "Saving '$video_id' '$time' on '$file'"
    printf "%s\n%s %s" "$content" "$video_id" "$time" > $file
}

_is_time_hhmmss() {
    echo "$1" | grep -q "[0-9][0-9]:[0-9][0-9]:[0-9][0-9]"
}

delete_game() {
    game_id=$(choose_from_list "$(sort "$GAMES_FILE")" "%2" "Delete game: " ";" t | sed 's/;.*//')
    sed -i "/^$game_id/d" "$GAMES_FILE"
    notif "Game deleted" t
}

delete_streamer() {
    streamer_to_delete=$(sort "$CHANNELS_FILE" | $MENU_CMD -i -l 10 -p "Delete streamer: ")
    grep -v "$streamer_to_delete" "$CHANNELS_FILE" > /tmp/chanshit && mv /tmp/chanshit "$CHANNELS_FILE"
}

__get_file_content() {
    file=$1 content=
    [ ! -f "$file" ] && return 1
    content=$(cat "$file")
    [ -n "$content" ] && echo "$content"
}

__file_exist_and_not_empty() {
    file=$1
    [ -f "$file" ] && [ -n "$(cat $file)" ]
}

twitchmenu() {
    choice=$({
                live_streams=$(cat "$CACHE_CHANNEL_LIVE" | tr "\n" " ")
                [ -n "$live_streams" ] && echo "Live Now: $live_streams"
                echo "Search Games"
                echo "Channel VODs"
                echo
                __file_exist_and_not_empty "$LAST_STREAM_FILE"
                last_streamer=$(__get_file_content "$LAST_STREAM_FILE") && echo "Add Last Streamer: $last_streamer"
                __file_exist_and_not_empty "$CHANNELS_FILE" && echo "Delete streamer"
                __file_exist_and_not_empty "$GAMES_FILE" && echo "Delete streamer"
            } | $MENU_CMD -i -l 10 -p "Twitch Menu :") || aborted

    case "$choice" in
        "Live Now:"*) twitch_live ;;
        "Search Games") twitch_game ;;
        "Channel VODs") twitchvod_search ;;
        "Add Last Streamer:"*) echo "$last_streamer" >> "$CHANNELS_FILE" ;;
        "Delete streamer") delete_streamer ;;
        "Delete game") delete_game ;;
        *) aborted "Option not found" ;;
    esac
}

check_internet

case $1 in
    --live) twitch_live "$2" ;;
    --game) twitch_game ;;
    --vod) twitchvod_search ;;
    --refresh-token) refresh_access_token ;;
    --help) echo "usage: twitchscript --live (stream name), --vod, --game or --refresh-token" ;;
    *) twitchmenu ;;
esac
