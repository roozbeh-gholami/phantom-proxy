# phantom-proxy - Transport over Raw Packet

[![Go Version](https://img.shields.io/badge/go-1.25+-blue.svg)](https://golang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

`phantom-proxy` is a bidirectional Packet-level proxy built using raw sockets in Go. It forwards traffic from a local client to a remote server, which then connects to target services. By operating at the packet level, it completely bypasses the host operating system's TCP/IP stack and uses KCP for secure, reliable transport.

> **⚠️ Development Status Notice**
>
> This project is in **active development**. APIs, configuration formats, protocol specifications, and command-line interfaces may change without notice. Expect breaking changes between versions. Use with caution in production environments.

This project serves as an example of low-level network programming in Go, demonstrating concepts like:

- Raw packet crafting and injection with `gopacket`.
- Packet capture with `pcap`.
- Custom binary network protocols.
- The security implications of operating below the standard OS firewall.

## Use Cases and Motivation

`phantom-proxy` is designed for specific scenarios where standard VPN or SSH tunnels may be insufficient. Its primary use cases include bypassing firewalls that detect standard handshake protocols by using custom packet structures, network security research for penetration testing and data exfiltration, and evading kernel-level connection tracking for monitoring avoidance.

While `phantom-proxy` includes built-in encryption via KCP, it is more complex to configure than general-purpose VPN solutions.

## How It Works

`phantom-proxy` creates a transport channel using KCP over raw TCP packets, bypassing the OS's TCP/IP stack entirely. It captures packets using pcap and injects crafted TCP packets containing encrypted transport data, allowing it to bypass kernel-level connection tracking and evade firewalls.

```
[Your App] <------> [phantom-proxy Client] <===== Raw TCP Packet =====> [phantom-proxy Server] <------> [Target Server]
(e.g. curl)        (localhost:1080)        (Internet)          (Public IP:PORT)     (e.g. https://httpbin.org)
```

The system operates in three layers: raw TCP packet injection, encrypted transport (KCP), and application-level connection multiplexing.

KCP provides reliable, encrypted communication optimized for high-loss or unpredictable networks, using aggressive retransmission, forward error correction, and symmetric encryption with a shared secret key. It is especially well-suited for real-time applications and gaming where low latency are critical.

## Getting Started

### Quick Installation (Recommended)

The easiest way to install phantom-proxy is using our automated installation scripts.

#### Linux/macOS

```bash
# Download and run the installation script
curl -fsSL https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/install.sh | sudo bash

# Or download first, then run:
wget https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/install.sh
chmod +x install.sh
sudo ./install.sh
```

#### Windows

```powershell
# Download and run as Administrator in PowerShell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/install.ps1" -OutFile "install.ps1"
.\install.ps1

# Or in one line (run PowerShell as Administrator):
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/install.ps1'))
```

The installation script will:
- Detect your OS and architecture automatically
- Install required dependencies (libpcap/Npcap)
- Download the latest phantom-proxy binary
- Install example configuration files
- Add phantom-proxy to your system PATH

### Manual Installation

If you prefer to install manually or the automated script doesn't work for your system:

#### Prerequisites

- `libpcap` development libraries must be installed on both the client and server machines.
  - **Debian/Ubuntu:** `sudo apt-get install libpcap-dev`
  - **RHEL/CentOS/Fedora:** `sudo yum install libpcap-devel`
  - **macOS:** Comes pre-installed with Xcode Command Line Tools. Install with `xcode-select --install`
  - **Windows:** Install Npcap. Download from [npcap.com](https://npcap.com/).

#### 1. Download a Release

Download the pre-compiled binary for your client and server operating systems from the project's **Releases page**.

You will also need the configuration files from the `example/` directory.

#### 2. Configure the Connection

**Option A: Interactive Configuration (Recommended)**

Use the interactive configuration scripts to automatically generate your config file:

**Linux/macOS Client:**
```bash
# Download configuration script
curl -fsSL https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/configure-client.sh -o configure-client.sh
chmod +x configure-client.sh
sudo ./configure-client.sh
```

**Linux/macOS Server:**
```bash
# Download configuration script
curl -fsSL https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/configure-server.sh -o configure-server.sh
chmod +x configure-server.sh
sudo ./configure-server.sh
```

**Windows Client:**
```powershell
# Download and run configuration script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/configure-client.ps1" -OutFile "configure-client.ps1"
.\configure-client.ps1
```

**Windows Server:**
```powershell
# Download and run configuration script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/configure-server.ps1" -OutFile "configure-server.ps1"
.\configure-server.ps1
```

These scripts will:
- Auto-detect network interfaces and IP addresses
- Find gateway MAC addresses automatically
- Generate secure encryption keys
- Create a ready-to-use `config.yaml` file

**Option B: Manual Configuration**

phantom-proxy uses a unified configuration approach with role-based settings. Copy and modify either:

- `example/client.yaml.example` - Client configuration example
- `example/server.yaml.example` - Server configuration example

You must correctly set the interfaces, IP addresses, MAC addresses, and ports.

> **⚠️ Important:**
>
> - **Role Configuration**: Role must be explicitly set as `role: "client"` or `role: "server"`
> - **Transport Security**: KCP requires identical keys on client/server.
> - **Configuration**: See "Critical Configuration Points" section below for detailed security requirements

#### Finding Your Network Details (Manual Configuration)

You'll need to find your network interface name, local IP, and the MAC address of your network's gateway (router).

**On Linux:**

1.  **Find Interface and Local IP:** Run `ip a`. Look for your primary network card (e.g., `eth0`, `ens3`). Its IP address is listed under `inet`.
2.  **Find Gateway MAC:**
    - First, find your gateway's IP: `ip r | grep default`
    - Then, find its MAC address with `arp -n <gateway_ip>` (e.g., `arp -n 192.168.1.1`).

**On macOS:**

1.  **Find Interface and Local IP:** Run `ifconfig`. Look for your primary interface (e.g., `en0`). Its IP is listed under `inet`.
2.  **Find Gateway MAC:**
    - First, find your gateway's IP: `netstat -rn | grep default`
    - Then, find its MAC address with `arp -n <gateway_ip>` (e.g., `arp -n 192.168.1.1`).

**On Windows:**

1. **Find Interface and Local IP:** Run `ipconfig /all` and note your active network adapter (Ethernet or Wi-Fi), along with:
   - Its **IPv4 Address**
   - The **Gateway** IP
2. **Find Interface device GUID:** Windows requires the Npcap device GUID. In PowerShell, run: `Get-NetAdapter | Select-Object Name, InterfaceGuid`: Note the **InterfaceGuid** of your active network interface. (Format it as: `\Device\NPF_{GUID}`)
3. **Find Gateway MAC Address:** Run: `arp -a <gateway_ip>`. Note the MAC address for the gateway.

#### Client Configuration - SOCKS5 Proxy Mode

The client acts as a SOCKS5 proxy server, accepting connections from applications and dynamically forwarding them through the raw TCP packets to any destination.

#### Example Client Configuration (`config.yaml`)

```yaml
# Role must be explicitly set
role: "client"

# Logging configuration
log:
  level: "info" # none, debug, info, warn, error, fatal

# SOCKS5 proxy configuration (client mode)
socks5:
  - listen: "127.0.0.1:1080" # SOCKS5 proxy listen address

# Network interface settings
network:
  interface: "en0" # CHANGE ME: Network interface (en0, eth0, wlan0, etc.)
  # guid: "\Device\NPF_{...}" # Windows only (Npcap).
  ipv4:
    addr: "192.168.1.100:0" # CHANGE ME: Local IP (use port 0 for random port)
    router_mac: "aa:bb:cc:dd:ee:ff" # CHANGE ME: Gateway/router MAC address

# Server connection settings
server:
  addr: "10.0.0.100:9999" # CHANGE ME: phantom-proxy server address and port

# Transport protocol configuration
transport:
  protocol: "kcp" # Transport protocol (currently only "kcp" supported)
  kcp:
    block: "aes" # Encryption algorithm
    key: "your-secret-key-here" # CHANGE ME: Secret key (must match server)
```

#### Example Server Configuration (`config.yaml`)

```yaml
# Role must be explicitly set
role: "server"

# Logging configuration
log:
  level: "info" # none, debug, info, warn, error, fatal

# Server listen configuration
listen:
  addr: ":9999" # CHANGE ME: Server listen port (must match network.ipv4.addr port)

# Network interface settings
network:
  interface: "eth0" # CHANGE ME: Network interface (eth0, ens3, en0, etc.)
  ipv4:
    addr: "10.0.0.100:9999" # CHANGE ME: Server IPv4 and port (port must match listen.addr)
    router_mac: "aa:bb:cc:dd:ee:ff" # CHANGE ME: Gateway/router MAC address

# Transport protocol configuration
transport:
  protocol: "kcp" # Transport protocol (currently only "kcp" supported)
  kcp:
    block: "aes" # Encryption algorithm
    key: "your-secret-key-here" # CHANGE ME: Secret key (must match client)
```

#### Critical Firewall Configuration

This application uses `pcap` to receive and inject packets at a low level, **bypassing traditional firewalls like `ufw` or `firewalld`**. However, the OS kernel will still see incoming packets for the connection port and, not knowing about the connection, will generate TCP `RST` (reset) packets. While your connection may appear to work initially, these kernel-generated RST packets can corrupt connection state in NAT devices and stateful firewalls, leading to connection instability, packet drops, and premature connection termination in complex network environments.

You **must** configure `iptables` on the server to prevent the kernel from interfering.

Run these commands as root on your server:

```bash
# Replace <PORT> with your server listen port (e.g., 9999)

# 1. Bypass connection tracking (conntrack) for the connection port. This is essential.
# This tells the kernel's netfilter to ignore packets on this port for state tracking.
sudo iptables -t raw -A PREROUTING -p tcp --dport <PORT> -j NOTRACK
sudo iptables -t raw -A OUTPUT -p tcp --sport <PORT> -j NOTRACK

# 2. Prevent the kernel from sending TCP RST packets that would kill the session.
# This drops any RST packets the kernel tries to send from the connection port.
sudo iptables -t mangle -A OUTPUT -p tcp --sport <PORT> --tcp-flags RST RST -j DROP

# An alternative for rule 2 if issues persist:
sudo iptables -t filter -A INPUT -p tcp --dport <PORT> -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --sport <PORT> -j ACCEPT

# To make rules persistent across reboots:
# Debian/Ubuntu: sudo iptables-save > /etc/iptables/rules.v4
# RHEL/CentOS: sudo service iptables save
```

These rules ensure that only the application handles traffic for the connection port.

#### 3. Run `phantom-proxy`

If you used the automated installer, phantom-proxy will be available globally. Otherwise, make the downloaded binary executable (`chmod +x ./phantom-proxy_linux_amd64`). You will need root privileges to use raw sockets.

**On the Server:**

```bash
# If installed via script:
sudo phantom-proxy run -c /etc/phantom-proxy/config.yaml

# If manual installation, place your server configuration file in the same directory as the binary:
sudo ./phantom-proxy_linux_amd64 run -c config.yaml
```

**On the Client:**

```bash
# If installed via script:
sudo phantom-proxy run -c /etc/phantom-proxy/config.yaml

# If manual installation, place your client configuration file in the same directory as the binary:
sudo ./phantom-proxy_darwin_arm64 run -c config.yaml
```

#### 4. Test the Connection

Once the client and server are running, test the SOCKS5 proxy:

```bash
# Test with curl using the SOCKS5 proxy
curl -v https://httpbin.org/ip --proxy socks5h://127.0.0.1:1080
```

This request will be proxied over raw TCP packets to the server, and then forwarded according to the client mode configuration. The output should show your server's public IP address, confirming the connection is working.

## Command-Line Usage

`phantom-proxy` is a multi-command application. The primary command is `run`, which starts the proxy, but several utility commands are included to help with configuration and debugging.

The general syntax is:

```bash
sudo ./phantom-proxy <command> [arguments]
```

| Command   | Description                                                                      |
| :-------- | :------------------------------------------------------------------------------- |
| `run`     | Starts the `phantom-proxy` client or server proxy. This is the main operational command. |
| `secret`  | Generates a new, cryptographically secure secret key.                            |
| `ping`    | Sends a single test packet to the server to verify connectivity .                |
| `dump`    | A diagnostic tool similar to `tcpdump` that captures and decodes packets.        |
| `version` | Prints the application's version information.                                    |

## Configuration Reference

phantom-proxy uses a unified YAML configuration that works for both clients and servers. The `role` field must be explicitly set to either `"client"` or `"server"`.

**For complete parameter documentation, see the example files:**

- [`example/client.yaml.example`](example/client.yaml.example) - Client configuration reference
- [`example/server.yaml.example`](example/server.yaml.example) - Server configuration reference

### Encryption Modes

The `transport.kcp.block` parameter determines the encryption method. There are two special modes to disable encryption:

**`none`** (Plaintext with Header)
No encryption is applied, but a protocol header is still present. The packet format remains compatible with encrypted modes, but the content is plaintext. This helps with protocol compatibility.

**`null`** (Raw Data)
No encryption and no protocol header, data is transmitted in raw form without any cryptographic framing. This offers the highest performance but is the least secure and most easily identified.

### Critical Configuration Points

**Transport Security:** KCP requires identical keys on client/server (use `secret` command to generate).

**Network Configuration:** Use your actual IP address in `network.ipv4.addr`, not `127.0.0.1`. For servers, `network.ipv4.addr` and `listen.addr` ports must match. For clients, use port `0` in `network.ipv4.addr` to automatically assign a random available port and avoid conflicts.

**TCP Flag Cycling:** The `network.tcp.local_flag` and `network.tcp.remote_flag` arrays cycle through flag combinations to vary traffic patterns. Common patterns: `["PA"]` (standard data), `["S"]` (connection setup), `["A"]` (acknowledgment).

# Architecture & Security Model

### The `pcap` Approach and Firewall Bypass

Understanding _why_ standard firewalls are bypassed is key to using this tool securely.

A normal application uses the OS's TCP/IP stack. When a packet arrives, it travels up the stack where `netfilter` (the backend for `ufw`/`firewalld`) inspects it. If a firewall rule blocks the port, the packet is dropped and never reaches the application.

```
      +------------------------+
      |   Normal Application   |  <-- Data is received here
      +------------------------+
                   ^
      +------------------------+
      |    OS TCP/IP Stack     |  <-- Firewall (netfilter) runs here
      |  (Connection Tracking) |
      +------------------------+
                   ^
      +------------------------+
      |     Network Driver     |
      +------------------------+
```

`phantom-proxy` uses `pcap` to hook in at a much lower level. It requests a **copy** of every packet directly from the network driver, _before_ the main OS TCP/IP stack and firewall get to process it.

```
      +------------------------+
      |    phantom-proxy Application   |  <-- Gets a packet copy immediately
      +------------------------+
              ^       \
 (pcap copy) /         \  (Original packet continues up)
            /           v
      +------------------------+
      |     OS TCP/IP Stack    |  <-- Firewall drops the *original* packet,
      |  (Connection Tracking) |      but phantom-proxy already has its copy.
      +------------------------+
                  ^
      +------------------------+
      |     Network Driver     |
      +------------------------+
```

This means a rule like `ufw deny <PORT>` will have no effect on the proxy's operation, as `phantom-proxy` receives and processes the packet before `ufw` can block it.

## ⚠️ Security Warning

This project is an exploration of low-level networking and carries significant security responsibilities. The KCP transport protocol provides encryption, authentication, and integrity using symmetric encryption with a shared secret key.

Security depends entirely on proper key management. Use the `secret` command to generate a strong key that must remain identical on both client and server.

## Troubleshooting

1.  **Permission Denied:** Ensure you are running with `sudo`.
2.  **Connection Times Out:**
    - **Transport Configuration Mismatch:**
      - **KCP**: Ensure `transport.kcp.key` is exactly identical on client and server
    - **`iptables` Rules:** Did you apply the firewall rules on the server?
    - **Incorrect Network Details:** Double-check all IPs, MAC addresses, and interface names.
    - **Cloud Provider Firewalls:** Ensure your cloud provider's security group allows TCP traffic on your `listen.addr` port.
    - **NAT/Port Configuration:** For servers, ensure `listen.addr` and `network.ipv4.addr` ports match. For clients, use port `0` in `network.ipv4.addr` for automatic port assignment to avoid conflicts.
3.  **Use `ping` and `dump`:** Use `phantom-proxy ping -c config.yaml` to test the connection. Use `phantom-proxy dump -p <PORT>` on the server to see if packets are arriving.

## Uninstallation

To remove phantom-proxy from your system:

### Linux/macOS

```bash
# Download and run the uninstallation script
curl -fsSL https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/uninstall.sh | sudo bash

# Or download first, then run:
wget https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/uninstall.sh
chmod +x uninstall.sh
sudo ./uninstall.sh
```

### Windows

```powershell
# Download and run as Administrator in PowerShell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/uninstall.ps1" -OutFile "uninstall.ps1"
.\uninstall.ps1
```

The uninstall script will remove the binary and optionally remove configuration files. Note that libpcap/Npcap must be uninstalled manually if no longer needed.

## Acknowledgments

This work draws inspiration from the research and implementation in the [gfw_resist_tcp_proxy](https://github.com/GFW-knocker/gfw_resist_tcp_proxy) project by GFW-knocker, which explored the use of raw sockets to circumvent certain forms of network filtering. This project serves as a Go-based exploration of those concepts.

- Uses [pcap](https://github.com/the-tcpdump-group/libpcap) for low-level packet capture and injection
- Uses [gopacket](https://github.com/gopacket/gopacket) for raw packet crafting and decoding
- Uses [kcp-go](https://github.com/xtaci/kcp-go) for reliable transport with encryption
- Uses [smux](https://github.com/xtaci/smux) for connection multiplexing

## License

This project is licensed under the MIT License. See the see [LICENSE](LICENSE) file for details.
