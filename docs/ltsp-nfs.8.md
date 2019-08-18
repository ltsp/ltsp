## NAME
**ltsp nfs** - configure NFS exports for LTSP

## SYNOPSIS
**ltsp** [_ltsp-options_] **nfs** [**-h** _nfs-home_] [**t** _nfs-tftp_]

## DESCRIPTION
Install /etc/exports.d/ltsp-nfs.conf in order to export /srv/ltsp ($BASE_DIR),
/srv/tftp/ltsp ($TFTP_DIR) and optionally /home ($HOME_DIR).

## OPTIONS
See the **ltsp(8)** man page for _ltsp-options_.

**-h**, **--nfs-home=**_0|1_
: Export /home over NFS3. Defaults to 0.
Note that NFS3 is insecure for home, so by default SSHFS is used.
To specify a different directory, set $HOME_DIR in /etc/ltsp/ltsp.conf.

**-t**, **--nfs-tftp=**_0|1_
: Export /srv/tftp/ltsp over NFS3. Defaults to 1.
To specify a different directory, set $TFTP_DIR in /etc/ltsp/ltsp.conf.

## EXAMPLES
To export only some user homes over NFS3 (insecure) while the rest still
use SSHFS, use symlinks as described below. Note that the NFS server doesn't
follow symlinks outside of an export. Start by putting this line in
/etc/ltsp/ltsp.conf under the [clients] section:

```shell
FSTAB_NFS="server:/home/nfs /home nfs 0 0"
```

Then run the following commands:

```shell
ltsp initrd  # This is needed whenever ltsp.conf is modified

mkdir /home/nfs
for u in guest01 guest02; do
    mv "/home/$u" /home/nfs/
    ln -s "nfs/$u" "/home/$u"
done

ltsp --home-dir=/home/nfs nfs --export-home=1
```
