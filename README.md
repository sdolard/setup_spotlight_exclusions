# Spotlight Exclusions — macOS (fish)

## Purpose

Reduce CPU/IO usage from Spotlight (`mds`, `mds_stores`, `mdworker_shared`) by **excluding noisy directories** (e.g., `node_modules`, `dist`, `.next`) and **app caches** (VS Code, browsers, containers).
The script is **idempotent** (safe to re-run) and adapts to machine differences (only marks what exists).

---

## What this script does

- Creates a `.metadata_never_index` marker in target directories so Spotlight **ignores** them.
- Scans your **dev roots** (defaults to existing among `~/Git`, `~/Code`, `~/Projects`).
- Optionally marks app caches (VS Code, Brave/Chrome/Edge/Firefox), OrbStack, Docker Desktop.
- Can optionally **rebuild** the Spotlight index after marking (`--rebuild`).

**What it does NOT do**

- It does **not** disable Spotlight globally.
- It does **not** delete your data—only creates tiny marker files.

---

## Requirements

- macOS (recent versions, Apple Silicon or Intel).
- **fish** shell.
- `sudo` privileges only if you use `--rebuild`.

---

## Install

Recommended structure:

```text
spotlight-exclusions/
├─ README.md
└─ setup_spotlight_exclusions.fish
```

Make the script executable (optional):

```bash
chmod +x setup_spotlight_exclusions.fish
```

---

## Usage

Dry run (no changes):

```bash
fish setup_spotlight_exclusions.fish --dry-run
```

Standard run:

```bash
fish setup_spotlight_exclusions.fish
```

Mark & **rebuild Spotlight index** afterwards (optional):

```bash
fish setup_spotlight_exclusions.fish --rebuild
```

Help:

```bash
fish setup_spotlight_exclusions.fish -h
```

---

## Environment variables (optional)

You can customize behavior via environment variables (set them before running the script).

- `SPOTLIGHT_DEV_ROOTS`
  Space-separated list of dev roots to scan.
  Default: whichever exist among `~/Git ~/Code ~/Projects`.
  Example:

  ```fish
  set -Ux SPOTLIGHT_DEV_ROOTS "$HOME/Git $HOME/Code"
  ```

- `SPOTLIGHT_EXTRA_GLOBS`
  Extra directory names to mark (space-separated).
  Example:

  ```fish
  set -Ux SPOTLIGHT_EXTRA_GLOBS ".nx .nuxt .docusaurus out coverage"
  ```

- `SPOTLIGHT_MARK_GLOBAL_CACHES=1`
  Also mark `~/Library/Caches` (broad; off by default).

- `SPOTLIGHT_INCLUDE_DOCKER=1`
  Mark Docker Desktop caches if present (off by default).

- `SPOTLIGHT_INCLUDE_BROWSERS=0|1` (default `1`)
  Mark caches for Brave/Chrome/Edge/Firefox if present.

- `SPOTLIGHT_INCLUDE_VSCODE=0|1` (default `1`)
  Mark VS Code caches if present.

- `SPOTLIGHT_INCLUDE_ORBSTACK=0|1` (default `1`)
  Try to mark `~/OrbStack` (some paths may be read-only; harmless warnings).

---

## What gets marked

### Inside your dev roots

By default the script marks directories named:

```text
node_modules, dist, build, .next, .turbo, .vite, .parcel-cache,
.jest, .eslintcache, .pnpm-store, .yarn/cache, .wrangler,
.svelte-kit, out, coverage, .gradle, .venv, .tox, target, .idea, .cache
```

Plus anything you add via `SPOTLIGHT_EXTRA_GLOBS`.

### App caches (optional toggles)

- **VS Code**:
  `~/Library/Application Support/Code/Cache`
  `~/Library/Application Support/Code/CachedData`
- **Browsers** (Brave/Chrome/Edge/Firefox):
  `~/Library/Caches/BraveSoftware`, `~/Library/Caches/Google/Chrome`,
  `~/Library/Caches/Microsoft Edge`, `~/Library/Caches/Firefox`
- **OrbStack**: `~/OrbStack` (may be read-only)
- **Docker Desktop**:
  `~/Library/Containers/com.docker.docker`,
  `~/Library/Group Containers/group.com.docker`
- **Global caches** (if `SPOTLIGHT_MARK_GLOBAL_CACHES=1`):
  `~/Library/Caches`

> Rationale: these paths change frequently and provide little value to Spotlight’s global search.

---

## Verifying results

Top Spotlight processes (should be near zero or absent most of the time):

```bash
ps -Ao %cpu,pid,comm | sort -nr | head -n 30 | egrep 'mds|mdworker|mds_stores' || true
```

Live file activity (10–15 seconds, then Ctrl+C):

```bash
sudo fs_usage -w -f filesys mds_stores mdworker_shared
```

You should **not** see accesses under `.../node_modules`, `.../dist`, `.../.next`, etc.

List markers created (example on `~/Git`):

```bash
find ~/Git -type f -name .metadata_never_index | head -n 20
```

---

## Reverting / unmarking

To re-enable Spotlight indexing for a specific folder, remove the marker:

```bash
rm /path/to/folder/.metadata_never_index
```

Optionally rebuild the index:

```bash
sudo mdutil -E /
```

---

## Notes & compatibility

- Works on recent macOS releases (tested on Sonoma/Sequoia).
- `mdutil` primarily operates **per volume**; for per-directory control the **marker file** is the most reliable method.
- Some locations (e.g., inside OrbStack mounts) may be **read-only**. The script logs a warning and continues.
- The script is **safe to re-run**—it won’t duplicate work and only touches marker files.

---

## FAQ

**Does this disable Spotlight?**
No. Spotlight remains enabled; it simply **skips** marked folders.

**Will this affect VS Code search or dev tools?**
No. Editors and tools maintain their **own** indexes. This only prevents Spotlight from wasting cycles on build/caches.

**Should I commit `.metadata_never_index` to Git?**
No. These are **local** machine preferences. Keep them out of VCS (use `.gitignore` if needed).

---

## Troubleshooting

- **High `mds_stores` CPU after marking**
  Let Spotlight finish compaction/merge. If it persists, try a clean rebuild:

  ```bash
  sudo mdutil -E /
  ```

- **I still see activity under browser/VS Code caches**
  Ensure those specific cache directories exist and were marked (see “Verifying results”).
- **Markers didn’t get created**
  Run with `--dry-run` to inspect candidates. Confirm your dev roots (`SPOTLIGHT_DEV_ROOTS`) are correct and that directories exist.

---

## License

MIT — use at your own risk. The script only creates/deletes small marker files.

---

## Author

Designed for macOS dev workflows with **OrbStack**, **VS Code**, JS/TS monorepos (Vite/Next/Turbo), and common browser caches.
