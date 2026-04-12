# macOS Compatibility Issues - Ranked by Severity

## Summary
Total files audited: 7  
Breaking issues: 1  
Cosmetic issues: 1  
Already compatible: 5  

## Issue List (Highest to Lowest Severity)

### BREAKING (Script fails on macOS)

| File | Line | Issue | Severity | Description | Fix Required |
|------|------|-------|----------|-------------|--------------|
| `test_cross_platform.sh` | 71 | `grep -qP` | BREAKING | BSD grep doesn't support `-P` (Perl regex) flag | Replace with `grep -E` and convert pattern to ERE |

### COSMETIC (Works but confusing message)

| File | Line | Issue | Severity | Description | Fix Required |
|------|------|-------|----------|-------------|--------------|
| `skills/pdf-ingest/scripts/ingest.sh` | 17-18 | Package name in error message | COSMETIC | Says "install poppler-utils" (Linux) vs "poppler" (Mac) | Update error message to mention both |

### ALREADY COMPATIBLE (No action needed)

| File | Compatibility Handled | Status |
|------|----------------------|---------|
| `set_claude.sh` | sed -i + shell detection | ✅ GOOD |
| `setup_codex.sh` | sed -i + readlink -f + POSIX regex | ✅ GOOD |
| `patches/fix-humanize-openrouter-model.sh` | awk-only approach, mktemp, find -print0 | ✅ GOOD |
| `patches/fix-humanize-session-id.sh` | awk-only approach, POSIX char classes | ✅ GOOD |
| `skills/pdf-ingest/scripts/ingest.sh` | command -v, basic file ops, wc -l (echo-only) | ✅ GOOD |

## Specific Pattern Conversions Required

### grep -qP → grep -E Conversion
**Current (Line 71):**
```bash
if grep -qP '\\\\s|\\\\+' setup_codex.sh 2>/dev/null; then
```

**Fixed (ERE equivalent):**
```bash
if grep -qE '\\\\s|\\\\+' setup_codex.sh 2>/dev/null; then
```

Note: This specific pattern `\\\\s|\\\\+` actually works with ERE since it's looking for literal backslash-s and backslash-plus sequences, not PCRE metacharacters.

## Web Research Sources Used

This audit was informed by current macOS compatibility documentation:

**sed -i compatibility:**
- [sed Tutorial => BSD/macOS Sed vs. GNU Sed vs. the POSIX Sed...](https://riptutorial.com/sed/topic/9436/bsd-macos-sed-vs--gnu-sed-vs--the-posix-sed-specification)
- [Using sed "in place" (gnu vs bsd) - The Meditative Coder](http://blog.geeky-boy.com/2020/11/using-sed-in-place-gnu-vs-bsd.html)
- [Fixing 'sed -i' In-Place Edit Errors Across GNU and BSD/macOS Systems](https://sqlpey.com/bash/sed-in-place-portability-fix/)

**readlink -f compatibility:**
- [How to get GNU's readlink -f behavior on OS X. · GitHub](https://gist.github.com/esycat/5279354)
- [Using GNU command line tools in macOS instead of FreeBSD tools · GitHub](https://gist.github.com/skyzyx/3438280b18e4f7c490db8a2a2ca0b9da)

**grep -P compatibility:**
- [Perl Compatible Regular Expressions - CLI text processing with GNU grep and ripgrep](https://learnbyexample.github.io/learn_gnugrep_ripgrep/perl-compatible-regular-expressions.html)
- [Grep BSD posix regular expression alterna… - Apple Community](https://discussions.apple.com/thread/5832809)
- [Install gnu grep on mac osx - Hey Stephen Wood](https://www.heystephenwood.com/2013/09/install-gnu-grep-on-mac-osx.html)

**Cross-platform shell scripting:**
- [Write Cross-Platform Shell: Linux vs macOS Differences That Break Production](https://tech-champion.com/programming/write-cross-platform-shell-linux-vs-macos-differences-that-break-production/)
- [Linux (GNU) vs. Mac (BSD) Command Line Utilities | Ponder The Bits](https://ponderthebits.com/2017/01/know-your-tools-linux-gnu-vs-mac-bsd-command-line-utilities-grep-strings-sed-and-find/)