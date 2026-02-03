#!/usr/bin/env bash
# Sprint Board Kanban Display
# Displays sprint-status.yaml as a visual Kanban board
# Compatible with bash 3.2+ (macOS default)

set -euo pipefail

# Color support detection (F3: respect NO_COLOR and TTY)
USE_COLOR=true
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    USE_COLOR=false
fi

# ANSI Colors (only if color is enabled)
if [[ "$USE_COLOR" == "true" ]]; then
    RESET='\033[0m'
    BOLD='\033[1m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    DIM='\033[2m'
else
    RESET=''
    BOLD=''
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
    DIM=''
fi

# Column width for Kanban display
COL_WIDTH=18

# Box-drawing characters (F10: support ASCII fallback)
USE_UNICODE=true
if [[ "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" != *UTF-8* && "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" != *utf8* ]]; then
    USE_UNICODE=false
fi
# Allow override via environment variable
if [[ "${SPRINT_BOARD_ASCII:-}" == "1" ]]; then
    USE_UNICODE=false
fi

if [[ "$USE_UNICODE" == "true" ]]; then
    BOX_TL="╔"; BOX_TR="╗"; BOX_BL="╚"; BOX_BR="╝"
    BOX_H="═"; BOX_V="║"; BOX_HV="│"
    BOX_TM="╦"; BOX_BM="╩"; BOX_LM="╠"; BOX_RM="╣"
    BOX_CROSS="╬"; BOX_TCROSS="┼"; BOX_HL="─"
else
    BOX_TL="+"; BOX_TR="+"; BOX_BL="+"; BOX_BR="+"
    BOX_H="="; BOX_V="|"; BOX_HV="|"
    BOX_TM="+"; BOX_BM="+"; BOX_LM="+"; BOX_RM="+"
    BOX_CROSS="+"; BOX_TCROSS="+"; BOX_HL="-"
fi

# Storage - using newline-separated strings for bash 3.2 compatibility
BACKLOG=""
READY=""
IN_PROGRESS=""
REVIEW=""
DONE_ITEMS=""
EPICS=""
EPIC_STATUSES=""

PROJECT_NAME=""

# Find config.yaml by traversing up the directory tree
find_config() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/_bmad/_memory/config.yaml" ]]; then
            echo "$dir/_bmad/_memory/config.yaml"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# Extract output_folder from config.yaml
get_output_folder() {
    local config_path="$1"
    local project_root
    project_root=$(dirname "$(dirname "$(dirname "$config_path")")")

    local output_folder
    output_folder=$(grep -E "^output_folder:" "$config_path" | sed 's/output_folder:[[:space:]]*//' | tr -d '"' | tr -d "'")

    # Replace {project-root} placeholder
    output_folder="${output_folder//\{project-root\}/$project_root}"

    echo "$output_folder"
}

# Find sprint-status.yaml in the output folder
find_sprint_status() {
    local output_folder="$1"
    local sprint_status_path="$output_folder/implementation-artifacts/sprint-status.yaml"

    if [[ -f "$sprint_status_path" ]]; then
        echo "$sprint_status_path"
        return 0
    fi
    return 1
}

# Add item to newline-separated list (F1: avoid eval with user data)
# Uses indirect variable reference safely
add_to_list() {
    local list_name="$1"
    local item="$2"
    # Sanitize item - remove any shell metacharacters for safety
    item="${item//\`/}"
    item="${item//\$/}"
    item="${item//\(/}"
    item="${item//\)/}"

    case "$list_name" in
        BACKLOG)
            if [[ -z "$BACKLOG" ]]; then BACKLOG="$item"; else BACKLOG="$BACKLOG"$'\n'"$item"; fi ;;
        READY)
            if [[ -z "$READY" ]]; then READY="$item"; else READY="$READY"$'\n'"$item"; fi ;;
        IN_PROGRESS)
            if [[ -z "$IN_PROGRESS" ]]; then IN_PROGRESS="$item"; else IN_PROGRESS="$IN_PROGRESS"$'\n'"$item"; fi ;;
        REVIEW)
            if [[ -z "$REVIEW" ]]; then REVIEW="$item"; else REVIEW="$REVIEW"$'\n'"$item"; fi ;;
        DONE_ITEMS)
            if [[ -z "$DONE_ITEMS" ]]; then DONE_ITEMS="$item"; else DONE_ITEMS="$DONE_ITEMS"$'\n'"$item"; fi ;;
        EPICS)
            if [[ -z "$EPICS" ]]; then EPICS="$item"; else EPICS="$EPICS"$'\n'"$item"; fi ;;
        EPIC_STATUSES)
            if [[ -z "$EPIC_STATUSES" ]]; then EPIC_STATUSES="$item"; else EPIC_STATUSES="$EPIC_STATUSES"$'\n'"$item"; fi ;;
    esac
}

# Count items in newline-separated list
count_list() {
    local list="$1"
    if [[ -z "$list" ]]; then
        echo 0
    else
        echo "$list" | wc -l | tr -d ' '
    fi
}

# Get item at index from newline-separated list (0-indexed)
get_item() {
    local list="$1"
    local index="$2"
    if [[ -z "$list" ]]; then
        echo ""
    else
        echo "$list" | sed -n "$((index + 1))p"
    fi
}

# Parse sprint-status.yaml and populate lists
parse_sprint_status() {
    local sprint_status_path="$1"
    local in_dev_status=false

    # Extract project name
    PROJECT_NAME=$(grep -E "^project:" "$sprint_status_path" | sed 's/project:[[:space:]]*//' | head -1)

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Check if we're entering development_status section
        if [[ "$line" =~ ^development_status: ]]; then
            in_dev_status=true
            continue
        fi

        # If we're in development_status, parse entries
        if [[ "$in_dev_status" == "true" ]]; then
            # Check for next top-level section (no leading whitespace)
            if [[ "$line" =~ ^[a-z] && ! "$line" =~ ^[[:space:]] ]]; then
                break
            fi

            # Remove leading whitespace and parse key: value
            local trimmed
            trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')

            # Skip comment lines
            [[ "$trimmed" =~ ^# ]] && continue

            # F4: Handle values that may contain colons by only splitting on first colon
            local key value
            key="${trimmed%%:*}"
            value="${trimmed#*:}"
            value="${value#"${value%%[![:space:]]*}"}"  # trim leading whitespace

            # Skip retrospective entries
            [[ "$key" =~ retrospective$ ]] && continue

            # Classify entry
            if [[ "$key" =~ ^epic-[0-9]+$ ]]; then
                # This is an epic
                add_to_list "EPICS" "$key"
                add_to_list "EPIC_STATUSES" "$key:$value"
            elif [[ "$key" =~ ^[0-9]+-[0-9]+- ]]; then
                # This is a story
                local story_name="$key"

                # Add to appropriate status list (F5: warn on unknown statuses)
                case "$value" in
                    backlog)
                        add_to_list "BACKLOG" "$story_name"
                        ;;
                    ready-for-dev)
                        add_to_list "READY" "$story_name"
                        ;;
                    in-progress)
                        add_to_list "IN_PROGRESS" "$story_name"
                        ;;
                    review)
                        add_to_list "REVIEW" "$story_name"
                        ;;
                    done)
                        add_to_list "DONE_ITEMS" "$story_name"
                        ;;
                    *)
                        echo -e "${YELLOW}Warning: Unknown status '$value' for story '$story_name'${RESET}" >&2
                        ;;
                esac
            fi
        fi
    done < "$sprint_status_path"
}

# Truncate string to fit column width
truncate_str() {
    local str="$1"
    local max_len=$((COL_WIDTH - 2))
    if [[ ${#str} -gt $max_len ]]; then
        echo "${str:0:$((max_len - 2))}.."
    else
        echo "$str"
    fi
}

# Pad string to column width
pad_str() {
    local str="$1"
    local len=${#str}
    local padding=$((COL_WIDTH - len))
    printf "%s%*s" "$str" "$padding" ""
}

# Get epic status from EPIC_STATUSES list (F2: use grep -F for literal matching)
get_epic_status() {
    local epic="$1"
    if [[ -n "$EPIC_STATUSES" ]]; then
        echo "$EPIC_STATUSES" | grep -F "$epic:" | cut -d: -f2
    fi
}

# Render the Kanban board
render_kanban() {
    local total_width=$((COL_WIDTH * 5 + 6))

    # Header (F10: use BOX_* variables for Unicode/ASCII support)
    echo ""
    printf "%b" "${BOLD}${MAGENTA}"
    printf "  %s" "$BOX_TL"
    for i in 1 2 3 4 5; do
        printf "%0.s${BOX_H}" $(seq 1 $COL_WIDTH)
        [[ $i -lt 5 ]] && printf "%s" "$BOX_TM" || printf "%s" "$BOX_TR"
    done
    printf "%b\n" "${RESET}"

    # Project name
    local title="SPRINT BOARD: ${PROJECT_NAME:-Unknown}"
    local title_len=${#title}
    local title_padding=$(( (total_width - title_len - 2) / 2 ))
    printf "${BOLD}${MAGENTA}  %s${RESET}" "$BOX_V"
    printf "%*s${BOLD}${MAGENTA}%s${RESET}%*s" "$title_padding" "" "$title" "$((total_width - title_len - title_padding - 2))" ""
    printf "${BOLD}${MAGENTA}%s${RESET}\n" "$BOX_V"

    # Separator
    printf "%b" "${BOLD}${MAGENTA}  ${BOX_LM}"
    for i in 1 2 3 4 5; do
        printf "%0.s${BOX_H}" $(seq 1 $COL_WIDTH)
        [[ $i -lt 5 ]] && printf "%s" "$BOX_CROSS" || printf "%s" "$BOX_RM"
    done
    printf "%b\n" "${RESET}"

    # Column headers
    printf "${BOLD}${MAGENTA}  %s${RESET}" "$BOX_V"
    printf "${BOLD}${RED}$(pad_str " BACKLOG")${RESET}${BOLD}${MAGENTA}%s${RESET}" "$BOX_V"
    printf "${BOLD}${BLUE}$(pad_str " READY")${RESET}${BOLD}${MAGENTA}%s${RESET}" "$BOX_V"
    printf "${BOLD}${YELLOW}$(pad_str " IN-PROGRESS")${RESET}${BOLD}${MAGENTA}%s${RESET}" "$BOX_V"
    printf "${BOLD}${CYAN}$(pad_str " REVIEW")${RESET}${BOLD}${MAGENTA}%s${RESET}" "$BOX_V"
    printf "${BOLD}${GREEN}$(pad_str " DONE")${RESET}${BOLD}${MAGENTA}%s${RESET}" "$BOX_V"
    echo ""

    # Separator
    printf "%b" "${BOLD}${MAGENTA}  ${BOX_LM}"
    for i in 1 2 3 4 5; do
        printf "%0.s${BOX_HL}" $(seq 1 $COL_WIDTH)
        [[ $i -lt 5 ]] && printf "%s" "$BOX_TCROSS" || printf "%s" "$BOX_RM"
    done
    printf "%b\n" "${RESET}"

    # Calculate max rows needed
    local backlog_count=$(count_list "$BACKLOG")
    local ready_count=$(count_list "$READY")
    local in_progress_count=$(count_list "$IN_PROGRESS")
    local review_count=$(count_list "$REVIEW")
    local done_count=$(count_list "$DONE_ITEMS")

    local max_rows=0
    [[ $backlog_count -gt $max_rows ]] && max_rows=$backlog_count
    [[ $ready_count -gt $max_rows ]] && max_rows=$ready_count
    [[ $in_progress_count -gt $max_rows ]] && max_rows=$in_progress_count
    [[ $review_count -gt $max_rows ]] && max_rows=$review_count
    [[ $done_count -gt $max_rows ]] && max_rows=$done_count

    # Ensure at least one row
    [[ $max_rows -eq 0 ]] && max_rows=1

    # Render rows
    for ((i=0; i<max_rows; i++)); do
        printf "${BOLD}${MAGENTA}  %s${RESET}" "$BOX_V"

        # F7: Fixed column alignment - consistent spacing for all cells
        # Backlog column
        local item=$(get_item "$BACKLOG" "$i")
        if [[ -n "$item" ]]; then
            printf "${RED}$(pad_str " $(truncate_str "$item")")${RESET}"
        else
            printf "$(pad_str "")"
        fi
        printf "${BOLD}${MAGENTA}%s${RESET}" "$BOX_HV"

        # Ready column
        item=$(get_item "$READY" "$i")
        if [[ -n "$item" ]]; then
            printf "${BLUE}$(pad_str " $(truncate_str "$item")")${RESET}"
        else
            printf "$(pad_str "")"
        fi
        printf "${BOLD}${MAGENTA}%s${RESET}" "$BOX_HV"

        # In-Progress column
        item=$(get_item "$IN_PROGRESS" "$i")
        if [[ -n "$item" ]]; then
            printf "${YELLOW}$(pad_str " $(truncate_str "$item")")${RESET}"
        else
            printf "$(pad_str "")"
        fi
        printf "${BOLD}${MAGENTA}%s${RESET}" "$BOX_HV"

        # Review column
        item=$(get_item "$REVIEW" "$i")
        if [[ -n "$item" ]]; then
            printf "${CYAN}$(pad_str " $(truncate_str "$item")")${RESET}"
        else
            printf "$(pad_str "")"
        fi
        printf "${BOLD}${MAGENTA}%s${RESET}" "$BOX_HV"

        # Done column
        item=$(get_item "$DONE_ITEMS" "$i")
        if [[ -n "$item" ]]; then
            printf "${GREEN}$(pad_str " $(truncate_str "$item")")${RESET}"
        else
            printf "$(pad_str "")"
        fi
        printf "${BOLD}${MAGENTA}%s${RESET}" "$BOX_V"
        echo ""
    done

    # Bottom border
    printf "%b" "${BOLD}${MAGENTA}  ${BOX_BL}"
    for i in 1 2 3 4 5; do
        printf "%0.s${BOX_H}" $(seq 1 $COL_WIDTH)
        [[ $i -lt 5 ]] && printf "%s" "$BOX_BM" || printf "%s" "$BOX_BR"
    done
    printf "%b\n" "${RESET}"

    # Summary
    local total=$((backlog_count + ready_count + in_progress_count + review_count + done_count))
    local percent=0
    [[ $total -gt 0 ]] && percent=$((done_count * 100 / total))

    echo ""
    printf "${DIM}  Stories: %d total | ${RED}%d backlog${RESET}${DIM} | ${BLUE}%d ready${RESET}${DIM} | ${YELLOW}%d in-progress${RESET}${DIM} | ${CYAN}%d review${RESET}${DIM} | ${GREEN}%d done${RESET}${DIM} (%d%%)${RESET}\n" \
        "$total" "$backlog_count" "$ready_count" "$in_progress_count" "$review_count" "$done_count" "$percent"

    # Epic summary
    echo ""
    printf "${DIM}  Epics: "
    if [[ -n "$EPICS" ]]; then
        while IFS= read -r epic; do
            local status=$(get_epic_status "$epic")
            local color
            case "$status" in
                backlog) color="$RED" ;;
                in-progress) color="$YELLOW" ;;
                done) color="$GREEN" ;;
                *) color="$RESET" ;;
            esac
            printf "${color}%s${RESET}${DIM} " "$epic"
        done <<< "$EPICS"
    fi
    printf "%b\n" "${RESET}"
    echo ""
}

# Main execution
main() {
    # Step 1: Find config
    local config_path
    if ! config_path=$(find_config); then
        echo -e "${RED}Error: Config not found: _bmad/_memory/config.yaml${RESET}" >&2
        echo -e "${DIM}Searched from: $PWD${RESET}" >&2
        exit 1
    fi

    # Step 2: Get output folder (F6: validate output_folder is not empty)
    local output_folder
    output_folder=$(get_output_folder "$config_path")

    if [[ -z "$output_folder" ]]; then
        echo -e "${RED}Error: output_folder not defined in config${RESET}" >&2
        echo -e "${DIM}Check: $config_path${RESET}" >&2
        exit 1
    fi

    # Step 3: Find sprint-status.yaml
    local sprint_status_path
    if ! sprint_status_path=$(find_sprint_status "$output_folder"); then
        echo -e "${RED}Error: sprint-status.yaml not found${RESET}" >&2
        echo -e "${DIM}Expected at: $output_folder/implementation-artifacts/sprint-status.yaml${RESET}" >&2
        exit 1
    fi

    # Step 4: Parse and render
    parse_sprint_status "$sprint_status_path"
    render_kanban
}

main "$@"
