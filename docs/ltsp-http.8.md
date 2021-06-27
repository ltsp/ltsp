## NAME
**ltsp http** - configure nginx or apache for LTSP

## SYNOPSIS
**ltsp** [_ltsp-options_] **http** [**I** _http-index_] [**i** _http-images_] [**t** _http-tftp_]

## DESCRIPTION
Install /etc/nginx/conf.d/ltsp.conf in order to export /srv/ltsp/images ($BASE_DIR/images)
and /srv/tftp/ltsp ($TFTP_DIR).

## OPTIONS
See the **ltsp(8)** man page for _ltsp-options_.

**-I**, **--http-index**[=_0|1_]
: Enable directory listing. Defaults to 0.

**-i**, **--http-images**[=_0|1_]
: Export /srv/ltsp/images over HTTP. Defaults to 1.
To specify a different directory, set $BASE_DIR in /etc/ltsp/ltsp.conf.

**-t**, **--http-tftp**[=_0|1_]
: Export /srv/tftp/ltsp over HTTP. Defaults to 1.
To specify a different directory, set $TFTP_DIR in /etc/ltsp/ltsp.conf.

## EXAMPLES
Create a default nginx or apache configuration, overwriting the old one,
enable directory listing:

```shell
ltsp http -I
```
