# BGP Professional Lab 1 – govNet Mini-ISP

This lab turns a 10‑router topology into a mini service provider called **govNet**. You build a realistic Internet edge, multi‑AS core, and controlled connectivity to an external customer.

## Big picture

- **AS 999** – Public ISP with many IPv4/IPv6 prefixes (Loopback0–19).
- **AS 1 (R1)** – govNet Internet edge, speaking BGP to ISP and to internal ASes.
- **AS 23 (R2, R3)** – Regional core with iBGP and OSPF.
- **Confed AS 4567 (R4–R7)** – Large regional network split into sub‑AS 45 and 67.
- **R8** – Simple transit router between R5 and R9 (no BGP).
- **R9** – External customer with a 4‑byte ASN, reached via a GRE tunnel and eBGP.

You start from basic interface/loopback configs and layer on OSPF, BGP, tunneling, IPv6, and advanced policy.

## What this lab simulates

- A government or enterprise backbone (govNet) connecting to a Tier‑1 provider.
- Multiple internal regions run as separate ASes / confed sub‑ASes but act as one network.
- A remote customer (R9) with nontrivial requirements (tunnel + 4‑byte ASN).
- Real‑world concerns: selective route propagation, IPv6 rollout, redundancy, and stability.

## Core technologies

- **BGP**: iBGP, eBGP, confederations, 4‑byte ASN, multipath.
- **IGP**: OSPF carrying loopbacks and internal links.
- **Tunneling**: GRE between R5 and R9 over a non‑BGP transit router.
- **IPv6**: Dual‑stack edge to ISP, IPv6 over existing IPv4 BGP sessions into AS 23.
- **Traffic Engineering**:
  - Weight, local‑pref, MED, AS‑path prepending.
  - Route summarization on the ISP side.
- **Policy & Security**:
  - BGP communities: `no-advertise`, `no-export`, and custom communities.
  - Prefix‑lists and route‑maps for filtering and tagging.
  - Transit‑AS blocking and route dampening.

## Why it’s useful

By finishing this lab you practice how to:

- Design and configure a **realistic ISP/customer edge**, not just a single eBGP peering.
- Use **communities and attributes** to decide who sees which prefixes and over which path.
- Bring up **IPv6 alongside IPv4** without redesigning the network.
- Write **production-style configs** with peer‑groups, next‑hop‑self, and modular policy blocks.
- Debug BGP with `show ip bgp`, `show bgp ipv6`, `show ip bgp neighbors`, and understand what you’re seeing.

If you can explain each router’s role and every major policy knob in your configs, you’ve basically turned this lab into a small, realistic ISP design in your head.