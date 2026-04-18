# IPERF3 Tester

Small bash wrapper around `iperf3` for fast, **human‑readable** connectivity checks between a *testing net* and a *target net*.

It runs a short suite of TCP and UDP tests, shows a live spinner while each test runs, and prints compact labeled summaries plus a final table.

---

## Features

- Prompts for **target IP/hostname** and **iperf3 port** (default: 5201).
- Runs a quick suite (configurable duration, default 10 s):  
  - `TCP_UP`   – testing net → target net  
  - `TCP_DOWN` – target net → testing net (`-R` reverse mode)  
  - `UDP_500M` – UDP at 500 Mbit/s testing net → target net  
  - `UDP_800M` – UDP at 800 Mbit/s testing net → target net
- Shows a **spinner** while each test runs so the terminal doesn’t look “stuck”.
- Prints **compact** end‑of‑test summaries including:
  - Direction (testing net IP → target net IP:port)
  - TCP **Retransmissions** count
  - UDP **Loss%**
- Outputs a final **summary table** that’s screenshot‑/ticket‑friendly.

---

## Requirements

### Both sides (testing net & target net)

- Linux/Unix shell with:
  - `bash`
  - `iperf3`
  - `ping`
  - `timeout`
  - `awk`, `grep`, `tail`
- Basic IP connectivity between testing net and target net.

### Target net (iperf3 server)

On the **target** host:

1. Install `iperf3`:

   ```bash
   # Ubuntu / Debian
   sudo apt update
   sudo apt install iperf3

   # RHEL / CentOS / Fedora
   sudo dnf install iperf3
   ```

2. Start iperf3 server (default port 5201):

   ```bash
   iperf3 -s
   ```

   To use a custom port (example: 9000):

   ```bash
   iperf3 -s -p 9000
   ```

3. Open firewall and/or NAT for the iperf3 port:

   ```bash
   # ufw example (5201)
   sudo ufw allow 5201/tcp
   sudo ufw allow 5201/udp

   # firewalld example (5201)
   sudo firewall-cmd --add-port=5201/tcp --permanent
   sudo firewall-cmd --add-port=5201/udp --permanent
   sudo firewall-cmd --reload
   ```

   If you use a different port, adjust the rules accordingly.

You can also run iperf3 as a service or daemon if you want a permanent test endpoint.

---

## Installation (testing net)

On the **testing net** host (the client that will run the script):

1. Install `iperf3` and dependencies if needed:

   ```bash
   sudo apt install iperf3
   ```

2. Download or copy `quick_live_iperf.sh` into a directory in your `$PATH` or any working directory:

   ```bash
   chmod +x quick_live_iperf.sh
   ```

---

## Usage

### Basic usage (default port 5201)

From the testing net host:

```bash
./quick_live_iperf.sh
Enter target IP or hostname (target net): 10.0.0.45
Enter iperf3 port :
```

- Press **Enter** at the port prompt to use the default 5201.
- The script will:
  - Ping the target to verify reachability.
  - Detect the testing net IP used to reach the target.
  - Run TCP and UDP tests.
  - Print end‑of‑test summaries and a final table.

Example output (simplified):

```text
=== quick_live_iperf: testing net -> target net ===
Testing net (client): 10.0.0.205
Target net (server): 10.0.0.45:5201
(Each test 10s, compact summary only)

>>> TCP_UP
Running TCP_UP (10s) done

[SUM]   0.00-10.00  sec  1.10 GBytes   948 Mbits/sec    0             sender
[SUM]   0.00-10.00  sec  1.10 GBytes   942 Mbits/sec                  receiver
>>> TCP_UP summary: TESTING_NET(10.0.0.205) -> TARGET_NET(10.0.0.45:5201) = 948 Mbits/sec, Retransmissions=0

...

=== SUMMARY TABLE ===
Test         Direction                                Result
------------ ---------------------------------------- ------------------------------
TCP_UP       TESTING_NET(10.0.0.205) -> TARGET_NET(10.0.0.45:5201) 948 Mbits/sec Retransmissions=0
TCP_DOWN     TESTING_NET(10.0.0.205) -> TARGET_NET(10.0.0.45:5201) 943 Mbits/sec Retransmissions=0
UDP_500M     TESTING_NET(10.0.0.205) -> TARGET_NET(10.0.0.45:5201) 498 Mbits/sec Loss=0%
UDP_800M     TESTING_NET(10.0.0.205) -> TARGET_NET(10.0.0.45:5201) 800 Mbits/sec Loss=0%

=== DONE ===
```

### Using a custom iperf3 port

If the iperf3 server is listening on a **non‑default** port (e.g. `iperf3 -s -p 9000`):

```bash
./quick_live_iperf.sh
Enter target IP or hostname (target net): 173.33.25.179
Enter iperf3 port : 9000
```

The script will automatically pass `-p 9000` to all iperf3 client calls.

---

## Parameters

You can also control some behavior with environment variables:

- `DURATION` – seconds per test (default `10`)  
- `PARALLEL` – number of parallel TCP streams (default `4`)  
- `UDP_RATES` – space‑separated UDP target rates (default `"500M 800M"`)

Examples:

```bash
# Short, light test at a single UDP rate
DURATION=5 UDP_RATES="500M" ./quick_live_iperf.sh 10.0.0.45

# Heavier TCP test with more streams
PARALLEL=8 ./quick_live_iperf.sh 10.0.0.45
```

---

## Interpreting results

- **TCP_up / TCP_down bandwidth**  
  - Values close to the link rate with **low Retransmissions** indicate a clean path.
- **Retransmissions**  
  - `0` on a short LAN test is ideal.  
  - Small non‑zero values can be acceptable over WAN; large counts over a short test hint at loss or congestion.
- **UDP Loss%**  
  - `0%` is ideal; increasing loss as you raise `UDP_RATES` shows where queues or shaping start dropping packets.
- **Jitter** (from iperf3 output)  
  - Relevant for real‑time traffic like video/VoIP; lower is better.

---

## Notes

- This script is designed for **operators and homelabbers** who want a quick, readable sanity check rather than raw iperf3 noise.
- It assumes you control both ends (testing net and target net) and can install/enable iperf3 server on the target.

Feel free to fork and adapt it to your own lab (extra UDP profiles for multiple feeds, JSON logging, Grafana integration, etc.).
