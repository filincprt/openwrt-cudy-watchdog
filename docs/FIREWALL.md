# Firewall snapshot (read-only audit)

Observed on OpenWrt 25.12.6 on 2026-10-22. This is an observational summary, not a complete firewall export.

## Zones and defaults

- Defaults: `input='REJECT'`, `output='ACCEPT'`, `forward='REJECT'`.
- LAN zone: network `lan`; input/output/forward all `ACCEPT`.
- WAN zone: networks `wan`, `wan6`; input `REJECT`, output `ACCEPT`, forward `REJECT`; masquerading enabled; `mtu_fix='1'`.
- Forwarding: `lan -> wan`.
- `fw4 print` returned successfully. `nft list ruleset` showed inet fw4 input/forward default policy drop.
- No custom redirect/port-forward UCI sections were found in the queried output at the time.
- Standard inbound rules observed include DHCP/IPv6 ICMP, ping, IGMP/MLD and IPSec-related ESP/UDP 500 rules. Do not remove rules blindly.

## Listener observations

- Dropbear SSH port 22 bound to wildcard IPv4 and IPv6 addresses.
- uhttpd LuCI HTTP 80 and HTTPS 443 bound to wildcard addresses; `redirect_https='0'`.
- DNS/dnsmasq binds to LAN/WAN addresses as part of the current setup. PassWall2 interception rules had active counters.
- A listening wildcard socket does not by itself prove WAN exposure; firewall and upstream router behavior matter.

## WAN topology

- WAN IPv4: `192.168.1.164/24`, gateway `192.168.1.1`.
- Router LAN: `192.168.50.1`.
- Likely upstream router/double NAT. No WAN IPv6 address or IPv6 default route was observed at the time.
- No port forwarding or DMZ was identified on the upstream router in this audit; upstream configuration was not exhaustively inspected.

## SSH key setup

- Windows key fingerprint reported: `SHA256:jDEprib9nD4I4w0cKSxMryYxlSR9sXCN1/0j4PchsjE` (public fingerprint only).
- Key was ultimately accepted. SSH debug log explicitly showed `Authenticated ... using "publickey"`.
- Router key file: `/etc/dropbear/authorized_keys`; file was set to root-owned mode 600. `/root/.ssh/authorized_keys` was also created and normalized.
- The user later restored access through LuCI after trouble while toggling password authentication. Do **not** assume password authentication is currently disabled. Check `uci show dropbear` before changing it.
- Keep SSH password login enabled until key-only access has been confirmed in a second independent session; keep an existing session open during auth changes.

## Safe follow-up commands

```sh
/etc/init.d/firewall status
fw4 print >/dev/null && echo 'fw4: OK'
uci show firewall
ubus call network.interface.wan status
ubus call network.interface.wan6 status
ip route show default
ip -6 route show default
uci show dropbear
```
