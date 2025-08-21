# File: setup_spotlight_exclusions.fish
# Purpose: Mark noisy dev & cache directories so Spotlight ignores them.
# Shell: fish
# Safe to re-run; will only (re)create .metadata_never_index markers.
#
# USAGE (fish):
#   fish setup_spotlight_exclusions.fish                # run with defaults
#   fish setup_spotlight_exclusions.fish --dry-run      # show what would be marked
#   fish setup_spotlight_exclusions.fish --rebuild      # rebuild Spotlight index after marking
#
# ENV VARS (optional):
#   SPOTLIGHT_DEV_ROOTS        space-separated roots; defaults to existing among: ~/Git ~/Code ~/Projects
#   SPOTLIGHT_EXTRA_GLOBS      extra dir names to mark (e.g. ".wrangler .svelte-kit out coverage")
#   SPOTLIGHT_MARK_GLOBAL_CACHES=1  also mark ~/Library/Caches (broad; off by default)
#   SPOTLIGHT_INCLUDE_DOCKER=1      mark Docker Desktop caches if present (off by default)
#   SPOTLIGHT_INCLUDE_BROWSERS=1    mark common browser caches (Chrome/Edge/Brave/Firefox) (on by default)
#   SPOTLIGHT_INCLUDE_VSCODE=1      mark VS Code caches (on by default)
#   SPOTLIGHT_INCLUDE_ORBSTACK=1    try to mark ~/OrbStack (may be read-only) (on by default)

set -l DRY_RUN 0
set -l DO_REBUILD 0

for arg in $argv
    switch $arg
        case --dry-run
            set DRY_RUN 1
        case --rebuild
            set DO_REBUILD 1
        case -h --help
            echo "Usage: fish (script) [--dry-run] [--rebuild]"
            exit 0
        case '*'
            echo "Unknown flag: $arg"
            exit 1
    end
end

function _say --argument-names msg
    echo (set_color cyan)"[spotlight]"(set_color normal) " $msg"
end

function _mark_dir --argument-names d
    if not test -d "$d"
        _say "skip (missing): $d"
        return 0
    end
    set -l marker "$d/.metadata_never_index"
    if test -e "$marker"
        _say "already:        $d"
        return 0
    end
    if test $DRY_RUN -eq 1
        _say "would-mark:     $d"
    else
        touch "$marker" ^/dev/null
        if test $status -eq 0
            _say "marked:         $d"
        else
            _say "warn: could not create marker in $d (read-only?)"
        end
    end
end

# 1) Figure out dev roots (where your repos live)
set -l DEFAULT_ROOTS "$HOME/Git" "$HOME/Code" "$HOME/Projects"
set -l DEV_ROOTS

if set -q SPOTLIGHT_DEV_ROOTS
    set DEV_ROOTS $SPOTLIGHT_DEV_ROOTS
else
    for r in $DEFAULT_ROOTS
        if test -d "$r"
            set -a DEV_ROOTS "$r"
        end
    end
end

if test (count $DEV_ROOTS) -eq 0
    _say "no dev roots found. Set SPOTLIGHT_DEV_ROOTS, e.g.: set -Ux SPOTLIGHT_DEV_ROOTS \"$HOME/Git $HOME/Code\""
else
    _say "dev roots: "(string join ' ' $DEV_ROOTS)
end

# 2) Directory name globs to exclude inside dev roots
set -l GLOBS node_modules dist build .next .turbo .vite .parcel-cache .jest .eslintcache .pnpm-store .yarn/cache .wrangler .svelte-kit out coverage .gradle .venv .tox target .idea .cache

if set -q SPOTLIGHT_EXTRA_GLOBS
    set -a GLOBS $SPOTLIGHT_EXTRA_GLOBS
end

# 3) Mark noisy directories under each dev root
for root in $DEV_ROOTS
    if not test -d "$root"
        _say "skip non-existent root: $root"
        continue
    end
    _say "scanning: $root"
    # Use /usr/bin/find to avoid fish globbing; prune to avoid deep descent after match
    command find "$root" -type d \( \
        $(for g in $GLOBS
            printf "%s%s" "-name" " " ; printf "%s" "$g" ; printf " -o "
          end | sed 's/ -o $//') \
        \) -prune -print0 | while read -lz d
            _mark_dir "$d"
        end
end

# 4) App caches (conditionally)
# Defaults: include VS Code + browsers; global Caches optional
set -q SPOTLIGHT_INCLUDE_VSCODE; or set -l SPOTLIGHT_INCLUDE_VSCODE 1
set -q SPOTLIGHT_INCLUDE_BROWSERS; or set -l SPOTLIGHT_INCLUDE_BROWSERS 1
set -q SPOTLIGHT_INCLUDE_ORBSTACK; or set -l SPOTLIGHT_INCLUDE_ORBSTACK 1

if test "$SPOTLIGHT_INCLUDE_VSCODE" = 1
    _say "marking VS Code caches (if present)"
    _mark_dir "$HOME/Library/Application Support/Code/Cache"
    _mark_dir "$HOME/Library/Application Support/Code/CachedData"
end

if test "$SPOTLIGHT_INCLUDE_BROWSERS" = 1
    _say "marking common browser caches (if present)"
    # Brave / Chrome / Edge / Firefox caches
    _mark_dir "$HOME/Library/Caches/BraveSoftware"
    _mark_dir "$HOME/Library/Caches/BraveSoftware/Brave-Browser"
    _mark_dir "$HOME/Library/Caches/Google/Chrome"
    _mark_dir "$HOME/Library/Caches/Microsoft Edge"
    _mark_dir "$HOME/Library/Caches/Firefox"
end

if test "$SPOTLIGHT_MARK_GLOBAL_CACHES" = 1
    _say "broad: marking ~/Library/Caches (optional, may hide some Spotlight results in caches)"
    _mark_dir "$HOME/Library/Caches"
end

# 5) Container stacks (OrbStack / Docker Desktop)
if test "$SPOTLIGHT_INCLUDE_ORBSTACK" = 1
    _say "marking OrbStack (may be read-only; safe to try)"
    _mark_dir "$HOME/OrbStack"
end

if test "$SPOTLIGHT_INCLUDE_DOCKER" = 1
    _say "marking Docker Desktop caches (if present)"
    _mark_dir "$HOME/Library/Containers/com.docker.docker"
    _mark_dir "$HOME/Library/Group Containers/group.com.docker"
end

# 6) Optional: rebuild Spotlight index for a clean slate
if test $DO_REBUILD -eq 1
    _say "rebuilding Spotlight index on / (this can take a while)"
    if test $DRY_RUN -eq 1
        _say "dry-run: would run 'sudo mdutil -E /'"
    else
        sudo mdutil -E / ; and _say "rebuild requested"
    end
end

# 7) Final sanity: show top Spotlight processes (should usually be quiet)
_say "top Spotlight processes (if any):"
ps -Ao %cpu,pid,comm | sort -nr | head -n 30 | egrep 'mds|mdworker|mds_stores' || true

_say "done."