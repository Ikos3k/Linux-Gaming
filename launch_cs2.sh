#!/bin/bash

TARGET_RESOLUTION="1280x960"
TARGET_REFRESH_RATE=165

GAME_PROCESS_NAME="cs2"
APP_ID=730

WIDTH=$(echo "$TARGET_RESOLUTION" | cut -d'x' -f1)
HEIGHT=$(echo "$TARGET_RESOLUTION" | cut -d'x' -f2)

LAUNCH_OPTIONS="-novid -nojoy -high -console -w $WIDTH -h $HEIGHT -fullscreen +r_dynamic 0 +fps_max $TARGET_REFRESH_RATE"

if [ -z "$DISPLAY" ]; then
    echo "Not running in X11 environment. Exiting."
    exit 1
fi

notify-send "Game Notification" "CS2 is starting!" --icon=dialog-information
steam -silent -vgui -applaunch $APP_ID $LAUNCH_OPTIONS &
sleep 5

while ! GAME_PID=$(pgrep -x "$GAME_PROCESS_NAME"); do
    sleep 1
done

echo "CS2 process detected. Waiting for it to end..."
DISP_OUT=$(xrandr | grep " connected" | awk '{print $1}')
CURRENT_RESOLUTION=$(xrandr | grep -A1 "^$DISP_OUT connected" | tail -n1 | awk '{ print $1 }')
TARGET_MODE_NAME="${TARGET_RESOLUTION}_${TARGET_REFRESH_RATE}.00"
TARGET_MODELINE=$(cvt $(echo $TARGET_RESOLUTION | tr 'x' ' ') $TARGET_REFRESH_RATE.00 | grep "Modeline" | cut -d' ' -f3-)

if xrandr --verbose | grep -q "$TARGET_MODE_NAME"; then
    echo "Mode $TARGET_MODE_NAME already exists."
else
    echo "Adding mode $TARGET_MODE_NAME..."
    xrandr --newmode "$TARGET_MODE_NAME" $TARGET_MODELINE
    xrandr --addmode $DISP_OUT "$TARGET_MODE_NAME"
fi

echo "Setting mode $TARGET_MODE_NAME on $DISP_OUT..."
xrandr --output $DISP_OUT --mode "$TARGET_MODE_NAME"

while kill -0 "$GAME_PID" 2> /dev/null; do
    sleep 10
done

echo "CS2 process has ended."
echo "Restoring original res $CURRENT_RESOLUTION on $DISP_OUT..."
xrandr --output $DISP_OUT --mode $CURRENT_RESOLUTION --rate 60 --primary

sleep 5
notify-send "Game Notification" "CS2 has closed!" --icon=dialog-information
