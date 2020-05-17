local APP_NAME=Music

autoload is-at-least
if is-at-least 10.15 $(sw_vers -productVersion); then
    if [[ $0 = itunes ]]; then
        echo >&2 The itunes function name is deprecated. Use \`music\' instead.
        return 1
    fi
else
    APP_NAME=iTunes
fi

local opt=$1
local playlist=$2
shift
case "$opt" in
    launch|play|pause|stop|rewind|resume|quit)
        ;;
    mute)
        opt="set mute to true"
        ;;
    unmute)
        opt="set mute to false"
        ;;
    next|previous)
        opt="$opt track"
        ;;
    vol)
        local new_volume volume=$(osascript -e "tell application \"$APP_NAME\" to get sound volume")
        if [[ $# -eq 0 ]]; then
            echo "Current volume is ${volume}."
            return 0
        fi
        case $1 in
            up) new_volume=$((volume + 10 < 100 ? volume + 10 : 100)) ;;
            down) new_volume=$((volume - 10 > 0 ? volume - 10 : 0)) ;;
            <0-100>) new_volume=$1 ;;
            *) echo "'$1' is not valid. Expected <0-100>, up or down."
               return 1 ;;
        esac
        opt="set sound volume to ${new_volume}"
        ;;
    playlist)
        # Inspired by: https://gist.github.com/nakajijapan/ac8b45371064ae98ea7f
        if [[ ! -z "$playlist" ]]; then
            osascript -e "tell application \"$APP_NAME\"" -e "set new_playlist to \"$playlist\" as string" -e "play playlist new_playlist" -e "end tell" 2>/dev/null;
            if [[ $? -eq 0 ]]; then
                opt="play"
            else
                opt="stop"
            fi
        else
            opt="set allPlaylists to (get name of every playlist)"
        fi
        ;;
    playing|status)
        local state=`osascript -e "tell application \"$APP_NAME\" to player state as string"`
        if [[ "$state" = "playing" ]]; then
            currenttrack=`osascript -e "tell application \"$APP_NAME\" to name of current track as string"`
            currentartist=`osascript -e "tell application \"$APP_NAME\" to artist of current track as string"`
            echo -E "Listening to $fg[yellow]$currenttrack$reset_color by $fg[yellow]$currentartist$reset_color";
        else
            echo "$APP_NAME is" $state;
        fi
        return 0
        ;;
    shuf|shuff|shuffle)
        # The shuffle property of current playlist can't be changed in iTunes 12,
        # so this workaround uses AppleScript to simulate user input instead.
        # Defaults to toggling when no options are given.
        # The toggle option depends on the shuffle button being visible in the Now playing area.
        # On and off use the menu bar items.
        local state=$1

        if [[ -n "$state" && ! "$state" =~ "^(on|off|toggle)$" ]]
        then
            print "Usage: $0 shuffle [on|off|toggle]. Invalid option."
            return 1
        fi

        case "$state" in
            on|off)
                # Inspired by: https://stackoverflow.com/a/14675583
                osascript 1>/dev/null 2>&1 <<-EOF
                tell application "System Events" to perform action "AXPress" of (menu item "${state}" of menu "Shuffle" of menu item "Shuffle" of menu "Controls" of menu bar item "Controls" of menu bar 1 of application process "iTunes" )
EOF
                return 0
                ;;
            toggle|*)
                osascript 1>/dev/null 2>&1 <<-EOF
                tell application "System Events" to perform action "AXPress" of (button 2 of process "iTunes"'s window "iTunes"'s scroll area 1)
EOF
                return 0
                ;;
        esac
        ;;
    ""|-h|--help)
        echo "Usage: $0 <option>"
        echo "option:"
        echo "\tlaunch|play|pause|stop|rewind|resume|quit"
        echo "\tmute|unmute\tcontrol volume set"
        echo "\tnext|previous\tplay next or previous track"
        echo "\tshuf|shuffle [on|off|toggle]\tSet shuffled playback. Default: toggle. Note: toggle doesn't support the MiniPlayer."
        echo "\tvol [0-100|up|down]\tGet or set the volume. 0 to 100 sets the volume. 'up' / 'down' increases / decreases by 10 points. No argument displays current volume."
        echo "\tplaying|status\tShow what song is currently playing in Music."
        echo "\tplaylist [playlist name]\t Play specific playlist"
        echo "\thelp\tshow this message and exit"
        return 0
        ;;
    *)
        print "Unknown option: $opt"
        return 1
        ;;
esac
osascript -e "tell application \"$APP_NAME\" to $opt"
