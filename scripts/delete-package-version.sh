#!/bin/bash

################################################################################
# GitHub Packages Version Deletion Script
# Deletes a specific version from all Maven packages in an organization.
#
# Usage: ./delete-package-version.sh [OPTIONS] <VERSION>
# Options:
#   -d, --dry-run         Preview without deleting
#   -o, --owner OWNER     GitHub organization (default: kubesmarts)
#   -h, --help            Show help
################################################################################

# Configuration
readonly DEFAULT_OWNER="kubesmarts"
readonly PACKAGE_TYPE="maven"
readonly DELAY_SECONDS=1

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Parameters
OWNER="${DEFAULT_OWNER}"
VERSION=""
DRY_RUN=false

# Counters
packages_found=0
packages_with_version=0
versions_deleted=0
errors_count=0

################################################################################
# Functions
################################################################################

show_usage() {
    cat << EOF
GitHub Packages Version Deletion Script

Usage: $0 [OPTIONS] <VERSION>

Arguments:
  VERSION               Version to delete (e.g., 111-SNAPSHOT, 2.0.0)

Options:
  -d, --dry-run         Preview without deleting
  -o, --owner OWNER     GitHub organization (default: ${DEFAULT_OWNER})
  -h, --help            Show this help

Examples:
  $0 111-SNAPSHOT
  $0 2.0.0
  $0 --dry-run 111-SNAPSHOT
  $0 -o myorg 112-SNAPSHOT
EOF
}

# Unified logging function
log() {
    local level="$1"
    local message="$2"
    local color="${NC}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        ERROR)   color="${RED}"; ((errors_count++)) ;;
        SUCCESS) color="${GREEN}" ;;
        WARNING) color="${YELLOW}" ;;
        INFO)    color="${CYAN}" ;;
    esac
    
    echo -e "${timestamp} - ${color}${level}: ${message}${NC}" >&2
}

url_encode() {
    printf '%s' "$1" | jq -sRr @uri
}

check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    if ! command -v gh &> /dev/null; then
        log "ERROR" "GitHub CLI (gh) not installed. Visit: https://cli.github.com/"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log "ERROR" "GitHub CLI not authenticated. Run 'gh auth login'"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log "ERROR" "jq not installed. Install with: brew install jq (macOS) or apt-get install jq (Linux)"
        exit 1
    fi
    
    log "SUCCESS" "Prerequisites check passed"
}

fetch_packages() {
    log "INFO" "Fetching packages for organization: ${OWNER}..."
    
    local page=1
    local per_page=100
    local all_packages=()
    
    while true; do
        local api_url="/orgs/${OWNER}/packages?package_type=${PACKAGE_TYPE}&per_page=${per_page}&page=${page}"
        
        local response=$(gh api \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "${api_url}" 2>/dev/null)
        local gh_exit_code=$?
        
        if [ ${gh_exit_code} -ne 0 ]; then
            log "ERROR" "Failed to fetch packages from API"
            exit 1
        fi
        
        # Validate JSON first
        if ! echo "${response}" | jq empty 2>/dev/null; then
            log "ERROR" "Invalid JSON response from API"
            break
        fi
        
        # Count packages in response
        local package_count=$(echo "${response}" | jq '. | length' 2>/dev/null)
        
        # Extract package names from JSON response
        local packages=$(echo "${response}" | jq -r '.[].name')
        if [ $? -ne 0 ]; then
            log "ERROR" "Failed to parse package names with jq"
            break
        fi
        
        # Check if we got any packages
        if [ -z "${packages}" ] || [ "${package_count}" = "0" ]; then
            break
        fi
        
        # Add packages to array
        while IFS= read -r package; do
            if [ -n "${package}" ]; then
                all_packages+=("${package}")
            fi
        done <<< "${packages}"
        
        ((page++))
    done
    
    packages_found=${#all_packages[@]}
    log "SUCCESS" "Found ${packages_found} packages"
    printf '%s\n' "${all_packages[@]}"
}

delete_package_version() {
    local package_name="$1"
    local current="$2"
    local total="$3"
    
    echo ""
    echo -e "${BLUE}[${current}/${total}]${NC} Checking: ${package_name}"
    
    local encoded_package_name=$(url_encode "${package_name}")
    
    local version_id=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/orgs/${OWNER}/packages/maven/${encoded_package_name}/versions" 2>/dev/null | \
        jq -r ".[] | select(.name == \"${VERSION}\") | .id" 2>/dev/null || echo "")
    
    if [ -n "${version_id}" ]; then
        ((packages_with_version++))
        log "INFO" "Found ${VERSION} (ID: ${version_id})"
        
        if [ "$DRY_RUN" = true ]; then
            log "INFO" "[DRY-RUN] Would delete: ${package_name}:${VERSION}"
            ((versions_deleted++))
        else
            local response=$(gh api \
                -X DELETE \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "/orgs/${OWNER}/packages/maven/${encoded_package_name}/versions/${version_id}" 2>&1)
            
            if [ $? -eq 0 ]; then
                log "SUCCESS" "Deleted ${package_name}:${VERSION}"
                ((versions_deleted++))
            else
                log "ERROR" "Failed to delete ${package_name}:${VERSION} - ${response}"
            fi
            
            [ ${current} -lt ${total} ] && sleep ${DELAY_SECONDS}
        fi
    else
        log "INFO" "No ${VERSION} in ${package_name}"
    fi
}

print_summary() {
    echo ""
    echo "================================================================================"
    [ "$DRY_RUN" = true ] && echo -e "${YELLOW}DRY-RUN MODE${NC}" || echo -e "${BLUE}DELETION SUMMARY${NC}"
    echo "================================================================================"
    echo "Configuration:"
    echo "  Version:        ${VERSION}"
    echo "  Organization:   ${OWNER}"
    echo "  Dry-run:        ${DRY_RUN}"
    echo ""
    echo "Results:"
    echo "  Packages found:       ${packages_found}"
    echo "  With version:         ${packages_with_version}"
    [ "$DRY_RUN" = true ] && \
        echo -e "  ${YELLOW}Would delete:         ${versions_deleted}${NC}" || \
        echo -e "  ${GREEN}Deleted:              ${versions_deleted}${NC}"
    echo -e "  ${RED}Errors:               ${errors_count}${NC}"
    echo "================================================================================"
    
    if [ ${versions_deleted} -gt 0 ]; then
        [ "$DRY_RUN" = true ] && \
            log "INFO" "Dry-run: Would delete ${VERSION} from ${versions_deleted} package(s)" || \
            log "SUCCESS" "Deleted ${VERSION} from ${versions_deleted} package(s)"
    else
        log "INFO" "No versions found to delete"
    fi
    
    [ ${errors_count} -gt 0 ] && log "WARNING" "${errors_count} error(s) occurred"
}

################################################################################
# Main
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dry-run) DRY_RUN=true; shift ;;
            -o|--owner)
                OWNER="$2"
                [ -z "$OWNER" ] && { echo -e "${RED}ERROR: --owner requires a value${NC}"; exit 1; }
                shift 2
                ;;
            -h|--help) show_usage; exit 0 ;;
            -*)
                echo -e "${RED}ERROR: Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
            *)
                [ -z "$VERSION" ] && VERSION="$1" || \
                    { echo -e "${RED}ERROR: Multiple versions provided${NC}"; show_usage; exit 1; }
                shift
                ;;
        esac
    done
    
    # Validate version argument
    if [ -z "$VERSION" ]; then
        echo -e "${RED}ERROR: VERSION argument required${NC}"
        echo ""
        show_usage
        exit 1
    fi
    
    # Allow environment variable override
    [ -n "${GITHUB_OWNER}" ] && [ "${OWNER}" = "${DEFAULT_OWNER}" ] && OWNER="${GITHUB_OWNER}"
    
    # Print header
    echo "================================================================================"
    echo -e "${BLUE}GitHub Packages Version Deletion${NC}"
    echo "================================================================================"
    echo "Organization:   ${OWNER}"
    echo "Version:        ${VERSION}"
    [ "$DRY_RUN" = true ] && \
        echo -e "Mode:           ${YELLOW}DRY-RUN${NC}" || \
        echo -e "Mode:           ${GREEN}LIVE${NC}"
    echo "================================================================================"
    echo ""
    
    log "INFO" "Starting deletion script"
    
    # Check prerequisites
    check_prerequisites
    
    # Fetch packages
    local packages=$(fetch_packages)
    
    # Count packages from the returned list
    if [ -n "${packages}" ]; then
        packages_found=$(echo "${packages}" | wc -l | tr -d ' ')
    else
        packages_found=0
    fi
    
    if [ -z "${packages}" ] || [ ${packages_found} -eq 0 ]; then
        log "WARNING" "No packages found"
        exit 0
    fi
    
    log "INFO" "Checking packages for ${VERSION}..."
    
    # Process packages
    local current=0
    while IFS= read -r package; do
        if [ -n "${package}" ]; then
            ((current++))
            delete_package_version "${package}" ${current} ${packages_found}
        fi
    done <<< "${packages}"
    
    # Print summary
    print_summary
    
    # Exit
    if [ ${errors_count} -gt 0 ]; then
        log "WARNING" "Completed with errors"
        exit 1
    else
        log "SUCCESS" "Completed successfully"
        exit 0
    fi
}

# Entry point
main "$@"

# Made with Bob
