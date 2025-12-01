#!/bin/bash

echo "Installing Flutter SDK..."

git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

flutter doctor -v
