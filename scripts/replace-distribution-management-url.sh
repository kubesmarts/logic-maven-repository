#!/bin/bash

# Script: replace-distribution-management-url.sh
# Purpose: Replace distributionManagement URLs in pom.xml files within a target directory
# 
# This script finds all pom.xml files in the specified directory and replaces URLs
# matching the old repository URL within <distributionManagement> sections with a new repository URL.
#
# This is necessary because -DaltDeploymentRepository doesn't work for complex
# multi-module Maven projects like kie-tools.
#
# Usage: ./replace-distribution-management-url.sh <target_directory> <old_repository_url> <new_repository_url>
#
# Arguments:
#   target_directory      - Directory containing pom.xml files to update (e.g., "kie-tools")
#   old_repository_url    - Old Maven repository URL to replace
#   new_repository_url    - New Maven repository URL to use
#
# Example:
#   ./replace-distribution-management-url.sh kie-tools \
#     https://maven.pkg.github.com/kubesmarts/logic-maven-repository \
#     https://maven.pkg.github.com/baldimir/logic-maven-repository

set -e  # Exit on error

# Validate arguments
if [ $# -ne 3 ]; then
    echo "Error: Invalid number of arguments"
    echo "Usage: $0 <target_directory> <old_repository_url> <new_repository_url>"
    exit 1
fi

TARGET_DIR="$1"
OLD_REPO_URL="$2"
NEW_REPO_URL="$3"

# Validate target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Target directory '$TARGET_DIR' does not exist"
    exit 1
fi

# Process all pom.xml files
# The sed command operates only within <distributionManagement>...</distributionManagement> sections
# and replaces URLs matching the old repository URL with the new URL
find "$TARGET_DIR" -name "pom.xml" -type f -exec sed -i '' -e \
    "/<distributionManagement>/,/<\/distributionManagement>/ s|<url>$OLD_REPO_URL</url>|<url>$NEW_REPO_URL</url>|g" \
    {} \;

echo "✓ Updated distributionManagement URLs in pom.xml files"

# Made with Bob
