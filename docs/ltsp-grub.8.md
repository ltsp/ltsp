## NAME
**ltsp grub** - install GRUB binaries and configuration in TFTP

## SYNOPSIS
**ltsp** [_ltsp-options_] **grub** [**-b** _binaries_]

## DESCRIPTION
Generate the grub.cfg configuration file and install the required GRUB binaries
in /srv/tftp/ltsp: memtest.0, memtest.efi, snponly.efi and undionly.kpxe.

An ltsp-binaries package is available in the LTSP PPA that provides them;
otherwise, some of them are automatically found in the grub/memtest86+ packages.

## OPTIONS
See the **ltsp(8)** man page for _ltsp-options_.

**-b**, **--binaries=**_[0|1|""]_
: Reinstall the additional binaries in TFTP even if they already exist.
Defaults to "", which means "only install the missing ones".
Note that the --overwrite flag doesn't affect the binaries, they're only
contolled by the --binaries flag.

**-h**, **--http**=_0|1_
: Enable or disable the HTTP method for download kernel and initrd.
The HTTP method is faster and more safe then TFTP however you need
to have configured http-server. See the ltsp-http(8) man page for more details.

**-H**, **--http-image**=_0|1_
: Enable or disable the HTTP method for download rootfs image.
The image will be saved to RAM during the boot. That makes clients less
dependent on the server, but they must have sufficient memory to fit the image.
You need to have configured http-server for using this option.
See the ltsp-http(8) man page for more details.

## EXAMPLES
Initial use:

```shell
ltsp grub
```

Regenerate grub.cfg and reinstall the binaries:

```shell
ltsp grub -b
```

Copy the binaries from a USB stick before running ltsp grub:

```shell
mkdir -p /srv/tftp/ltsp
cd /media/administrator/usb-stick
cp {memtest.0,memtest.efi} /srv/tftp/ltsp
ltsp grub
```
