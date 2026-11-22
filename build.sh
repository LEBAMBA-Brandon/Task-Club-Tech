#!/bin/bash
set -e

git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

flutter config --enable-web
flutter precache --web
flutter build web --release