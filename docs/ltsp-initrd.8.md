## NAME
**ltsp initrd** - create the ltsp.img initrd add-on

## SYNOPSIS
**ltsp** [_ltsp-options_] **initrd**

## DESCRIPTION
Create a secondary initrd in /srv/tftp/ltsp/ltsp.img, that contains the LTSP
client code from /usr/share/ltsp/{client,common} and everything under
/etc/ltsp, including the ltsp.conf settings file. LTSP clients receive this
initrd in addition to their usual one.

This means that whenever you edit **ltsp.conf(5)**, you need to run
`ltsp initrd` to update **ltsp.img**, and reboot the clients.

It also means that you can very easily put template xorg.conf or sshfs
or other files in /etc/ltsp, and have them on the clients in seconds,
without having to run `ltsp image`.

## OPTIONS
See the **ltsp(8)** man page for _ltsp-options_.

## EXAMPLES
Most live CDs do not contain sshfs, so by default you can only use NFS
home with them. But sshfs is a small binary without many dependencies,
so you may usually provide it to the clients if you include it to ltsp.img:

```shell
cp /usr/bin/sshfs /etc/ltsp/sshfs-$(uname -m)
ltsp initrd
```

You can even provide multiple sshfs versions for different architectures.
LTSP contains code to automatically use those sshfs binaries if it can't
find the /usr/bin/sshfs one.
