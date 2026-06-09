# VMware Net Lab – VyOS Segmentation & Internal Routing

This lab builds a segmented on‑prem VMware environment with **VyOS** open‑source routers, routed internal networks, a management desktop, and multiple role‑based VMs. The focus is VLAN trunking, inter‑VLAN routing, persistent management access, and troubleshooting routing issues inside a virtual lab.

---

## Big picture

- Ubuntu desktop is the main **management** and **attack** workstation.
- `rtr1` and `rtr2` are **VyOS** routers providing internal routing between isolated lab networks.
- Internal segments represent different roles instead of a single flat LAN.
- VMware virtual networking carries all the lab VLANs and connects routers to VMs.
- End state: the desktop keeps normal internet via DHCP and can also reach all lab subnets through a single static route.

---

## What this lab simulates

- A small enterprise network with separate:
  - Management, server, security, and attacker zones.
- Router‑on‑a‑stick / inter‑VLAN routing inside a virtual environment.
- A management workstation **outside** the routed segments that still needs controlled access into the lab.
- Real troubleshooting around:
  - Trunks, VLAN tags, default gateways, static routes, and persistent Linux config.

---

## Core technologies

- VMware vSwitch / port groups for internal connectivity.
- VyOS open‑source virtual routers (`rtr1`, `rtr2`).
- VLAN segmentation and trunk delivery to a routing device.
- Inter‑VLAN routing on VyOS.
- Ubuntu Netplan for persistent static routes.
- Linux tools: `ip route`, `ip a`, `ping`, `ssh`, `traceroute`.

---

## Lab networks

| Role        | Subnet           | Example host |
|------------|------------------|--------------|
| Management | 10.10.10.0/24    | 10.10.10.10  |
| Server     | 10.10.20.0/24    | 10.10.20.10  |
| Security   | 10.10.30.0/24    | 10.10.30.10  |
| Attacker   | 10.10.40.0/24    | 10.10.40.10  |

---

## Topology (high level)

```text
Ubuntu Desktop
      |
      | static route: 10.10.0.0/16 via 10.0.0.50
      |
    rtr1 (VyOS)
      |
    rtr2 (VyOS)
      |
+------+------+--------+--------+
| mgmt | server | security | attacker |
|10.10.10|10.10.20|10.10.30|10.10.40|
+--------+--------+---------+--------+
```

---

## Installation & build steps

### 1. Create the VMs

Create these VMs in VMware:

- Ubuntu Desktop (management / attacker box)
- `rtr1` (VyOS)
- `rtr2` (VyOS)
- Management VM
- Server VM
- Security VM
- Attacker VM

Attach NICs so:

- `rtr1` / `rtr2` see all required internal networks (or a VLAN trunk).
- Each endpoint VM sits in the correct subnet (mgmt, server, security, attacker).

---

### 2. Install VyOS on `rtr1` and `rtr2`

1. Create the router VM and mount the VyOS ISO.
2. Boot into the VyOS live environment.
3. At the console run:

```bash
install image
```

Follow the prompts (auto partition, select disk, set `vyos` password, install bootloader), then:

4. Detach the ISO.
5. Reboot the VM so it boots from the installed image.

Repeat for both `rtr1` and `rtr2`.

---

### 3. Basic VyOS configuration

VyOS uses a commit‑style workflow:

```bash
configure
set system host-name rtr1
commit
save
exit
```

Example interface config on a router:

```bash
configure
set interfaces ethernet eth0 address '10.0.0.50/24'
set interfaces ethernet eth0 description 'Desktop side'
set interfaces ethernet eth1 address '10.10.10.1/24'
set interfaces ethernet eth1 description 'Management subnet'
set interfaces ethernet eth2 address '10.10.20.1/24'
set interfaces ethernet eth2 description 'Server subnet'
# add more interfaces/subnets as needed
commit
save
exit
```

Useful VyOS show commands:

```bash
show interfaces
show ip route
show configuration commands
```

---

### 4. Base Ubuntu setup (desktop + VMs)

On each Ubuntu system:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y net-tools iproute2 openssh-server curl wget vim traceroute
```

Verify interfaces and routing:

```bash
ip a
ip route
nmcli device status   # on desktop for NetworkManager
```

---

### 5. Temporary static route on desktop

Prove reachability from the desktop into the lab:

```bash
sudo ip route add 10.10.0.0/16 via 10.0.0.50
ip route | grep 10.10.0.0

ping -c3 10.10.10.10
ping -c3 10.10.20.10
ping -c3 10.10.30.10
ping -c3 10.10.40.10
```

This works until reboot; next step makes it permanent.

---

### 6. Make the route persistent with Netplan

Check existing Netplan files:

```bash
sudo cat /etc/netplan/01-network-manager-all.yaml
sudo cat /etc/netplan/50-cloud-init.yaml
```

Edit the file that defines your desktop NIC (example `enp7s0`):

```yaml
network:
  version: 2
  ethernets:
    enp7s0:
      dhcp4: true
      routes:
        - to: 10.10.0.0/16
          via: 10.0.0.50
```

Apply and verify:

```bash
sudo netplan apply
ip route | grep 10.10.0.0
```

Expected:

```text
10.10.0.0/16 via 10.0.0.50 dev enp7s0 proto static metric 100
```

If you see a permissions warning for a Netplan file:

```bash
sudo chmod 600 /etc/netplan/01-network-manager-all.yaml
sudo netplan apply
```

---

## Internal routing concept

For inter‑VLAN routing to work:

- `rtr1` / `rtr2` have an interface (or sub‑interface) in **each** subnet.
- Every VM uses its local VyOS router IP as the **default gateway**.
- The VMware side actually carries the VLANs (or separate port groups) to the routers.
- The desktop knows that `10.10.0.0/16` is reachable via `10.0.0.50`.

Common validation commands (on routers / Linux VMs):

```bash
ip a
ip route
ping -c3 <gateway-ip>
ping -c3 <remote-subnet-host>
sysctl net.ipv4.ip_forward
```

---

## Issues you hit and how you fixed them

### 1. VyOS not installed to disk (live‑only)

**Symptoms**

- Router booted but long‑term persistence was uncertain.

**Fix**

- Ran `install image` on both routers and rebooted from the installed disk.

---

### 2. VLAN / trunk path issues

**Symptoms**

- Some VMs could not reach their gateway.
- Segments felt isolated even with “correct” IPs.

**Fix**

- Checked VMware vSwitch / port groups to ensure the router‑facing NICs carried all required VLANs.
- Verified each VM was on the right internal network.

---

### 3. Wrong default gateways on VMs

**Symptoms**

- VMs could ping local hosts but not other VLANs.
- Router self‑pings looked fine; host‑to‑host failed.

**Fix**

- Set each VM’s default gateway to the router IP in its subnet (for example, 10.10.20.1 for the server VLAN).
- Re‑tested from the VMs, not only from routers.

---

### 4. Desktop could not reach lab networks

**Symptoms**

- Desktop had internet but no access to 10.10.x.x.
- Internal devices talked to each other fine.

**Fix**

- Added `10.10.0.0/16 via 10.0.0.50` on the desktop.
- Made it persistent with Netplan so it survives reboot.

---

### 5. Netplan warnings

**Symptoms**

- `sudo netplan apply` complained about file permissions, even though the route worked.

**Fix**

```bash
sudo chmod 600 /etc/netplan/01-network-manager-all.yaml
sudo netplan apply
```

---

## Command cheat‑sheet

```bash
# VyOS (on rtr1 / rtr2)
install image
configure
set system host-name rtr1
set interfaces ethernet eth0 address '10.0.0.50/24'
set interfaces ethernet eth1 address '10.10.10.1/24'
set interfaces ethernet eth2 address '10.10.20.1/24'
commit
save
show interfaces
show ip route
show configuration commands
exit

# Base Ubuntu packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y net-tools iproute2 openssh-server curl wget vim traceroute

# Inspect
ip a
ip route
nmcli device status

# Desktop route (test)
sudo ip route add 10.10.0.0/16 via 10.0.0.50

# Netplan
sudo cat /etc/netplan/01-network-manager-all.yaml
sudo cat /etc/netplan/50-cloud-init.yaml
sudo netplan apply
sudo chmod 600 /etc/netplan/01-network-manager-all.yaml

# Connectivity tests
ping -c3 10.10.10.10
ping -c3 10.10.20.10
ping -c3 10.10.30.10
ping -c3 10.10.40.10
ssh <user>@10.10.20.10
```

---

## Status

- [x] VMware VMs created
- [x] VyOS installed and saving config
- [x] Internal routing between lab VLANs working
- [x] Desktop internet via DHCP
- [x] Desktop route to 10.10.0.0/16 via 10.0.0.50
- [ ] (Optional) Document per‑VM gateway IPs
- [ ] (Optional) Add diagrams / screenshots
