# Home Lab Edge – Cisco 2800 + ASA 5512-X + 2960

This repo documents my home‑lab edge stack built on real Cisco gear:  
Rogers fiber → Cisco 2800 → ASA 5512‑X → Catalyst 2960 → LAN / Wi‑Fi AP / Dell R710.

The goal is a **realistic, routed perimeter** with a separate DMZ, while keeping the config simple enough to paste and lab with.

---

## Topology

```text
          ISP Fiber
              │
        [Cisco 2800]
   G0/1 = WAN (DHCP from ISP)
   G0/0 = LAN handoff (173.32.153.194/23)
              │
              │ 173.32.153.194/23
              │
        [ASA 5512-X]
   G0/0 outside 173.32.153.195/23
   G0/1 inside  10.0.10.1/24
   G0/2 dmz     10.0.20.1/24
              │
              │ 10.0.10.0/24
              │
        [Catalyst 2960]
   VLAN 10 = INSIDE-LAN
   Fa0/1   → ASA inside
   Fa0/3   → Wi‑Fi AP
   Fa0/4–24 → Lab clients
              │
        [Dell R710]
   (either on DMZ via ASA G0/2 or inside via 2960)
```

---

## Cisco 2800 – WAN Edge

Handles ISP handoff and routes a /23 to the ASA.

```cisco
enable
conf t
!
hostname R2800
no ip domain-lookup
!
! WAN toward ISP fiber / ONT
interface GigabitEthernet0/1
 description TO-ISP-FIBER-ONT
 ip address dhcp
 ip nat outside
 no shutdown
!
! LAN handoff to ASA outside
interface GigabitEthernet0/0
 description TO-ASA-OUTSIDE
 ip address 173.32.153.194 255.255.254.0
 no ip nat outside
 no shutdown
!
! Default route via ISP (learned from DHCP)
ip route 0.0.0.0 0.0.0.0 GigabitEthernet0/1 dhcp
!
end
write mem
```

---

## ASA 5512‑X – Firewall, NAT, DMZ

Routed mode ASA with an inside LAN, a DMZ for the R710, and DHCP for the LAN.

```cisco
enable
conf t
!
hostname ciscoasa
no domain-lookup
!
! OUTSIDE to 2800
interface GigabitEthernet0/0
 description TO-R2800-G0/0
 nameif outside
 security-level 0
 ip address 173.32.153.195 255.255.254.0
 no shutdown
!
! INSIDE to 2960 (wired LAN + Wi-Fi AP)
interface GigabitEthernet0/1
 description TO-2960-SWITCH
 nameif inside
 security-level 100
 ip address 10.0.10.1 255.255.255.0
 no shutdown
!
! DMZ to Dell R710
interface GigabitEthernet0/2
 description TO-DELL-R710
 nameif dmz
 security-level 50
 ip address 10.0.20.1 255.255.255.0
 no shutdown
!
! G0/3 not used directly (Wi-Fi AP hangs off 2960)
interface GigabitEthernet0/3
 shutdown
!
! Default route to router
route outside 0.0.0.0 0.0.0.0 173.32.153.194
!
! Objects for NAT
object network INSIDE-NET
 subnet 10.0.10.0 255.255.255.0
 nat (inside,outside) dynamic interface
!
object network DMZ-NET
 subnet 10.0.20.0 255.255.255.0
 nat (dmz,outside) dynamic interface
!
! (Optional) static NAT for Dell web
! object network DELL-WEB
!  host 10.0.20.10
!  nat (dmz,outside) static 173.32.153.196 service tcp 80 80
!
! Access-lists
access-list OUTSIDE_IN extended permit icmp any any
! Add more specific permits to OUTSIDE_IN if you publish services
access-group OUTSIDE_IN in interface outside
!
! Inside: allow all out (explicit)
access-list INSIDE_IN extended permit ip any any
access-group INSIDE_IN in interface inside
!
! DMZ: restrict to SSH/RDP into inside (example)
access-list DMZ_IN extended permit tcp any any eq 22
access-list DMZ_IN extended permit tcp any any eq 3389
access-group DMZ_IN in interface dmz
!
! DHCP for inside (wired + Wi-Fi clients)
dhcpd address 10.0.10.50-10.0.10.200 inside
dhcpd dns 8.8.8.8 1.1.1.1
dhcpd option 3 ip 10.0.10.1
dhcpd enable inside
!
! Basic management from inside net
http server enable
http 10.0.10.0 255.255.255.0 inside
ssh 10.0.10.0 255.255.255.0 inside
username admin password Str0ngPass privilege 15
!
end
write mem
```

---

## Catalyst 2960 – Inside Access Layer

Single inside VLAN with ports for ASA, Wi‑Fi AP, Dell, and clients.

```cisco
enable
conf t
hostname SW2960
no ip domain-lookup
!
vlan 10
 name INSIDE-LAN
!
! Port to ASA inside
interface FastEthernet0/1
 description TO-ASA-G0/1
 switchport mode access
 switchport access vlan 10
 spanning-tree portfast
!
! Port to ISP Wi-Fi router LAN (AP mode)
interface FastEthernet0/3
 description TO-ISP-WIFI-LAN
 switchport mode access
 switchport access vlan 10
 spanning-tree portfast
!
! All other user ports default to VLAN 10
interface range FastEthernet0/4 - 24
 description USER-PORT
 switchport mode access
 switchport access vlan 10
 spanning-tree portfast
!
! Optional: switch mgmt IP on inside net
interface Vlan10
 ip address 10.0.10.2 255.255.255.0
 no shutdown
!
ip default-gateway 10.0.10.1
!
end
write mem
```

---

## Usage Notes

- Plug the ISP handoff into `R2800 G0/1`; it will grab a public IP via DHCP.  
- Dell R710 can live either:
  - On the **DMZ** (ASA G0/2, 10.0.20.0/24) for “internet‑facing server” tests, or  
  - On the **inside** via the 2960 if you uncomment the inside port.  
- Any Wi‑Fi router/AP can be dropped onto `SW2960 Fa0/3` with its LAN in 10.0.10.0/24 and DHCP disabled to extend the inside network over wireless.

Feel free to clone, tweak the prefixes/passwords, and use this as a starting point for your own Cisco home‑lab edge.
