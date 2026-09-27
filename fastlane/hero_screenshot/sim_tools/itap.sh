#!/bin/zsh
# device px (1320x2868) -> mac screen
# 前提: Simulator は Window > Fit Screen（402x869）で、Shot-17ProMax のウィンドウを (300,43) に置く
osascript -e 'tell application "Simulator" to activate' -e 'tell application "System Events" to tell process "Simulator" to perform action "AXRaise" of (first window whose name starts with "Shot-17ProMax")' >/dev/null; sleep 0.3
X=$(python3 -c "print(round(323+$1/3.70))"); Y=$(python3 -c "print(round(118+$2/3.70))")
cliclick c:$X,$Y
