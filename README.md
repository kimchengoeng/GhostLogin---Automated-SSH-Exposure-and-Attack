# 👻 Ghost Login

## ⚠️ Disclaimer

This project is created strictly for **educational purposes and authorized security testing only**.

Do not use this tool on any system, network, or device you do not own or do not have explicit permission to test. Unauthorized access is illegal. The author is not responsible for any misuse.

---

## 📌 Project Overview

**Ghost Login** is a Bash-based automation script that simulates a basic penetration testing workflow in a controlled lab environment.

It demonstrates how security testing automation works, including network scanning, SSH detection, credential testing, and post-access simulation.

---

## ⚙️ Features

- IP / CIDR input validation  
- Network scanning for SSH (Port 22) using Nmap  
- Automatic discovery of live SSH hosts  
- Credential brute-force testing (user:pass format)  
- Logging of successful logins  
- Post-access simulation (PoC execution)  
- Structured reporting output  

---

## 🧰 Requirements

Install dependencies:

```bash
sudo apt update
sudo apt install nmap sshpass
```

---

Required tools:
- `bash`
- `nmap`
- `ssh`
- `sshpass`
