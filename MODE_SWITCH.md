**Mode Switch Checklist & Script**

- Files created:
  - `scripts/switch-mode.ps1` — PowerShell script to switch between `dev` and `prod` modes.

**Overview**
- `dev` mode:
  - Sets `SEARXNG_HOSTNAME=localhost:8334` and `LETSENCRYPT_EMAIL=` in `.env`.
  - Forces `SEARXNG_TLS=internal` in `docker-compose.yaml` and `SEARXNG_BASE_URL` to `http://localhost:8334/`.
  - Recreates `caddy` and `searxng` containers (no-deps, force recreate).

- `prod` mode:
  - Requires `-Domain` and `-Email` arguments.
  - Writes `SEARXNG_HOSTNAME=<domain>` and `LETSENCRYPT_EMAIL=<email>` to `.env`.
  - Sets `SEARXNG_TLS=${LETSENCRYPT_EMAIL:-}` in `docker-compose.yaml` and `SEARXNG_BASE_URL=https://<domain>/`.
  - Renames Caddy `autosave.json` (backup) so Caddy reads the `Caddyfile` and can request ACME certs.
  - Recreates the entire stack (`docker-compose down` then `up -d`).

**Usage examples**

- Switch to dev mode:
```powershell
# from repository root
.\scripts\switch-mode.ps1 -Mode dev
```

- Switch to prod mode:
```powershell
.\scripts\switch-mode.ps1 -Mode prod -Domain example.com -Email admin@example.com
```

**Safety & notes**
- The script creates timestamped backups for `.env`, `docker-compose.yaml`, and `caddy/config/caddy/autosave.json` before modifying them.
- Review backups in case you want to revert: files are saved with `.<timestamp>.bak` suffix.
- For production, ensure DNS A/AAAA records point to the host, and ports 80/443 are open and forwarded to the Docker host.
- Consider testing ACME on staging CA before production to avoid rate limits.
- Do NOT commit secrets or `LETSENCRYPT_EMAIL` to public repositories.

**Next steps**
- Want me to run the script now (which will recreate containers)?
- Or would you like the script adapted (e.g., use Docker plugin `docker compose` instead of `docker-compose`)?
