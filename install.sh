#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 [-f] <qiskit-clone-path>" >&2
    exit 1
}

FORCE=0

while getopts ":f" opt; do
    case $opt in
        f) FORCE=1 ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -lt 1 ]]; then
    usage
fi

TARGET="$1"

if [[ ! -d "$TARGET" ]]; then
    echo "Error: '$TARGET' is not a directory." >&2
    exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"

for src in "$SCRIPT_DIR/playbook" "$SCRIPT_DIR/skills" "$SCRIPT_DIR/deploy/AGENTS.md"; do
    if [ ! -e "$src" ]; then
        echo "Error: source not found: $src" >&2
        exit 1
    fi
done

INSTALLED=()

# Helper: prompt before overwrite unless -f is set
# Returns 0 to proceed, 1 to skip
confirm_overwrite() {
    local dest="$1"
    if [[ -e "$dest" ]]; then
        if [[ $FORCE -eq 1 ]]; then
            return 0
        fi
        if [ ! -t 0 ]; then
            echo "Warning: '$dest' already exists. Skipping (not a tty — use -f to force)." >&2
            return 1
        fi
        echo "Warning: '$dest' already exists."
        printf "Overwrite? [y/N] "
        read -r answer
        case "$answer" in
            [Yy]*) return 0 ;;
            *)     return 1 ;;
        esac
    fi
    return 0
}

# 1. Copy playbook/ → <target>/docs/playbook/
PLAYBOOK_DEST="$TARGET/docs/playbook"
if confirm_overwrite "$PLAYBOOK_DEST"; then
    mkdir -p "$PLAYBOOK_DEST"
    cp -r "$SCRIPT_DIR/playbook/." "$PLAYBOOK_DEST/"
    INSTALLED+=("playbook/ → $PLAYBOOK_DEST/")
fi

# 2. Copy skills/ → <target>/.claude/skills/
SKILLS_DEST="$TARGET/.claude/skills"
if confirm_overwrite "$SKILLS_DEST"; then
    mkdir -p "$SKILLS_DEST"
    cp -r "$SCRIPT_DIR/skills/." "$SKILLS_DEST/"
    INSTALLED+=("skills/ → $SKILLS_DEST/")
fi

# 3. Copy deploy/AGENTS.md → <target>/AGENTS.md
AGENTS_DEST="$TARGET/AGENTS.md"
if confirm_overwrite "$AGENTS_DEST"; then
    cp "$SCRIPT_DIR/deploy/AGENTS.md" "$AGENTS_DEST"
    INSTALLED+=("deploy/AGENTS.md → $AGENTS_DEST")
fi

# Summary
echo ""
if [[ ${#INSTALLED[@]} -eq 0 ]]; then
    echo "Nothing installed."
else
    echo "Installed:"
    for item in "${INSTALLED[@]}"; do
        echo "  $item"
    done
fi
