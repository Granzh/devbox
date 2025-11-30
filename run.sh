#!/bin/bash
# run.sh - компилирует и запускает решение
# Использование: ./run.sh 1920A

PROBLEM=$1

if [ -z "$PROBLEM" ]; then
    echo "Usage: $0 <problem>"
    echo "Example: $0 1920A"
    exit 1
fi

SOURCE="${PROBLEM}.cpp"
BINARY="${PROBLEM}"

if [ ! -f "$SOURCE" ]; then
    echo "❌ File $SOURCE not found!"
    exit 1
fi

echo "🔨 Compiling $SOURCE..."
g++ -std=c++17 -O2 -Wall -Wextra -DLOCAL -o "$BINARY" "$SOURCE"

if [ $? -eq 0 ]; then
    echo "✅ Compiled successfully!"
    echo "🚀 Running..."
    echo "---"
    ./"$BINARY"
else
    echo "❌ Compilation failed!"
    exit 1
fi
