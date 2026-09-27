#!/bin/zsh
S=${SCRATCH:-/tmp/hero_sim}; mkdir -p $S
xcrun simctl io ${SIM_UDID:?SIM_UDID を指定} screenshot $S/iraw_$1.png >/dev/null 2>&1
python3 -c "from PIL import Image; im=Image.open('$S/iraw_$1.png'); im.convert('RGB').resize((440,956)).save('$S/iv_$1.png')"
