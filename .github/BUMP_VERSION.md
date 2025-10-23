# Version Bump Quick Reference

## 🚀 Release Checklist (3 steps)

### 1. Update Version Files
```bash
# Edit Version.swift
# - Update marketing version (e.g., "1.4.1" → "1.5.0")
# - Update build if needed (e.g., "2025.10" → "2025.11")

# Edit RELEASE_NOTES.md
# - Add new version section at top
# - Use format: # Omri v1.5.0
```

### 2. Commit & Tag
```bash
git add -A
git commit -m "bump: v1.5.0"
git tag v1.5.0
```

### 3. Push
```bash
git push origin main --tags
```

**GitHub Actions will automatically:**
- Build `Omri-v1.5.0-apple-silicon.zip`
- Create GitHub Release with RELEASE_NOTES.md
- Attach binary + checksum

---

## 📋 Version Sources

**Single Source of Truth:**
```swift
// Omri/Version.swift
struct AppVersion {
    static let marketing = "1.4.1"  // ← UPDATE HERE
    static let build = "2025.10"     // ← UPDATE HERE
}
```

**Auto-Updated (reads from Version.swift):**
- ✅ SettingsView: `Text(AppVersion.display)` → "Version 1.4.1 • Build 2025.10"
- ✅ GitHub Actions: Extracts version from git tag `v1.4.1`

**Manual Updates:**
- ✅ `Omri/Version.swift` (marketing + build)
- ✅ `RELEASE_NOTES.md` (header: `# Omri v1.4.1`)
- ✅ Git tag (via `git tag v1.4.1`)

---

## 🔍 Verification Commands

```bash
# Check current version in code
grep "marketing = " Omri/Version.swift

# Check RELEASE_NOTES header
head -1 RELEASE_NOTES.md

# Check latest git tag
git tag | sort -V | tail -1

# Check if tag pushed to remote
git ls-remote --tags origin | tail -1

# View commit history with tags
git log --oneline --decorate -5
```

---

## 📝 Version Format

**Semantic Versioning (marketing):**
- `1.4.0 → 1.5.0` = Minor (new features)
- `1.4.0 → 1.4.1` = Patch (bug fixes)
- `1.4.0 → 2.0.0` = Major (breaking changes)

**Build Format:**
- `2025.10` = Year.Month (October 2025)
- `2025.11` = Year.Month (November 2025)

---

## 🎯 Example Workflow

```bash
# 1. Update version files
vi Omri/Version.swift        # Change "1.4.1" → "1.5.0"
vi RELEASE_NOTES.md            # Add "# Omri v1.5.0" section at top

# 2. Commit and tag
git add -A
git commit -m "bump: v1.5.0"
git tag v1.5.0

# 3. Push
git push origin main --tags

# 4. Monitor GitHub Actions
# https://github.com/nasedkinpv/omri/actions

# 5. Verify release created
# https://github.com/nasedkinpv/omri/releases/latest
```

---

## ⚠️ Important Notes

- **Tag format must be `vX.Y.Z`** (lowercase 'v' prefix required for GitHub Actions trigger)
- **Version.swift and RELEASE_NOTES.md must match** (consistency check)
- **Push with `--tags` flag** to include git tags in push
- **GitHub Actions requires tag push** to trigger release workflow
- **Xcode project version** (1.4 in pbxproj) is separate - Version.swift is source of truth for app

---

## 🔗 Related Files

- `Omri/Version.swift` - Single source of truth
- `RELEASE_NOTES.md` - Release notes (gets embedded in GitHub Release)
- `.github/workflows/release.yml` - GitHub Actions release workflow
- `VERSION_BUMP.md` - Detailed version bump documentation (ignored in git)
