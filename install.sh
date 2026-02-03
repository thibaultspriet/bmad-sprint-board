#!/usr/bin/env bash
# Sprint Board Installer
# Interactive installation for global or project-local setup

set -euo pipefail

# GitHub raw URL base
GITHUB_RAW_BASE="https://raw.githubusercontent.com/thibaultspriet/bmad-sprint-board/master"

# Cleanup on failure
CLEANUP_FILES=()
cleanup() {
    if [[ ${#CLEANUP_FILES[@]} -gt 0 ]]; then
        for file in "${CLEANUP_FILES[@]}"; do
            [[ -f "$file" ]] && rm -f "$file"
        done
    fi
}
trap cleanup EXIT

# Colors (respect NO_COLOR)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    RESET=''
fi

# Banner
echo ""
echo -e "${BOLD}${BLUE}╔═══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${BLUE}║       Sprint Board Installer              ║${RESET}"
echo -e "${BOLD}${BLUE}║   Visual Kanban for BMAD Sprint Status    ║${RESET}"
echo -e "${BOLD}${BLUE}╚═══════════════════════════════════════════╝${RESET}"
echo ""

# Check for BMAD
if [[ -f "_bmad/_memory/config.yaml" ]]; then
    echo -e "${GREEN}✓ BMAD detected in current project${RESET}"
else
    echo -e "${YELLOW}⚠ BMAD not detected in current directory${RESET}"
    echo -e "${YELLOW}  Sprint Board requires BMAD to be installed in your project.${RESET}"
    echo -e "${YELLOW}  The tool will look for _bmad/_memory/config.yaml at runtime.${RESET}"
    echo ""
fi

# Ask for installation mode
echo -e "${BOLD}Select installation mode:${RESET}"
echo ""
echo -e "  ${BLUE}[G]${RESET} Global  - Command available in Claude Code from any directory"
echo -e "              Installs to: ~/.claude/scripts/ and ~/.claude/commands/"
echo ""
echo -e "  ${BLUE}[P]${RESET} Project - Command only available in this project"
echo -e "              Installs to: ./.claude/scripts/ and ./.claude/commands/"
echo ""
echo -n "Your choice [G/P]: "
read -r mode < /dev/tty

# Normalize input
mode=$(echo "$mode" | tr '[:lower:]' '[:upper:]')

# Validate input
if [[ "$mode" != "G" && "$mode" != "P" ]]; then
    echo -e "${RED}Error: Invalid choice. Please run the installer again and choose G or P.${RESET}"
    exit 1
fi

# Set paths based on mode
if [[ "$mode" == "G" ]]; then
    SCRIPTS_DIR="${HOME}/.claude/scripts"
    COMMANDS_DIR="${HOME}/.claude/commands"
    SCRIPT_PATH_IN_MD="\${HOME}/.claude/scripts/sprint-board.sh"
    MODE_NAME="Global"
else
    SCRIPTS_DIR="./.claude/scripts"
    COMMANDS_DIR="./.claude/commands"
    SCRIPT_PATH_IN_MD="{project-root}/.claude/scripts/sprint-board.sh"
    MODE_NAME="Project"
fi

SCRIPT_FILE="${SCRIPTS_DIR}/sprint-board.sh"
COMMAND_FILE="${COMMANDS_DIR}/sprint-board.md"

# Check for existing files
EXISTING_FILES=()
[[ -f "$SCRIPT_FILE" ]] && EXISTING_FILES+=("$SCRIPT_FILE")
[[ -f "$COMMAND_FILE" ]] && EXISTING_FILES+=("$COMMAND_FILE")

if [[ ${#EXISTING_FILES[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Existing files detected:${RESET}"
    for f in "${EXISTING_FILES[@]}"; do
        echo "  - $f"
    done
    echo ""
    echo -e "${BOLD}What would you like to do?${RESET}"
    echo -e "  ${BLUE}[O]${RESET} Overwrite - Replace existing files"
    echo -e "  ${BLUE}[S]${RESET} Skip      - Keep existing files (exit)"
    echo -e "  ${BLUE}[A]${RESET} Abort     - Cancel installation"
    echo ""
    echo -n "Your choice [O/S/A]: "
    read -r action < /dev/tty

    action=$(echo "$action" | tr '[:lower:]' '[:upper:]')

    case "$action" in
        O)
            echo -e "${BLUE}Overwriting existing files...${RESET}"
            ;;
        S)
            echo -e "${GREEN}Keeping existing files. Installation skipped.${RESET}"
            exit 0
            ;;
        A)
            echo -e "${YELLOW}Installation aborted.${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Invalid choice. Installation aborted.${RESET}"
            exit 1
            ;;
    esac
fi

echo ""
echo -e "${BLUE}Installing in ${MODE_NAME} mode...${RESET}"

# Create directories
echo -n "Creating directories... "
if ! mkdir -p "$SCRIPTS_DIR" "$COMMANDS_DIR" 2>/dev/null; then
    echo -e "${RED}FAILED${RESET}"
    echo -e "${RED}Error: Could not create directories. Check permissions.${RESET}"
    echo -e "${YELLOW}Try running with appropriate permissions or choose a different mode.${RESET}"
    exit 1
fi
echo -e "${GREEN}OK${RESET}"

# Download sprint-board.sh
echo -n "Downloading sprint-board.sh... "
CLEANUP_FILES+=("$SCRIPT_FILE")
if ! curl -fsSL "${GITHUB_RAW_BASE}/sprint-board.sh" -o "$SCRIPT_FILE" 2>/dev/null; then
    echo -e "${RED}FAILED${RESET}"
    echo ""
    echo -e "${RED}Error: Failed to download sprint-board.sh${RESET}"
    echo -e "${YELLOW}Manual installation:${RESET}"
    echo -e "  1. Download from: ${GITHUB_RAW_BASE}/sprint-board.sh"
    echo -e "  2. Save to: $SCRIPT_FILE"
    echo -e "  3. Run: chmod +x $SCRIPT_FILE"
    exit 1
fi

# Verify download
if [[ ! -s "$SCRIPT_FILE" ]]; then
    echo -e "${RED}FAILED${RESET}"
    echo -e "${RED}Error: Downloaded file is empty${RESET}"
    exit 1
fi
echo -e "${GREEN}OK${RESET}"

# Make executable
echo -n "Setting permissions... "
chmod +x "$SCRIPT_FILE"
echo -e "${GREEN}OK${RESET}"

# Generate sprint-board.md
echo -n "Creating Claude command... "
CLEANUP_FILES+=("$COMMAND_FILE")
cat > "$COMMAND_FILE" << EOF
---
description: 'Display sprint status as a visual Kanban board'
---

Execute the sprint-board script to display a Kanban board of the current sprint.

**Requirements:**
- BMAD installed in the project (\`_bmad/_memory/config.yaml\`)
- Sprint status file at \`{output_folder}/implementation-artifacts/sprint-status.yaml\`

**Environment Variables:**
- \`NO_COLOR=1\` : Disable ANSI colors
- \`SPRINT_BOARD_ASCII=1\` : Use ASCII characters instead of Unicode
- \`SPRINT_BOARD_COL_WIDTH=N\` : Set column width (default: 18)

Run the script:
\`\`\`bash
${SCRIPT_PATH_IN_MD}
\`\`\`
EOF
echo -e "${GREEN}OK${RESET}"

# Clear cleanup trap - installation successful
CLEANUP_FILES=()

# Success message
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║       Installation Complete!              ║${RESET}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${BOLD}Files installed:${RESET}"
echo "  - $SCRIPT_FILE"
echo "  - $COMMAND_FILE"
echo ""
echo -e "${BOLD}Usage:${RESET}"
echo "  In Claude Code, type: /sprint-board"
echo ""
if [[ "$mode" == "G" ]]; then
    echo -e "${YELLOW}Note: The command is globally available, but requires BMAD to be${RESET}"
    echo -e "${YELLOW}      installed in the current project to display the board.${RESET}"
fi
echo ""
