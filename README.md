# IPv6-on-OpenWrt
Set up IPv6 on OpenWrt behind a cable modem/router -> NAT6

Here's the documentation how to set up NAT6 or IPv6 NAT on OpenWrt Chaos Calmer:

Prerequesites: This guide assumes that you already have a working IPv6 WAN connection on your OpenWrt router and you want to allow your client devices to use this connection via NAT6.

1) Install the package `kmod-ipt-nat6` either via the LuCI interface under `System` -> `Software` or via ssh with the command

```
opkg update && opkg install kmod-ipt-nat6
```

2) In the LuCI webinterface go to `Network` -> `Interface`. Change the first letter of the `IPv6 ULA Prefix` from `f` to `d`.
Explanation: If you do not do this, IPv6 NAT may still work on some clients, but others will prefer the IPv4 route instead because the default prefix (starting with something like fd25...) does not indicate a globally routed address. Changing this to a global IPv6 address solves this - just make sure it's an address that is not being used yet (addresses starting with d... are unassigned and therefore safe to use).


3) On the same page, move up to the `LAN` section and click on `Edit`. There you scoll down to `DHPC Server` and hit the tab `IPv6 Settings`. Then check the box `Always announce default router`✅
.


4) Make sure that the following values are set (should be by default): `Router Advertisement-Service` and `DHCPv6-Service` should both be set to `server mode`, `NDP-Proxy` to `disabled` and `DHCPv6-Mode` to `stateless + stateful`.
Note: The original blog post on which this guide is based on recommends to disable the DHCPv6-Service. But my testing showed that with DHCPv6 disabled, some clients would still prefer IPv4 even though IPv6 worked as well (e.g. my Android smartphone showed this behaviour). Enabling DHCPv6 solved this.


5) Last but not least, you need a small script to add the actuall IPv6 NAT rule to the firewall and set the default route/gateway. Via ssh create a new file `/root/nat6.sh` with the following content (using your favorite editor like vi, nano, etc.):
```
#/bin/ash

# Wait until IPv6 route is up...
line=0
while [ $line -eq 0 ]
do
        sleep 5
        line=`route -A inet6 | grep ::/0 | awk 'END{print NR}'`
done

# Add masquerading rule (NAT6) to the firewall
ip6tables -t nat -I POSTROUTING -s `uci get network.globals.ula_prefix` -j MASQUERADE

# Set default gateway for requests to global addresses
route -A inet6 add 2000::/3 `route -A inet6 | grep ::/0 | awk 'NR==1{print "gw "$2" dev "$7}'`

# Set accept_ra to 2, otherwise temporary addresses won't work
echo 2 > /proc/sys/net/ipv6/conf/`route -A inet6 | grep ::/0 | awk 'NR==1{print $7}'`/accept_ra

# Use temporary addresses (IPv6 privacy extensions)
echo 2 > /proc/sys/net/ipv6/conf/`route -A inet6 | grep ::/0 | awk 'NR==1{print $7}'`/use_tempaddr
```

Note: If you do not want or cannot use IPv6 privacy extensions on your OpenWrt router, you can remove the last 5 lines (starting from "# Set accept_ra to 2...") from this script. Then your IPv6 suffix or interface identifier will be static.

6) Make the script executable by issuing the following command via ssh:
```
chmod +x /root/nat6.sh
```

7) Make the script being executed whenever your router boots. To do this, add the folloing line to `/etc/rc.local` before the last line that contains 'exit 0':
```
/root/nat6.sh &
```
You can do this either via ssh using your preferred editor or via LuCI under `System` -> `Startup` -> `Local Startup`

8) Restart your router and verify IPv6 is working on your clients.

