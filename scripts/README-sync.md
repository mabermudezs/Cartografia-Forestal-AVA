**Sync Scripts**

- **PowerShell**: `scripts/sync-docs.ps1` — use on Windows with `robocopy`.
- **Bash/WSL**: `scripts/sync-docs.sh` — use with `rsync` (WSL or Git Bash with rsync).

Both scripts:
- create a branch `update/docs-sync` from `origin/main` (or reset it if exists)
- mirror the folders `Datos`, `Documentación` and `media` from a provided source path
- stage only those folders, commit with a clear message and optionally push the branch
- explicitly restore `README.md` and `Evaluación/` from `HEAD` if changed by accident

Recommended flow:
1. Run the script locally pointing to your source (`D:\AVA\Cartografia-Forestal-AVA_source`).
2. Inspect the branch `update/docs-sync` and open a PR for review before merging to `main`.

If you want me to merge the branch into `main` after you push it, tell me and I will do the merge here (or perform the merge locally and push).
