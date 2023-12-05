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