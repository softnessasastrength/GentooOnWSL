# Troubleshooting — Gentoo on WSL2

Rescue and recovery notes for `install_gentoo_resilient.bat`. Every entry below
corresponds to a check, failure path, or rescue hint that the script itself
contains — nothing here invents procedure the script doesn't already have.

The script's configuration lives at the top of the file:

| Variable   | Default                                                              |
|------------|----------------------------------------------------------------------|
| `DISTRO`   | `Gentoo`                                                             |
| `BASE`     | `E:\Distros\Gentoo`                                                  |
| `ROOTFS`   | `C:\Users\Branden\Downloads\stage3-amd64-openrc-20250907T165007Z.tar.xz` |
| `USERNAME` | `branden`                                                            |

Most "wrong path / wrong name" failures are fixed by editing these four lines.

## The universal rescue shell

Almost every recovery below starts the same way — force a root shell, which
works because the script does not change the default user until *after* user
creation succeeds:

```bat
wsl -d Gentoo -u root -- bash -l
```

## Installer stops immediately

### `[!] WSL not found.`
The script's first check (`where wsl`) failed. Enable **Windows Subsystem for
Linux** and **Virtual Machine Platform**, then reboot, exactly as the message
says. The script exits with code 1 and changes nothing.

### `[!] Missing tarball: "..."`
The file at `ROOTFS` does not exist. Point `ROOTFS` at your actual stage3
tarball (the default is a dated OpenRC stage3 filename, so a newer download
will not match it) and retry.

### `[!] Import failed. Aborting.`
`wsl --import` returned an error. Note the order of operations: the script has
already unregistered any previous `Gentoo` distro by this point (see below),
so a failed import leaves no distro registered. Fix the cause — tarball
readable, `BASE` path creatable — and re-run.

## Re-running the script wipes the existing distro

Before importing, the script runs `wsl --unregister Gentoo` so the import
starts clean. That deletes the existing distro and its filesystem. The script's
own comment gives the opt-out: comment out the unregister lines to keep an
existing distro — but then the import step will collide with it instead. Treat
every re-run as a fresh install.

## Configuration failures

### `[!] Failed to write wsl.conf/resolv.conf.`
The base-config step failed after import. At this point `/etc/wsl.conf` still
has (or was intended to have) `default=root`, so rescue with the root shell
above and inspect `/etc/wsl.conf` and `/etc/resolv.conf` by hand.

### `[!] User creation failed. Keeping default=root so you can rescue.`
This is by design: the script refuses to set a default user that doesn't
exist. It prints the full manual procedure, which is:

```bat
wsl -d Gentoo -u root -- bash -l
```

then inside Gentoo:

```sh
useradd -m -G wheel -s /bin/bash branden
passwd && passwd branden
sed -i 's/^default=.*/default=branden/' /etc/wsl.conf
```

then exit, and from Windows:

```bat
wsl --shutdown
wsl -d Gentoo
```

### `sudo` is missing after install
The sudo step is explicitly **best-effort** in the script: the Portage snapshot
(`emerge-webrsync`), `emerge --sync`, and the sudo install itself all run with
failures tolerated (`|| true`), so a slow mirror or a sync failure will not
block user creation — and will not be reported as an install failure either.
If `sudo` is absent afterwards, that step did not complete; the commands the
script attempted are the three above, plus uncommenting the `%wheel` line in
`/etc/sudoers` if it is present in commented form.

## After a successful install

### No passwords are set by the script
The script deliberately leaves passwords to you. At the first shell it
instructs:

```sh
passwd            # root
passwd branden    # your user
```

then `exit`, `wsl --shutdown`, and `wsl -d Gentoo` so the default-user change
takes effect.

### Default user change doesn't seem to apply
WSL reads `/etc/wsl.conf` at distro start. The script runs `wsl --shutdown`
at the end for exactly this reason; if you edit `wsl.conf` by hand, shut WSL
down before relaunching or the old default keeps applying.

### Verify the install
The script's own end-of-run checks:

```sh
whoami
cat /etc/os-release
```

### DNS behaves differently than stock WSL
By design, not a bug: the script writes `[network] generateResolvConf = false`
into `/etc/wsl.conf` and manages `/etc/resolv.conf` itself, pinned to
`1.1.1.1` and `8.8.8.8` with `options edns0 trust-ad`. WSL will not regenerate
that file; if name resolution breaks, `/etc/resolv.conf` is the file to look
at, and its contents came from the script.

## Resetting the default user back to root

The script's closing `[Rescue]` block, for when the distro launches but the
default user is wrong:

```bat
wsl -d Gentoo -u root -- sh -lc "sed -i 's/^default=.*/default=root/' /etc/wsl.conf"
wsl --shutdown
```
