ui = true
disable_mlock = false

# Modern Integrated Storage (Raft)
storage "raft" {
  path    = "/vault/file"
  node_id = "vault-node-1"
}

# Enforce TLS
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/certs/fullchain.pem"
  tls_key_file  = "/vault/certs/privkey.pem"
  tls_disable   = 0
  
  # DevSecOps Best Practice: Disable outdated TLS versions
  tls_min_version = "tls12"
  
  # Optional but recommended: Specify secure cipher suites
  # tls_cipher_suites = "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
}

# Replace with your actual domain
api_addr     = "https://yourdomain.com:8200"
cluster_addr = "https://yourdomain.com:8201"
