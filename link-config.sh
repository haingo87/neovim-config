#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

link() {
	local src="$1"
	local target="$2"

	if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
		echo "OK: $target already linked -> $src"
		return
	fi

	if [ -e "$target" ] || [ -L "$target" ]; then
		local backup="${target}.bak.$(date +%s)"
		echo "WARN: $target exists, backing up to $backup"
		mv "$target" "$backup"
	fi

	ln -sf "$src" "$target"
	echo "LINKED: $target -> $src"
}

link "$REPO_DIR/ghostty" "$HOME/.config/ghostty"
link "$REPO_DIR/nvim" "$HOME/.config/nvim"
