#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Checking system dependencies..."
if ! pacman -Q xdotool &>/dev/null; then
	echo "Installing xdotool..."
	sudo pacman -S --noconfirm xdotool
fi

mkdir -p "$HOME/.local/bin"
ln -sf "$SCRIPT_DIR/nvim-open" "$HOME/.local/bin/nvim-open"
echo "LINKED: $HOME/.local/bin/nvim-open -> $SCRIPT_DIR/nvim-open"
ln -sf "$SCRIPT_DIR/nvim-daemon" "$HOME/.local/bin/nvim-daemon"
echo "LINKED: $HOME/.local/bin/nvim-daemon -> $SCRIPT_DIR/nvim-daemon"

mkdir -p "$HOME/.local/share/applications"
cp "$SCRIPT_DIR/nvim-open.desktop" "$HOME/.local/share/applications/"
update-desktop-database "$HOME/.local/share/applications/"
echo "REGISTERED: nvim-open.desktop in applications database"
