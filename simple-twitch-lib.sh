APPNAME=simple-twitch

CONFIG_FILE="/etc/simple-twitch.conf"

. "$CONFIG_FILE"

[ -z "$TWITCH_CLIENTID" ] && echo "TWITCH_CLIENTID" && exit 1
[ -z "$TWITCH_SECRET" ] && echo "TWITCH_SECRET needed" && exit 1

[ -n "$XDG_CONFIG_HOME" ] && CONFIG_HOME="$XDG_CONFIG_HOME" || CONFIG_HOME="${HOME}/.config"
[ -n "$XDG_CACHE_HOME" ] && CACHE_HOME="$XDG_CACHE_HOME" || CACHE_HOME="${HOME}/.cache"

CONFIG_DIR="$XDG_CONFIG_HOME/$APPNAME"
CACHE_DIR="$XDG_CACHE_HOME/$APPNAME"

mkdir -p "$CONFIG_DIR"
mkdir -p "$CACHE_DIR"

ACCESS_TOKEN_CACHE_FILE="${CACHE_DIR}/access_token"
touch "$ACCESS_TOKEN_CACHE_FILE"
TWITCH_ACCESS_TOKEN=$(cat "$ACCESS_TOKEN_CACHE_FILE")

API="https://api.twitch.tv/helix"

check_internet() {
    if ! ping -q -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
        aborted "No internet connection"
    fi
}

handle_error() {
    local curl_out="$1" error status message
    log "Handle Errors for $curl_out" 3
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
         -D "$CACHE_DIR/curl_headers" \
         $opt "$data"
}

curl_get() {
    local endpoint="$1" data="$2" url_encode="$3" curl_output opt datas
    log "ENDPOINT: $endpoint"
    [ -n "$url_encode" ] && opt="--data-urlencode" || opt="-d"
    log "DATA: $data"
    log "opt: $opt"
    curl_output=$(curl_call "$opt" "$data" "$endpoint")
    log "CURL OUTPUT: $curl_output" 3
    log "CURL HEADER: $(cat $CACHE_DIR/curl_headers)" 3
    handle_error "$curl_output"
    if [ $? -eq 2 ]; then
        log "Token refresh done, retry call"
        curl_output=$(curl_call "$opt" "$data")
        log "CURL OUTPUT: $curl_output" 3
    fi
    echo "$curl_output"
}

get_token(){
    curl -sX POST https://id.twitch.tv/oauth2/token \
         --data "client_id=$TWITCH_CLIENTID" \
         --data "client_secret=$TWITCH_SECRET" \
         --data "grant_type=client_credentials"
}

echoerror() {
    echo "$*"
    noshit="$*. Choose an other game:"
    twitchgamefunction
}

log() {
    local msg=$1 level=$2
    [ -z "$level" ] && level=1
    if [ -n "$VERBOSE" ] && [ $VERBOSE -ge $level ]; then
        echo "$(date "+%F %T.%N"):$LOGROOT:$msg" 1>&2
    fi
}

notif() {
    msg=$1 transient=$2
    [ -n "$transient" ] && opt="-e"
    notify-send "$msg" -a "$APPNAME" -i gnome-twitch "$opt"
}

aborted() {
    [ -n "$1" ] && notif "Error: $1" 1
    exit 1
}

refresh_access_token(){
    local token
    token=$(get_token | jq -r '.access_token')
    echo "$token" > "$ACCESS_TOKEN_CACHE_FILE"
}
