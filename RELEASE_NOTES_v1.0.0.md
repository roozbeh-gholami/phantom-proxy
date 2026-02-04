# phantom-proxy v1.0.0 - Initial Release

**phantom-proxy** is a bidirectional packet-level proxy using KCP and raw socket transport with encryption. It bypasses the OS TCP/IP stack by operating at the packet level using `pcap` and custom packet crafting.

## 🎉 Features

### Core Functionality
- **KCP-based Transport**: Encrypted, reliable transport optimized for high-loss networks
- **Raw Packet Operations**: Complete bypass of OS TCP/IP stack using pcap
- **SOCKS5 Proxy**: Full SOCKS5 server implementation for dynamic forwarding
- **Port Forwarding**: Static TCP/UDP port forwarding support
- **Multi-platform**: Linux, macOS, and Windows support

### Installation & Configuration
- **Automated Installation**: One-line installation scripts for all platforms
- **Interactive Configuration**: Auto-detecting network setup scripts
- **Example Configurations**: Ready-to-use client and server config templates

### Security
- **AES Encryption**: Built-in AES encryption via KCP
- **Secret Key Authentication**: Shared secret key for client-server authentication
- **Connection Multiplexing**: smux-based stream multiplexing over single connection

## 📦 Installation

### Quick Install (Recommended)

**Linux/macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/install.sh | sudo bash
```

**Windows (PowerShell as Administrator):**
```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/install.ps1'))
```

### Interactive Configuration

**Client:**
```bash
# Linux/macOS
curl -fsSL https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/configure-client.sh | sudo bash

# Windows
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/configure-client.ps1" | iex
```

**Server:**
```bash
# Linux/macOS
curl -fsSL https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/configure-server.sh | sudo bash

# Windows
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/configure-server.ps1" | iex
```

## 🚀 Quick Start

1. Install phantom-proxy (see above)
2. Configure using interactive scripts
3. Run on server: `sudo phantom-proxy run -c config.yaml`
4. Run on client: `sudo phantom-proxy run -c config.yaml`
5. Test: `curl https://httpbin.org/ip --proxy socks5h://127.0.0.1:1080`

## 📋 Requirements

- **Linux/macOS**: libpcap development libraries
- **Windows**: Npcap
- **All**: Root/Administrator privileges for raw socket access

## ⚙️ Available Binaries

This release includes pre-built binaries for:
- Linux (amd64, arm64)
- macOS (amd64, arm64)
- Windows (amd64)

## 📚 Documentation

- [README.md](https://github.com/roozbeh-gholami/phantom-proxy/blob/main/README.md) - Complete documentation
- [RELEASE.md](https://github.com/roozbeh-gholami/phantom-proxy/blob/main/RELEASE.md) - Release creation guide
- [Example Configs](https://github.com/roozbeh-gholami/phantom-proxy/tree/main/example) - Configuration examples

## ⚠️ Important Notes

- This tool requires root/administrator privileges
- Server requires iptables configuration (Linux) or firewall rules (Windows)
- Uses raw sockets and bypasses standard OS firewalls by design
- Intended for network research, testing, and specialized use cases

## 🔐 Security Warning

This project operates at a low level and carries security responsibilities. Always:
- Use strong secret keys (generate with `phantom-proxy secret`)
- Keep the same secret key on client and server
- Understand the implications of bypassing OS-level firewalls

## 📝 License

MIT License - See [LICENSE](https://github.com/roozbeh-gholami/phantom-proxy/blob/main/LICENSE) file for details

---

**Full Changelog**: https://github.com/roozbeh-gholami/phantom-proxy/commits/v1.0.0
