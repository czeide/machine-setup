# Czeide's machine setup

[![Verify Checksum](https://github.com/czeide/machine-setup/actions/workflows/verify.yml/badge.svg)](https://github.com/czeide/machine-setup/actions/workflows/verify.yml)

> Warning: Do not use this script unless you trust me or know how it works. Use at your own risk!

This script installs the necessary tools that I usually use for my developer work.

It works on the following operating systems:

- Debian / Ubuntu

The following are installed:

- [curl](https://curl.se/)
- [tmux](https://github.com/tmux/tmux/wiki)
- [htop](https://github.com/htop-dev/htop)
- [git](https://git-scm.com/)
- [gnupg](https://www.gnupg.org/index.html)
- [pass](https://www.passwordstore.org/)
- [Neovim](https://neovim.io/)

## Quick Setup

```bash
curl -s https://raw.githubusercontent.com/czeide/machine-setup/main/install.sh -o /tmp/install.sh && \
curl -s https://raw.githubusercontent.com/czeide/machine-setup/main/install.sh.sha256 -o /tmp/install.sh.sha256 && \
if [ "$(cat /tmp/install.sh.sha256 | cut -d ' ' -f 1)" != "$(sha256sum /tmp/install.sh | cut -d ' ' -f 1)" ]; then \
    echo "Script checksums do not match! Aborting..." && \
    exit 1; \
fi && \
sudo bash /tmp/install.sh
```

