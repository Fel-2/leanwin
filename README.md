# LEANWIN

Windows Server 2022 Datacenter Core running on Linux via Docker + KVM — a lean, reproducible Windows build environment for cross-compiling .NET, MSVC, and Windows-native software without leaving Linux.

```
 _      ______          _   ___          _______ _   _
| |    |  ____|   /\   | \ | \ \        / /_   _| \ | |
| |    | |__     /  \  |  \| |\ \  /\  / /  | | |  \| |
| |    |  __|   / /\ \ | . ` | \ \/  \/ /   | | | . ` |
| |____| |____ / ____ \| |\  |  \  /\  /   _| |_| |\  |
|______|______/_/    \_\_| \_|   \/  \/   |_____|_| \_|
```

## Requirements

- **Linux host** with KVM support (`/dev/kvm` present)
- **x86_64 / amd64** — Windows Server has no ARM Core image in `dockurr/windows`. Apple Silicon / ARM Linux not supported.
- **Docker** + `docker compose` v2
- **~40 GB** free disk for the VM image + cache
- **Filesystem**: XFS or ext4 recommended. BTRFS has known issues with Windows Setup.

## Quick Start

```bash
# Prerequisites: Linux with KVM support
ls /dev/kvm

# Clone and start
git clone <repo> leanwin
cd leanwin
make up                      # or: docker compose up -d

# Watch the install via web VNC
open http://localhost:8006

# Wait for provisioning (~15-20 min on first boot)
make health                  # poll until ready
make ssh                     # interactive shell

# Verify with a hello-world build:
./examples/hello-rust/build.sh
```

Convenience targets via `make`: `up`, `down`, `ssh`, `logs`, `health`, `reprovision`, `clean`.

## What You Get

| Resource | Spec |
|----------|------|
| OS | Windows Server 2022 Datacenter Core (no GUI) |
| RAM | 4 GB |
| CPU | 4 cores |
| Disk | 32 GB |
| SSH | Port **2223** (key + password auth) |
| RDP | Port **3389** |
| VNC | Port **8006** |

### Dev Toolchain

All tools install latest stable at first boot unless noted.

- **MSVC** + **MSBuild** — Visual Studio 2022 Build Tools
- **.NET Framework 4.8 SDK**
- **Windows 10 SDK** (20348)
- **Git** for Windows
- **Chocolatey** — package manager
- **winget** — portable (Server Core compatible)
- **Rust** (stable) via rustup with MSVC + GNU targets, MinGW-w64 linker
- **Python** + pip + venv, **pyenv-win** (Python version manager)
- **Node.js** LTS + npm, **nvm-windows** (Node version manager)
- **CMake**, **GNU Make**, **WiX Toolset**, **NuGet CLI**, **Strawberry Perl**
- **Neovim** — with LSP (clangd, powershell_es, lua_ls), telescope, oil.nvim, nvim-cmp, catppuccin theme
- **Oh My Posh** — prompt theme (montys)
- **PSReadLine** 2.2.6 (pinned — newer versions break Server Core SSH)
- **fastfetch** — system info with custom LEANWIN ASCII art logo
- **ripgrep**, **fd**, **7zip**, **bottom** (btm), **zellij** (tmux alternative)

### Hardening

- Telemetry: disabled (registry + services + 10 scheduled tasks)
- Windows Update: disabled
- Windows Defender real-time: disabled
- High-performance power scheme

## Architecture

```
┌─────────────────────────────────────────────┐
│  Linux Host                                  │
│  ┌─────────────────────────────────────────┐ │
│  │  Docker Container (dockurr/windows)     │ │
│  │  ┌───────────────────────────────────┐  │ │
│  │  │  Windows Server 2022 Core (KVM)   │  │ │
│  │  │  SSH:22  │  RDP:3389  │  VNC      │  │ │
│  │  │  user: builder / pass: build      │  │ │
│  │  │  SSH key: leanwin_key             │  │ │
│  │  │  Tools: MSVC, Git, nvim, choco…   │  │ │
│  │  └───────────────────────────────────┘  │ │
│  │  Volumes:                                │ │
│  │    ./oem/ → C:\oem (provisioning)       │ │
│  │    ./shared/ → \\host.lan\Shared        │ │
│  │    ./storage/ → system disk (persistent) │ │
│  └─────────────────────────────────────────┘ │
│  Ports: 2223→22  │  3389  │  8006            │
└─────────────────────────────────────────────┘
```

## Ports

| Host Port | Service | Notes |
|-----------|---------|-------|
| 2223 | SSH | Primary access — use key auth or password |
| 2224 | Build API | HTTP build server (`/exec`, `/upload`, `/download`) |
| 3389 | RDP | Remote Desktop (Server Core has no GUI though) |
| 8006 | VNC | Web-based viewer — watch Windows install |

## Access

### SSH (primary)

```bash
# Password auth
ssh -p 2223 builder@localhost

# Key auth (recommended — key generated during setup)
ssh -i leanwin_key -p 2223 builder@localhost
```

Credentials: `builder` / `build`

### VNC (for initial setup / debugging)

Open `http://localhost:8006` in a browser. Shows the Windows console during boot and provisioning.

### File Exchange

Files placed in `./shared/` on the host are available inside Windows at `\\host.lan\Shared`.

## Provisioning

On first boot, the container automatically runs `oem/install.bat` which:

1. Enables OpenSSH Server and sets PowerShell as default shell
2. Renames the machine to LEANWIN
3. Installs Git for Windows
4. Installs Chocolatey + dev tools (neovim, ripgrep, fd, 7zip, bottom, fastfetch)
5. Installs VS Build Tools with MSVC + .NET 4.8 SDK + Windows SDK
6. Installs Oh My Posh (montys theme), zellij, winget
7. Configures PowerShell profile — fastfetch MOTD with usage tips, Oh My Posh prompt, aliases (`ll`/`grep`/`which`/`reboot`/`poweroff`), PSReadLine suggestions
8. Sets up Neovim with full config (init.lua)
9. Configures fastfetch with custom LEANWIN logo
10. Disables telemetry, updates, Defender real-time

### Reprovisioning

To re-run provisioning against a running instance:

```bash
docker compose exec windows /oem/install.bat
```

Or start fresh:

```bash
docker compose down
rm -rf storage
docker compose up -d
```

## SSH Key

During initial setup, a 4096-bit RSA key pair is generated:

- **Private**: `leanwin_key` (in project root)
- **Public**: `leanwin_key.pub`

The public key is placed in `administrators_authorized_keys` (required for admin users on Windows OpenSSH — not the standard `authorized_keys` path).

## File Layout

```
leanwin/
├── docker-compose.yml    # Container config
├── Makefile              # Common ops: up/down/ssh/clean/health/...
├── LICENSE               # MIT
├── leanwin.sh            # SSH helper (escapes PS quoting)
├── leanwin_key           # SSH private key (generated)
├── leanwin_key.pub       # SSH public key (generated)
├── README.md             # This file
├── oem/
│   ├── install.bat       # Post-install provisioning script
│   ├── init.lua          # Neovim configuration
│   ├── fastfetch.jsonc   # fastfetch custom config
│   ├── logo.txt          # LEANWIN ASCII logo
│   └── build-server.js   # HTTP build server (Node.js, zero deps)
├── examples/             # Sample projects (Rust, .NET) to verify setup
├── shared/               # File exchange — mounted into Windows
└── storage/              # Persistent VM disk image
```

## CI/CD Integration

The VM runs a **lightweight HTTP build server** (Node.js, zero deps) as a scheduled task (auto-starts on boot). It listens inside the VM on port **8080**, mapped to host port **2224** by `docker-compose.yml`. No SSH quoting hell — just `curl`.

```bash
# Run a build
curl -X POST http://localhost:2224/exec \
  -H 'Content-Type: application/json' \
  -d '{"cmd": "cd C:\\project ; cargo build --release"}'

# Upload source
curl -X POST http://localhost:2224/upload?dest=C:\project\src\main.rs \
  --data-binary @src/main.rs

# Download artifact
curl -o myapp.exe http://localhost:2224/download?path=C:\project\target\release\myapp.exe
```

### API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET`  | `/health` | Readiness probe — `{ok: true}`. Unauthenticated. |
| `POST` | `/exec` | Run a command. Body: `{"cmd": "...", "cwd": "..."}`. Returns `{ok, stdout, stderr, exitCode}` |
| `POST` | `/upload?dest=<path>` | Upload file. Stream raw body to destination path |
| `GET` | `/download?path=<path>` | Download artifact file |

Response format (all endpoints):

```json
{ "ok": true, "stdout": "...", "stderr": "...", "exitCode": 0 }
```

Notes:
- **Shell**: Default is `cmd.exe` (exit codes work correctly). Prefix a command with `ps:` to run in PowerShell instead (e.g., `{"cmd": "ps:Get-Process"}`).
- **Chaining**: `;` is auto-converted to `&` (cmd.exe syntax) for convenience.
- **Timeout**: 10 minutes per command.
- **Workdir**: Default is `C:\builds`. Pass `"cwd": "..."` to change.
- **Auth (optional)**: If `LEANWIN_TOKEN` is set in the build-server environment, all requests must include `X-Auth-Token: <token>`. Unset = no auth (local dev default).

### Security Note

The compose file ships with **hardcoded credentials** (`builder` / `build`) and the build server has **no auth by default**. This is fine for a local-only build box bound to `localhost`. If you expose ports 2223/2224 to a network:

1. Change `USERNAME` / `PASSWORD` in `docker-compose.yml`.
2. Set `LEANWIN_TOKEN=<long-random-string>` on the `LeanwinBuildServer` scheduled task.
3. Disable password SSH auth — rely on `leanwin_key` only.

### GitHub Actions

```yaml
# .github/workflows/build.yml
jobs:
  build:
    runs-on: ubuntu-latest
    env:
      BS: http://${{ secrets.LEANWIN_HOST }}:2224
    steps:
      - uses: actions/checkout@v4
      - name: Windows build
        run: |
          find . -type f | while read f; do
            rel="${f#./}"
            curl -s -X POST "$BS/upload?dest=C:\\project\\${rel//\//\\}" \
              --data-binary "@$f"
          done
          curl -s -X POST "$BS/exec" \
            -H 'Content-Type: application/json' \
            -d '{"cmd": "cd C:\\project ; cargo build --release"}'
          curl -o myapp.exe \
            "$BS/download?path=C:\\project\\target\\release\\myapp.exe"
      - uses: actions/upload-artifact@v4
        with:
          name: windows-build
          path: myapp.exe
```

### GitLab CI

```yaml
windows-build:
  stage: build
  image: alpine:latest
  variables:
    BS: "http://$LEANWIN_HOST:2224"
  before_script:
    - apk add curl
  script:
    - find . -type f | while read f; do
        rel="${f#./}"
        curl -s -X POST "$BS/upload?dest=C:\\project\\${rel//\//\\}" \
          --data-binary "@$f"
      done
    - curl -s -X POST "$BS/exec" \
        -H 'Content-Type: application/json' \
        -d '{"cmd": "cd C:\\project ; cargo build --release"}'
    - curl -o myapp.exe \
        "$BS/download?path=C:\\project\\target\\release\\myapp.exe"
  artifacts:
    paths: [myapp.exe]
```

### Jenkins

```groovy
pipeline {
    agent any
    environment {
        BS = "http://${env.LEANWIN_HOST}:2224"
    }
    stages {
        stage('Windows Build') {
            steps {
                sh """
                    find . -type f | while read f; do
                        rel="\${f#./}"
                        curl -s -X POST "$BS/upload?dest=C:\\\\project\\\\\${rel//\\//\\\\}" \
                          --data-binary "@\$f"
                    done
                    curl -s -X POST "$BS/exec" -H 'Content-Type: application/json' \
                      -d '{"cmd": "cd C:\\\\project ; cargo build --release"}'
                    curl -o myapp.exe "$BS/download?path=C:\\\\project\\\\target\\\\release\\\\myapp.exe"
                """
            }
        }
    }
    post {
        success { archiveArtifacts 'myapp.exe' }
    }
}
```

### Legacy: SSH Executor (Fallback)

If you prefer SSH over HTTP, the old pattern still works:

```bash
ssh -p 2223 builder@localhost "cd C:\project ; cargo build --release"
```

Use `leanwin.sh` (see below) when PowerShell quoting causes issues.

### File Exchange

| Method | Direction | Best For |
|--------|-----------|----------|
| Build server `/upload` + `/download` (port 2224) | Both | CI pipelines (structured) |
| `./shared/` → `\\host.lan\Shared` | Host → VM | Large source drops, secrets |
| SCP (`-P 2223`) | Both | Ad-hoc, one-off files |

### Isolation (Start Clean Each Build)

```bash
docker compose down
rm -rf storage
docker compose up -d
# Wait ~3 min for boot + provisioning, then build
```

## Notes

- **BTRFS warning**: Windows Setup may have issues on BTRFS filesystems. XFS/ext4 recommended for `storage/`.
- **Server Core**: No GUI — everything goes through SSH, PowerShell, or the web VNC viewer.
- **PSReadLine**: Predictive suggestions require VT processing (works in interactive SSH). Non-interactive commands silently fall back.
- **fastfetch config**: Must be UTF-8 without BOM on Windows. Written via `[System.Text.UTF8Encoding]::new($false)`.
- **Windows OpenSSH**: Admin users require `administrators_authorized_keys`, not `~/.ssh/authorized_keys`.

## Licensing

| Component | License |
|-----------|---------|
| LEANWIN code (this repo) | MIT — see [LICENSE](LICENSE) |
| Windows Server 2022 | **Microsoft Evaluation License** — 180-day trial, then activation required |
| `dockurr/windows` base image | MIT |
| Bundled tools | Each retains its own license (MSVC Build Tools, etc.) |

**Important — Windows licensing:**

The ISO downloaded by `dockurr/windows` is Microsoft's free 180-day evaluation. After 180 days you must:

- **Activate** with a valid Windows Server 2022 product key, or
- **Rearm** the eval up to 6 times (`slmgr /rearm`) for ~3 years total, or
- **Wipe and rebuild** (`docker compose down && rm -rf storage && docker compose up -d`) for a fresh 180 days

Bring your own license for production. For build-box use (rebuilt frequently anyway) the eval is fine.

## Host Helper

The project includes `leanwin.sh` — a wrapper that handles the PowerShell quoting nightmare transparently:

```bash
# Interactive SSH
./leanwin.sh

# Single command
./leanwin.sh "cargo build --release"

# Chained commands (use ; not && — PS 5.1 doesn't support &&)
./leanwin.sh "cd C:\myproject ; cargo build"

# Or use the SSH config alias (requires `Host leanwin` in ~/.ssh/config):
ssh leanwin "cargo build --release"
```

Both routes all commands through base64-encoded PowerShell to avoid DefaultShell parsing issues.
