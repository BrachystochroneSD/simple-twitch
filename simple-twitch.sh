#!/bin/sh

CONFIG_FILE="/etc/simple-twitch.conf"

. "$CONFIG_FILE"

[ -z "$TWITCH_CLIENTID" ] && echo "TWITCH_CLIENTID" && exit 1
[ -z "$TWITCH_SECRET" ] && echo "TWITCH_SECRET needed" && exit 1

[ -z "$MENU_CMD" ] && MENU_CMD="dmenu"
[ -z "$CHAT_CMD" ] && CHAT_CMD="firefox --new-window"
[ -z "$MAX_VID" ] && MAX_VID=100

. "/usr/share/simple-twitch/simple-twitch-lib.sh"

TIME_FILE="$CACHE_DIR/vod_histo"
TEMP_TIME=$(mktemp)

[ -z "$MAX_VID" ] &&

mkdir -p $CONFIG_DIR
mkdir -p $CACHE_DIR

touch "$LAST_STREAM_FILE"

get_user_id() {
    log "Get User ID"
    local user_id="$1" key1= key2= curl_data=
    echo "$input" | grep -q "^[0-9]+$" && { key1="id";key2="login"; } || { key1="login";key2="id"; }
    curl_data=$(curl_get "users" "$key1=$user_id" t)
    echo $curl_data | jq -r ".data[] | .$key2"
}

get_game_info () {
    log "Get Game info"
    local gx="$1" key1= key2= curl_data=
    echo "$input" | grep -q "^[0-9]+$" && { key1="id";key2="name"; } || { key1="name";key2="id"; }
    curl_data=$(curl_get "games" "$key1=$gx" t)
    echo $curl_data | jq -r ".data[] | .$key2"
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
    local game_name="$1" game_id=$(get_game_info "$1") twitch_data= stream_list= stream=
    log "Checking connected streams for $game_name ..."
    twitch_data=$(curl_get "streams" "game_id=$game_id" t)
    chosen_stream=$(choose_stream "$twitch_data") || aborted
    echo "$chosen_stream" > "$LAST_STREAM_FILE"
    launch_stream "$chosen_stream"
    exit
}

twitchgamefunction () {
    game=$(echo "$(cat $GAMES_FILE)\n\nOther\nAdd Game" | $MENU_CMD -l 15 -i -p "$noshit") || aborted

    case "$game" in
        "Add Game")
            local dprompt="Add game: "
            game=$($MENU_CMD -l 10 -i -p "$dprompt" < "$gamesdb") || aborted
            echo "$game" >> "$GAMES_FILE"

            local dprompt="Do you want to check streams for $game? "
            cert=$(printf "No\nYes" | $MENU_CMD -l 10 -i -p "$dprompt")
            [ "$cert" = "Yes" ] || aborted
            ;;
        "Other")
            game=$($MENU_CMD -l 10 -i -p "$noshit" < "$gamesdb") || aborted
            check_and_launch "$game" ;;
        *)
            check_and_launch "$game" ;;
    esac
}

twitchlivefunction () {
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
    local prompt=$1 check
    check=$(echo | $MENU_CMD -i -p "$prompt (Y/n)")
    [ "$check" = "Y" ] || [ "$check" = "y" ] || [ -z "$check" ]
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
    video=$(echo $twitchvod | jq -r '.data[] | .title, .created_at' | awk -v bm=$borne_max -v offs="$offset" 'BEGIN{ if (offs > 0 ) { printf "Prev\n" } }!(NR%2){printf ("%3d: %-100s %.10s\n", FNR/2+offs, p, $0)}{p=$0}END{ if (offs < bm) { printf "Next" } }' | $MENU_CMD -i -l 30 -p "Which video: " | sed 's/:.*//')

    if [ -z "$video" ];then
        twitchvod_search
    elif [ "$video" = "Next" ];then
        : $(( offset=offset+100 ))
        curl_choose_and_watch
    elif [ "$video" = "Prev" ];then
        : $(( offset=offset-100 ))
        curl_choose_and_watch
    else
        : $(( num=video-1-offset ))
        videourl=$(echo $twitchvod | jq -r '.data['$num'].url')
        video_id=${videourl##*/}
        echo "$videourl" | xclip -selection clipboard
        echo selection cliped
        # ask for the resolution and launch the video with mpv
        if start_opt=$(grep "^$video_id" "$TIME_FILE");then
            start_opt=${start_opt#* }
            __confirm "Start at $start_opt ?" && {
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
    echo "$content\n$video_id $time" > $file
}

_is_time_hhmmss() {
    echo "$1" | grep -q "[0-9][0-9]:[0-9][0-9]:[0-9][0-9]"
}

delete_streamer() {
    streamer_to_delete=$(sort "$CHANNELS_FILE" | $MENU_CMD -i -l 10 -p "Delete streamer: ")
    grep -v "$streamer_to_delete" "$CHANNELS_FILE" > /tmp/chanshit && mv /tmp/chanshit "$CHANNELS_FILE"
}

twitchmenu() {
    laststreamer=$(cat "$LAST_STREAM_FILE")
    choice=$(printf "LIVE\nGAMES\nVOD\n\nAdd last streamer: $laststreamer\nDelete streamer" | $MENU_CMD -i -l 10 -p "Twitch Menu :")

    case "$choice" in
        "LIVE")
        twitchlivefunction "$2" ;;
        "GAMES")
            args=$(echo "$*" | sed "s/$1 *//")
            noshit="Choose a game: "
            [ -n "$args" ] && check_and_launch "$args"
            twitchgamefunction ;;
        "VOD")
            offset=0
            twitchvod_search ;;
        "Add last streamer: $laststreamer") cat "$LAST_STREAM_FILE" >> "$CHANNELS_FILE" ;;
        "Delete streamer") delete_streamer ;;
        *) aborted ;;
    esac
}

check_internet

case $1 in
    --live) twitchlivefunction "$2" ;;
    --game)
        args=$(echo "$*" | sed "s/$1 *//")
        noshit="Choose a game: "
        [ -n "$args" ] && check_and_launch "$args"
        twitchgamefunction ;;
    --vod)
        offset=0
        twitchvod_search ;;
    --refresh-token) refresh_access_token ;;
    --help) echo "usage: twitchscript --live (stream name), --vod, --game (game) or --refresh-token" ;;
    *) twitchmenu ;;
esac
