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

## Installation

`quick_live_iperf` assumes **iperf3** is installed on both the **testing net** host (client) and the **target net** host (server). [web:172][web:209]

### Install iperf3 on Linux

On most modern Linux distros iperf3 is in the default repos: [web:172][web:211]

```bash
# Debian / Ubuntu / Mint
sudo apt update
sudo apt install iperf3

# RHEL / CentOS / Rocky / AlmaLinux
sudo yum install iperf3        # or:
sudo dnf install iperf3

# Fedora
sudo dnf install iperf3

# Arch Linux
sudo pacman -S iperf3

# openSUSE
sudo zypper install iperf3
```

### Install iperf3 on macOS

On macOS, use Homebrew or MacPorts: [web:208][web:212]

```bash
# Homebrew
brew install iperf3

# MacPorts
sudo port install iperf3
```

### Install iperf3 on Windows

On Windows, download prebuilt binaries from the official iperf site: [web:208]

1. Go to: https://iperf.fr/iperf-download.php  
2. Download the latest **iperf3 Windows binary** (64‑bit recommended).  
3. Extract the archive and either:
   - Run `iperf3.exe` from that folder, or
   - Add the folder to your `PATH` so `iperf3` is available in any CMD/PowerShell window.

> Note: `quick_live_iperf.sh` itself is a Bash script, so you’ll typically run it on a Linux/macOS client. The Windows side can act as the iperf3 **server** or **client** as long as the port and firewall are configured.

---

## Setup: Target net (iperf3 server)

On the **target** host (server side):

1. **Install iperf3** using the commands above for your OS. [web:172][web:211]

2. **Start iperf3 server**

   Default port 5201:

   ```bash
   iperf3 -s
   ```

   Custom port (example: 9000):

   ```bash
   iperf3 -s -p 9000
   ```

3. **Open firewall / NAT for the iperf3 port**

   Examples for port 5201 (adjust if you use a different port): [web:22][web:174]

   ```bash
   # ufw (Ubuntu)
   sudo ufw allow 5201/tcp
   sudo ufw allow 5201/udp

   # firewalld (RHEL/Fedora)
   sudo firewall-cmd --add-port=5201/tcp --permanent
   sudo firewall-cmd --add-port=5201/udp --permanent
   sudo firewall-cmd --reload
   ```

   On home/edge routers, add a **port‑forward** for TCP/UDP 5201 (or your chosen port) to the target host if testing across NAT.

4. (Optional) **Run iperf3 server at boot** on Linux [web:213]

   Create a systemd unit:

   ```ini
   [Unit]
   Description=iperf3 server
   After=network.target

   [Service]
   ExecStart=/usr/bin/iperf3 -s
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

   Then enable it:

   ```bash
   sudo systemctl enable --now iperf3
   ```

---

## Setup: Testing net (client with quick_live_iperf)

On the **testing net** host (where you run the script):

1. **Install iperf3** (same commands as above for your OS). [web:172][web:211]

2. **Download the script**

   Save `quick_live_iperf.sh` into your repo or a tools directory and make it executable:

   ```bash
   chmod +x quick_live_iperf.sh
   ```

3. **Run tests**

   ```bash
   ./quick_live_iperf.sh
   Enter target IP or hostname (target net): 10.0.0.45
   Enter iperf3 port :
   ```

   - Enter the **LAN or public IP** of the iperf3 server.  
   - Enter the port used by the server (or press Enter for default 5201).  
   - The script will:
     - Ping the target to check reachability.
     - Run TCP up/down and UDP tests.
     - Print compact summaries and a final table.

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
