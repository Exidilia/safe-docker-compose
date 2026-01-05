Here are the specific steps you need to do after creating `docker-compose.yml` and `.env` files (The instructions are for WSL, for now. for linux server configs, they might be slightly different):

### SSL Generation Script (Mandatory for HTTPS)
Since security is prioritized (`external_url 'https://...'`), GitLab will not start without a certificate. For local/development environments, create a Self-Signed certificate.

Run the following command in WSL:

```bash
# Create SSL directory
mkdir -p ssl

# Generate key and certificate for gitlab.local
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/gitlab.local.key \
  -out ssl/gitlab.local.crt \
  -subj "/C=IR/ST=Tehran/L=Tehran/O=DevOps/CN=gitlab.local"
```
**Note:** If you selected a different domain in your `.env` file, change the filenames in the command above accordingly.

### Post-Installation Steps
To truly align with the new team's security standards, perform the following actions after running `docker-compose up -d`:

**Retrieve Initial Password:**
The root password is not hardcoded (Best Practice). You can find it using the following command:

```bash
docker exec -it gitlab_server grep 'Password:' /etc/gitlab/initial_root_password
```
**Warning:** This file is automatically deleted after 24 hours. Log in immediately and change the password.

**Hosts File Configuration:**
In Windows, edit your hosts file (`C:\Windows\System32\drivers\etc\hosts`) and add the following line to access the instance by name:

```text
127.0.0.1 gitlab.local
```

**Log Configuration for Splunk:**
The `./logs` path in your current directory contains all logs for `nginx`, `sidekiq`, and `rails`.
You should configure your **Splunk Forwarder** to monitor this path on the host (instead of installing the forwarder inside the container).

Critical paths for monitoring:
*   `./logs/nginx/*.log`
*   `./logs/gitlab-rails/*.log`
*   `./logs/gitaly/current`

### Important Note on System Resources
GitLab requires at least **4GB of RAM**. I have set the limit to `6G` in the compose file. If your system (WSL) has less than 8GB of free RAM, the container will likely crash or run extremely slowly. In this case, reduce `puma['worker_processes']` to `1` in the configuration, but do not expect high performance.
