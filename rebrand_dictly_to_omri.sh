#!/bin/bash

# Dictly → Omri Complete Rebrand Script
# This script performs comprehensive find-and-replace across the entire codebase
# Run from project root: ./rebrand_dictly_to_omri.sh

set -e  # Exit on error

echo "🚀 Starting Dictly → Omri rebrand..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to replace text in files
replace_in_files() {
    local find_text="$1"
    local replace_text="$2"
    local description="$3"

    echo -e "${BLUE}📝 Replacing: ${description}${NC}"

    # Find all text files (excluding binary, git, build artifacts)
    find . -type f \
        ! -path "./.git/*" \
        ! -path "./build/*" \
        ! -path "./DerivedData/*" \
        ! -path "*/.DS_Store" \
        ! -path "*.xcodeproj/project.xcworkspace/*" \
        ! -path "*.xcodeproj/xcuserdata/*" \
        ! -name "*.png" \
        ! -name "*.jpg" \
        ! -name "*.ttf" \
        ! -name "rebrand_dictly_to_omri.sh" \
        -exec grep -l "$find_text" {} \; 2>/dev/null | while read file; do

        # Use sed for in-place replacement
        sed -i '' "s/${find_text}/${replace_text}/g" "$file"
        echo "  ✓ Updated: $file"
    done

    echo ""
}

# Phase 1: Main application name
replace_in_files "Dictly" "Omri" "Main app name (Dictly → Omri)"

# Phase 2: Case variations
replace_in_files "dictly" "omri" "Lowercase references (dictly → omri)"
replace_in_files "DICTLY" "OMRI" "Uppercase references (DICTLY → OMRI)"

# Phase 3: Bundle identifiers
replace_in_files "com\.beneric\.Dictly" "com.beneric.Omri" "macOS bundle ID"
replace_in_files "Beneric\.DictlyiOS" "Beneric.OmriiOS" "iOS bundle ID"

# Phase 4: iOS folder references (before actual rename)
replace_in_files "DictlyiOS" "OmriiOS" "iOS folder references"

# Phase 5: Brand color names
replace_in_files "dictlyBrandGradient" "omriBrandGradient" "Brand gradient references"
replace_in_files "dictlyPremiumGradient" "omriPremiumGradient" "Premium gradient references"

# Phase 6: UI component names
replace_in_files "DictlyIcon" "OmriIcon" "Icon component"
replace_in_files "DictlyStatusIndicator" "OmriStatusIndicator" "Status indicator component"
replace_in_files "DictlyApp" "OmriApp" "App struct name"

echo -e "${GREEN}✅ Text replacements complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps (Manual):${NC}"
echo "1. Close Xcode completely"
echo "2. Rename files/folders:"
echo "   mv Dictly.xcodeproj Omri.xcodeproj"
echo "   mv Dictly Omri"
echo "   mv DictlyiOS OmriiOS"
echo "   mv OmriiOS/DictlyApp.swift OmriiOS/OmriApp.swift"
echo "3. Rename screenshots:"
echo "   cd screenshots && for f in dictly*; do mv \"\$f\" \"\${f/dictly/omri}\"; done && cd .."
echo "4. Rename scheme files in Omri.xcodeproj/xcshareddata/xcschemes/"
echo "   mv Dictly.xcscheme Omri.xcscheme"
echo "   mv DictlyiOS.xcscheme OmriiOS.xcscheme"
echo "5. Clean build:"
echo "   rm -rf build/ DerivedData/"
echo "6. Open Omri.xcodeproj in Xcode and rebuild"
echo ""
echo -e "${GREEN}🎉 Rebrand script complete!${NC}"
