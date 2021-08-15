## NAME
**ltsp dnsmasq** - configure dnsmasq for LTSP

## SYNOPSIS
**ltsp** [_ltsp-options_] **dnsmasq** [**-d** _dns_] [**-p** _proxy-dhcp_] [**-r** _real-dhcp_] [**-s** _dns-server_] [**-t** _tftp_]

## DESCRIPTION
Install /etc/dnsmasq.d/ltsp-dnsmasq.conf, while adjusting the template with
the provided parameters.

## OPTIONS
See the **ltsp(8)** man page for _ltsp-options_.

**-d**, **--dns=**_0|1_
: Enable or disable the DNS service. Defaults to 0.
Enabling the DNS service of dnsmasq allows caching of client requests,
custom DNS results, blacklisting etc, and automatically disables
DNSStubListener in systemd-resolved on the LTSP server.

**-h**, **--http**=_0|1_
: Enable or disable the HTTP method for download kernel and initrd.
The HTTP method is faster and more safe then TFTP however you need
to have configured http-server. See the ltsp-http(8) man page for more details.

**-p**, **--proxy-dhcp=**_0|1_
: Enable or disable the proxy DHCP service. Defaults to 1.
Proxy DHCP means that the LTSP server sends the boot filename, but it leaves
the IP leasing to an external DHCP server, for example a router or pfsense
or a Windows DHCP server. It's the easiest way to set up LTSP, as it only
requires a single NIC with no static IP, no need to rewire switches etc.

**-r**, **--real-dhcp=**_0|1_
: Enable or disable the real DHCP service. Defaults to 1.
In dual NIC setups, you only need to configure the internal NIC to a static
IP of 192.168.67.1; LTSP will try to autodetect everything else.
The real DHCP service doesn't take effect if your IP isn't 192.168.67.x,
so there's no need to disable it in single NIC setups unless you want to run
isc-dhcp-server on the LTSP server.

**-s**, **--dns-server=**_"space separated list"_
: Set the DNS server DHCP option. Defaults to autodetection.
Proxy DHCP clients don't receive DHCP options, so it's recommended to use the
ltsp.conf DNS_SERVER parameter when autodetection isn't appropriate.

**-t**, **--tftp=**_0|1_
: Enable or disable the TFTP service. Defaults to 1.

## EXAMPLES
Create a default dnsmasq configuration, overwriting the old one:

```shell
ltsp dnsmasq
```

A dual NIC setup with the DNS service enabled:

```shell
ltsp dnsmasq -d1 -p0 --dns-server="0.0.0.0 8.8.8.8 208.67.222.222"
```
