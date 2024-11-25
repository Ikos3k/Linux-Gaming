#!/bin/bash

TARGET_RESOLUTION="1280x960"
TARGET_REFRESH_RATE=165
TARGET_SCALE_MODE="Default" # Options: Full, Aspect, Center, Default
TARGET_FILTER="Default"     # Options: nearest, bilinear, default
NOTIFICATIONS=0

GAME_PROCESS_NAME="cs2"
APP_ID=730

WIDTH=$(echo "$TARGET_RESOLUTION" | cut -d'x' -f1)
HEIGHT=$(echo "$TARGET_RESOLUTION" | cut -d'x' -f2)

LAUNCH_OPTIONS="-novid -nojoy -high -console -noaafonts -nosync -noipx -freq $TARGET_REFRESH_RATE -refresh $TARGET_REFRESH_RATE -w $WIDTH -h $HEIGHT -fullscreen +fps_max $TARGET_REFRESH_RATE -forcenovsync"

SESSION_TYPE="Unknown"
if [ "$XDG_SESSION_TYPE" == "wayland" ]; then
    SESSION_TYPE="Wayland"
    if pgrep -x "sway" > /dev/null; then
        echo "Sway (Wayland) is in use."
        SESSION_TYPE="Wayland_Sway"
    else
        echo "Wayland is in use, but not Sway. Not supported environment."
        exit 1
    fi
elif [ -n "$DISPLAY" ]; then
    SESSION_TYPE="X11"
    echo "X11 is in use."
    if command -v notify-send >/dev/null 2>&1; then
        NOTIFICATIONS=1
    fi
else
    echo "Not supported environment."
    exit 1
fi

echo "Session type: $SESSION_TYPE"

if [ "$NOTIFICATIONS" -eq 1 ]; then
    notify-send "Game Notification" "CS2 is starting!" --icon=dialog-information
fi

steam -silent -vgui -applaunch $APP_ID $LAUNCH_OPTIONS &

while ! GAME_PID=$(pgrep -x "$GAME_PROCESS_NAME"); do
    sleep 1
done

echo "CS2 process detected. Waiting for it to end..."

if [ "$SESSION_TYPE" == "Wayland_Sway" ]; then
    DISP_OUT=$(swaymsg -t get_outputs | jq -r '.[] | select(.active == true) | .name')
    CURRENT_RESOLUTION=$(swaymsg -t get_outputs | jq -r --arg DISP "$DISP_OUT" '.[] | select(.name == $DISP) | "\(.current_mode.width)x\(.current_mode.height)"')
    echo "Adding custom mode $TARGET_RESOLUTION@$TARGET_REFRESH_RATE on $DISP_OUT..."
    swaymsg -- output $DISP_OUT mode --custom $TARGET_RESOLUTION@$TARGET_REFRESH_RATE"Hz"
elif [ "$SESSION_TYPE" == "X11" ]; then
    DISP_OUT=$(xrandr | grep " connected" | awk '{print $1}')
    CURRENT_RESOLUTION=$(xrandr | grep -A1 "^$DISP_OUT connected" | tail -n1 | awk '{ print $1 }')
    TARGET_MODE_NAME="${TARGET_RESOLUTION}_${TARGET_REFRESH_RATE}.00"
    TARGET_MODELINE=$(cvt $(echo $TARGET_RESOLUTION | tr 'x' ' ') $TARGET_REFRESH_RATE.00 | grep "Modeline" | cut -d' ' -f3-)
    
    if xrandr --verbose | grep -q "$TARGET_MODE_NAME"; then
        echo "Mode $TARGET_MODE_NAME already exists."
    else
        echo "Adding custom mode $TARGET_RESOLUTION@$TARGET_REFRESH_RATE on $DISP_OUT..."
        xrandr --newmode "$TARGET_MODE_NAME" $TARGET_MODELINE
        xrandr --addmode $DISP_OUT "$TARGET_MODE_NAME"
    fi
    
    if [ "$TARGET_SCALE_MODE" != "Default" ]; then
      echo "Setting scaling mode to $TARGET_SCALE_MODE on $DISP_OUT..."
      xrandr --output $DISP_OUT --set "scaling mode" "$TARGET_SCALE_MODE"
    else
      echo "Scaling mode is set to Default. No changes made."
    fi
    
    if [ "$TARGET_FILTER" != "Default" ]; then
      echo "Setting scaling filter to $TARGET_FILTER on $DISP_OUT..."
      xrandr --output $DISP_OUT --filter "$TARGET_FILTER"
    else
      echo "Scaling filter is set to Default. No changes made."
    fi
    
    echo "Setting mode $TARGET_MODE_NAME on $DISP_OUT..."
    xrandr --output $DISP_OUT --mode "$TARGET_MODE_NAME"
fi

while kill -0 "$GAME_PID" 2> /dev/null; do
    sleep 10
done

echo "CS2 process has ended."
echo "Restoring original res $CURRENT_RESOLUTION on $DISP_OUT..."
if [ "$SESSION_TYPE" == "Wayland_Sway" ]; then
    swaymsg -- output $DISP_OUT mode $CURRENT_RESOLUTION
elif [ "$SESSION_TYPE" == "X11" ]; then
    xrandr --output $DISP_OUT --mode $CURRENT_RESOLUTION --rate 60
fi

if [ "$NOTIFICATIONS" -eq 1 ]; then
    sleep 5
    notify-send "Game Notification" "CS2 has closed!" --icon=dialog-information
fi
