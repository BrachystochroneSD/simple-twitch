#!/bin/sh

CONFIG_FILE="/etc/twitch.conf"

. "$CONFIG_FILE"

[ -z "$TWITCH_CLIENTID" ] && echo "TWITCH_CLIENTID" && exit 1
[ -z "$TWITCH_SECRET" ] && echo "TWITCH_SECRET needed" && exit 1

[ -z "$MENU_CMD" ] && MENU_CMD="dmenu"
[ -z "$CHAT_CMD" ] && CHAT_CMD="firefox --new-window"
[ -z "$MAX_VID" ] && MAX_VID=100

# Parameters

CONFIG_DIR="${HOME}/.config/twitch"
CACHE_DIR="${HOME}/.cache/twitch"

ACCESS_TOKEN_CACHE_FILE="${CACHE_DIR}/access_token"
touch "$ACCESS_TOKEN_CACHE_FILE"
TWITCH_ACCESS_TOKEN=$(cat "$ACCESS_TOKEN_CACHE_FILE")

CHANNELS_FILE="$CONFIG_DIR/listchanneltwitch"
LAST_STREAM_FILE="$CONFIG_DIR/lastchannelviewed"
GAMES_FILE="$CONFIG_DIR/listgamestwitch"

gamesdb="${HOME}/.config/gamedatabase/gamesdb"

API="https://api.twitch.tv/helix"

TIME_FILE="$CACHE_DIR/vod_histo"
TEMP_TIME=$(mktemp)


[ -z "$MAX_VID" ] &&

mkdir -p $CONFIG_DIR
mkdir -p $CACHE_DIR

touch "$LAST_STREAM_FILE"

echoerror() {
    echo "$*"
    noshit="$*. Choose an other game:"
    twitchgamefunction
}

log() {
    local msg=$1 level=$2
    [ -z "$level" ] && level=1
    if [ -n "$VERBOSE" ] && [ $VERBOSE -ge $level ]; then
        echo "$(date "+%F %T.%N"):$msg" 1>&2
    fi
}

aborted() {
    [ -n "$1" ] && notify-send "Error: $1"
    exit 1
}

handle_error() {
    local curl_out="$1" error status message
    log "Handle Errors for $curl_out"
    error=$(echo $curl_out | jq -r .error 2>/dev/null)
    if [ -z "$error" ] || [ "$error" = "null" ]; then
        log "No Error Found, continuing"
        return 0
    fi
    log "Error found: $error"
    status=$(echo $curl_out | jq -r .status)
    message=$(echo $curl_out | jq -r .message)
    if [ "$status" = 401 ] && [ "$message" = "Invalid OAuth token" ]; then
        refresh_access_token
        return 2
    fi
    aborted "Error $status: $message"
}

curl_call() {
    local opt=$1 data=$2 endpoint=$3
    curl -s \
         -H "Client-ID: $TWITCH_CLIENTID" \
         -H "Authorization: Bearer $TWITCH_ACCESS_TOKEN" \
         -H "Accept: application/json" \
         -G "$API/$endpoint" \
         $opt "$data"
}

curl_get() {
    local endpoint="$1" data="$2" url_encode="$3" curl_output opt datas
    log "ENDPOINT: $endpoint"
    [ -n "$url_encode" ] && opt="--data-urlencode" || opt="-d"
    log "DATA: $data"
    log "opt: $opt"
    curl_output=$(curl_call "$opt" "$data" "$endpoint")
    log "CURL OUTPUT: $curl_output" 2
    handle_error "$curl_output"
    if [ $? -eq 2 ]; then
        log "Token refresh done, retry call"
        curl_output=$(curl_call "$opt" "$data")
        log "CURL OUTPUT: $curl_output" 2
    fi
    echo "$curl_output"
}

get_token(){
    curl -sX POST https://id.twitch.tv/oauth2/token \
         --data "client_id=$TWITCH_CLIENTID" \
         --data "client_secret=$TWITCH_SECRET" \
         --data "grant_type=client_credentials"
}

refresh_access_token(){
    local token
    token=$(get_token | jq -r '.access_token')
    echo "$token" > "$ACCESS_TOKEN_CACHE_FILE"
}


fzfcmd(){
    local prompt
    local iflag
    while getopts "ip:l:" opt; do
        case $opt in
            p) prompt=$OPTARG ;;
            l) lflag=shit ;;
            i) iflag="-i";;
        esac
    done
    [ -z "$prompt" ] && prompt=">"
    fzf --prompt="$prompt" "$iflag"
}

check_internet() {
    if ! ping -q -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
        aborted "No internet connection"
    fi
}

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

check_and_launch () {
    local game_name="$1" game_id=$(get_game_info "$1") twitchdata= stream_list= stream=
    log "Checking connected streams for $game_name ..."
    twitchdata=$(curl_get "streams" "game_id=$game_id" t)
    stream_list=$(echo $twitchdata | sed 's/\\n//g' | jq -r '.data[] | .language, .user_name, .title, .viewer_count' | awk '(NR%4==1){lg=$0}(NR%4==2){name=$0}(NR%4==3){title=$0}(NR%4==0){printf "%s:%s \"%s\" %s\n",lg,name,title,$0}')
    [ -z "$stream_list" ] && echoerror "No streams"

    stream=$(echo "$stream_list" | $MENU_CMD -i -l 10 -p "Streams: ") || aborted

    stream=$(echo "$stream" | sed 's/..:\([^ ]*\).*/\1/')
    echo "$stream" > "$LAST_STREAM_FILE"
    exec $CHAT_CMD "https://www.twitch.tv/popout/$stream/chat?darkpopout" & mpv "https://www.twitch.tv/$(echo $stream | tr [A-Z] [a-z])"
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
    local streamer=$1
    if [ -n "$streamer" ]; then
        echo "Checking if $streamer is live ..."
        test=$(curl_get streams "user_login=$streamer" | jq '.data | length' t)
        [ ! "$test" = 0 ] && (exec $CHAT_CMD "https://www.twitch.tv/popout/$streamer/chat?darkpopout" & mpv "https://www.twitch.tv/$streamer") || echo "$streamer doesn't stream right now"
        exit
    else
        echo "Checking connected streams ..."
        userlogins=$(awk '{printf "user_login="$1"&"}' "$CHANNELS_FILE")
        twitchdata=$(curl_get "streams" "$userlogins")

        game_ids=$(echo "$twitchdata" | jq -r '.data[] | .game_id' | awk '{printf "id="$1"&"}')
        curl_data=$(curl_get "games" "$game_ids")
        game_dico=$(echo "$curl_data" | jq -r '.data[] | .id,.name' | awk 'NR%2{printf "%s ",$0;next;}1')

        streams_test=$(echo "$twitchdata" | jq -r '.data[] | .user_name, .game_id')
        [ -z "$streams_test" ] && aborted "Nothing found"
        stream=$(echo "$streams_test" | while read a;do echo "$a" | grep -q "^[0-9]*$" && echo "$game_dico" | grep "$a" | sed 's/^[0-9]* //' || echo "$a";done | awk 'NR%2{printf "%14s : ",$0;next;}1' | $MENU_CMD -l 10 -i -p "Streams: ") || aborted
        stream=$(echo "$stream" | sed 's/ *\([^ ]*\).*/\1/')
        echo "https://www.twitch.tv/$stream"
        exec $CHAT_CMD "https://www.twitch.tv/popout/$stream/chat?darkpopout" & mpv "https://www.twitch.tv/$stream"
        exit
    fi
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
