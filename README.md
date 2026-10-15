# rFabric installers

The install scripts served at <https://get.rfabric.io> by GitHub Pages.

```bash
curl -fsSL https://get.rfabric.io/cli.sh | sh      # rFabric CLI (rfabric)
curl -fsSL https://get.rfabric.io/agent.sh | sh    # rFabric robot agent (rfabric-agent)
```

- Linux with apt-get or dnf: the script adds the rFabric package repository <https://linux.rfabric.io> and installs the package; `apt-get upgrade` / `dnf upgrade` keep it current.
- Any other system, or with `RFABRIC_VERSION` or `RFABRIC_INSTALL_DIR` set: the script installs the binary from the GitHub Release into `RFABRIC_INSTALL_DIR` (default `/usr/local/bin`).
- Release candidates: `curl -fsSL https://get.rfabric.io/cli.sh | RFABRIC_CHANNEL=rc sh`.

## How it is published

`cli.sh` and `agent.sh` are rendered from the one template `install.sh` by `render.sh`; `.github/workflows/publish.yml` renders and deploys on every push to `main`. Edit `install.sh`, never the rendered files.
