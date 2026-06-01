#### Tree of the files: 
```
.
├── certs
│   ├── fullchain.pem
│   └── privkey.pem
├── config
│   └── vault.hcl
├── data
│   ├── raft
│   │   ├── raft.db
│   │   └── snapshots
│   └── vault.db
├── docker-compose.yml
└── logs
    └── vault_audit.log
```
#################################################################
# HashiCorp Vault Production Deployment Guide (Docker Compose)

## 📌 Architecture Overview
This document outlines the deployment of a standalone HashiCorp Vault instance using Docker Compose. The deployment strictly adheres to DevSecOps best practices:
*   **Storage:** Modern Integrated Storage (Raft) – no external dependencies (e.g., Consul).
*   **Security:** End-to-End TLS termination at the container level.
*   **Memory Protection:** `IPC_LOCK` capability enabled to prevent sensitive data swapping to disk.
*   **Least Privilege:** Vault runs as a restricted non-root user (UID 100). Host mounts are mapped accordingly, utilizing read-only (`ro`) mounts where write access is unnecessary.

## 📋 Prerequisites
1.  **Host OS:** Ubuntu Linux (tested on latest) with Docker and Docker Compose installed.
2.  **Network:** A registered domain name pointed to the host IP.
    *   *Note for Cloudflare Users:* The DNS A-record **MUST** be set to "DNS Only" (Grey Cloud). Cloudflare's proxy drops traffic on ports 8200/8201 and interferes with strict TLS/mTLS validation.
3.  **Certificates:** Valid Let's Encrypt certificates for the domain (Fullchain and Private Key).

---

## 🛠️ Step 1: Directory & Permission Setup
Vault requires specific directories mapped to the host. Because the Vault container drops root privileges and runs as UID `100` and GID `1000`, the mapped directories must reflect these ownership permissions.

```bash
# Create directory structure
mkdir -p /opt/vault/{config,data,logs,certs}
cd /opt/vault

# Copy Let's Encrypt certificates to the certs directory
cp /etc/letsencrypt/live/vault.yourdomain.com/fullchain.pem ./certs/
cp /etc/letsencrypt/live/vault.yourdomain.com/privkey.pem ./certs/

# Apply DevSecOps permissions (UID 100 = vault user in container)
chown -R 100:1000 ./data ./logs ./certs
chmod 600 ./certs/privkey.pem
```
*(Note: `./config` remains owned by root as Vault only requires read access).*

---

## ⚙️ Step 2: Configuration Files

### 1. Vault Configuration (`/opt/vault/config/vault.hcl`)
Defines the Raft storage backend, enforces TLS 1.2+, and configures the listener.

```hcl
ui = true
disable_mlock = false

storage "raft" {
  path    = "/vault/file"
  node_id = "vault-node-1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  tls_cert_file   = "/vault/certs/fullchain.pem"
  tls_key_file    = "/vault/certs/privkey.pem"
  tls_disable     = 0
  tls_min_version = "tls12"
}

api_addr     = "https://vault.yourdomain.com:8200"
cluster_addr = "https://vault.yourdomain.com:8201"
```

### 2. Docker Compose (`/opt/vault/docker-compose.yml`)
Deploys the Vault service with strict memory locking and read-only mounts.

```yaml
version: '3.8'

services:
  vault:
    image: hashicorp/vault:latest
    container_name: vault-prod
    restart: unless-stopped
    cap_add:
      - IPC_LOCK
    environment:
      - VAULT_ADDR=https://127.0.0.1:8200
      - VAULT_API_ADDR=https://vault.yourdomain.com:8200
    volumes:
      - ./config:/vault/config:ro
      - ./certs:/vault/certs:ro
      - ./data:/vault/file
      - ./logs:/vault/logs
    ports:
      - "8200:8200"
      - "8201:8201"
    command: vault server -config=/vault/config/vault.hcl
```

---

## 🚀 Step 3: Deployment & Initialization

1.  **Start the container:**
    ```bash
    cd /opt/vault
    docker-compose up -d
    ```

2.  **Initialize Vault:**
    *Initialization generates the Unseal Keys and the Initial Root Token. This is only done once.*
    ```bash
    docker exec -it vault-prod vault operator init -tls-skip-verify
    ```
    🚨 **CRITICAL:** Securely store the 5 Unseal Keys and 1 Root Token in a password manager immediately. Loss of unseal keys results in permanent data loss.

3.  **Unseal Vault:**
    *Provide 3 out of the 5 unseal keys to unlock the database.*
    ```bash
    docker exec -it vault-prod vault operator unseal -tls-skip-verify
    # Repeat command 3 times, providing a different key each time.
    ```

---

## 🔒 Step 4: Security Hardening (Audit Logging)

Vault does not log requests by default. To adhere to compliance and DevSecOps standards, file auditing must be enabled.

1.  **Authenticate locally:**
    ```bash
    docker exec -it vault-prod vault login -tls-skip-verify
    # Enter the Initial Root Token when prompted
    ```

2.  **Enable the Audit Device:**
    *Because we are querying the `127.0.0.1` loopback address internally, we use `-tls-skip-verify` to bypass the Let's Encrypt Domain SAN check for this local command.*
    ```bash
    docker exec -it vault-prod vault audit enable -tls-skip-verify file file_path=/vault/logs/vault_audit.log
    ```

3.  **Verify Audit Logs:**
    ```bash
    tail -f /opt/vault/logs/vault_audit.log
    ```

**Next Steps for Administrators:** Access the UI at `https://vault.yourdomain.com:8200`, configure non-root Auth Methods (AppRole, OIDC), create administrative policies, and revoke the Initial Root Token.
