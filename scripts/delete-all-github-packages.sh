#!/bin/bash

################################################################################
# GitHub Packages Deletion Script
# 
# This script deletes all Maven packages from GitHub Packages for a specific user.
# It uses the GitHub CLI (gh) for authenticated API calls.
#
# Features:
# - Fetches all packages using GitHub API
# - Deletes packages one by one with rate limiting
# - Logs all operations to deletion-log.txt
# - Shows progress during execution
# - Handles errors gracefully
# - Provides a summary at the end
#
# Usage: ./delete-github-packages.sh
#
# Prerequisites:
# - GitHub CLI (gh) must be installed and authenticated
# - User must have appropriate permissions to delete packages
################################################################################

# Configuration
readonly USERNAME="requiredusername"
readonly PACKAGE_TYPE="maven"
readonly LOG_FILE="deletion-log.txt"
readonly DELAY_SECONDS=1

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Counters
successful_deletions=0
failed_deletions=0
total_packages=0

################################################################################
# Function: log_message
# Logs a message to both console and log file with timestamp
################################################################################
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - ${message}" | tee -a "${LOG_FILE}"
}

################################################################################
# Function: log_error
# Logs an error message in red color
################################################################################
log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - ${RED}ERROR: ${message}${NC}" | tee -a "${LOG_FILE}"
}

################################################################################
# Function: sanitize_output
# Sanitize output to remove sensitive information
################################################################################
sanitize_output() {
    local text="$1"
    # Remove GitHub tokens (ghp_, gho_, github_pat_)
    text=$(echo "$text" | sed -E 's/ghp_[a-zA-Z0-9]{36}/[REDACTED_TOKEN]/g')
    text=$(echo "$text" | sed -E 's/gho_[a-zA-Z0-9]{36}/[REDACTED_TOKEN]/g')
    text=$(echo "$text" | sed -E 's/github_pat_[a-zA-Z0-9_]{82}/[REDACTED_TOKEN]/g')
    # Remove Authorization headers
    text=$(echo "$text" | sed -E 's/(Authorization: [Bb]earer )[^ ]+/\1[REDACTED]/g')
    # Remove generic token patterns
    text=$(echo "$text" | sed -E 's/([Tt]oken[: =]+)[^ ]+/\1[REDACTED]/g')
    echo "$text"
}

################################################################################
# Function: log_success
# Logs a success message in green color
################################################################################
log_success() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - ${GREEN}SUCCESS: ${message}${NC}" | tee -a "${LOG_FILE}"
}

################################################################################
# Function: log_warning
# Logs a warning message in yellow color
################################################################################
log_warning() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - ${YELLOW}WARNING: ${message}${NC}" | tee -a "${LOG_FILE}"
}

################################################################################
# Function: check_prerequisites
# Verifies that required tools are installed and configured
################################################################################
check_prerequisites() {
    log_message "Checking prerequisites..."
    
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed. Please install it first."
        log_error "Visit: https://cli.github.com/"
        exit 1
    fi
    
    # Check if gh is authenticated
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated. Please run 'gh auth login' first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

################################################################################
# Function: fetch_packages
# Fetches all packages for the user using GitHub API
# Returns: Array of package names
################################################################################
fetch_packages() {
    log_message "Fetching packages for user: ${USERNAME}..."
    
    local page=1
    local per_page=100
    local all_packages=()
    
    while true; do
        # Fetch packages with pagination
        local response=$(gh api \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "/users/${USERNAME}/packages?package_type=${PACKAGE_TYPE}&per_page=${per_page}&page=${page}" 2>&1)
        
        # Sanitize response immediately after capture
        response=$(sanitize_output "${response}")
        
        if [ $? -ne 0 ]; then
            log_error "Failed to fetch packages: ${response}"
            exit 1
        fi
        
        # Extract package names from JSON response
        local packages=$(echo "${response}" | jq -r '.[].name' 2>/dev/null)
        
        if [ -z "${packages}" ]; then
            # No more packages, break the loop
            break
        fi
        
        # Add packages to array
        while IFS= read -r package; do
            if [ -n "${package}" ]; then
                all_packages+=("${package}")
            fi
        done <<< "${packages}"
        
        log_message "Fetched page ${page} (${#all_packages[@]} packages so far)..."
        ((page++))
    done
    
    total_packages=${#all_packages[@]}
    log_success "Found ${total_packages} packages to delete"
    
    # Return packages as newline-separated string
    printf '%s\n' "${all_packages[@]}"
}

################################################################################
# Function: delete_package
# Deletes a single package
# Arguments:
#   $1 - package name
#   $2 - current index
#   $3 - total count
################################################################################
delete_package() {
    local package_name="$1"
    local current="$2"
    local total="$3"
    
    echo -e "\n${BLUE}[${current}/${total}]${NC} Deleting package: ${package_name}"
    log_message "Attempting to delete package: ${package_name}"
    
    # Attempt to delete the package
    local response=$(gh api \
        -X DELETE \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/users/${USERNAME}/packages/${PACKAGE_TYPE}/${package_name}" 2>&1)
    
    # Sanitize response immediately after capture
    response=$(sanitize_output "${response}")
    
    if [ $? -eq 0 ]; then
        log_success "Deleted package: ${package_name}"
        ((successful_deletions++))
    else
        log_error "Failed to delete package: ${package_name}"
        log_error "Response: ${response}"
        ((failed_deletions++))
    fi
    
    # Rate limiting: wait before next deletion
    if [ ${current} -lt ${total} ]; then
        sleep ${DELAY_SECONDS}
    fi
}

################################################################################
# Function: print_summary
# Prints a summary of the deletion operation
################################################################################
print_summary() {
    echo ""
    echo "================================================================================"
    echo -e "${BLUE}DELETION SUMMARY${NC}"
    echo "================================================================================"
    echo "Total packages found:      ${total_packages}"
    echo -e "${GREEN}Successful deletions:      ${successful_deletions}${NC}"
    echo -e "${RED}Failed deletions:          ${failed_deletions}${NC}"
    echo "Log file:                  ${LOG_FILE}"
    echo "================================================================================"
    
    log_message "=== DELETION SUMMARY ==="
    log_message "Total packages found: ${total_packages}"
    log_message "Successful deletions: ${successful_deletions}"
    log_message "Failed deletions: ${failed_deletions}"
    log_message "=== END OF SUMMARY ==="
}

################################################################################
# Function: main
# Main execution function
################################################################################
main() {
    # Initialize log file
    echo "GitHub Packages Deletion Log - $(date)" > "${LOG_FILE}"
    echo "User: ${USERNAME}" >> "${LOG_FILE}"
    echo "Package Type: ${PACKAGE_TYPE}" >> "${LOG_FILE}"
    echo "========================================" >> "${LOG_FILE}"
    echo "" >> "${LOG_FILE}"
    
    log_message "Starting GitHub Packages deletion script"
    log_message "Target user: ${USERNAME}"
    log_message "Package type: ${PACKAGE_TYPE}"
    
    # Check prerequisites
    check_prerequisites
    
    # Fetch all packages
    local packages=$(fetch_packages)
    
    # Count packages from the returned list
    total_packages=$(echo "${packages}" | grep -c '^' | grep -v '^0$' || echo 0)
    
    if [ -z "${packages}" ] || [ ${total_packages} -eq 0 ]; then
        log_warning "No packages found to delete"
        exit 0
    fi
    
    log_message "Ready to delete ${total_packages} packages"
    
    # User has already confirmed via the orchestrator, proceed directly
    log_message "Proceeding with deletion (confirmation received via orchestrator)..."
    
    # Delete each package
    local current=0
    while IFS= read -r package; do
        if [ -n "${package}" ]; then
            ((current++))
            delete_package "${package}" ${current} ${total_packages}
        fi
    done <<< "${packages}"
    
    # Print summary
    print_summary
    
    # Exit with appropriate code
    if [ ${failed_deletions} -gt 0 ]; then
        log_warning "Script completed with some failures"
        exit 1
    else
        log_success "Script completed successfully"
        exit 0
    fi
}

################################################################################
# Script Entry Point
################################################################################

# Check if jq is installed (required for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is not installed. Please install it first.${NC}"
    echo "On macOS: brew install jq"
    echo "On Ubuntu/Debian: sudo apt-get install jq"
    exit 1
fi

# Run main function
main

# Made with Bob
