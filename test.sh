#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
PUB_KEY="./env/keys/Public-EC2-KeyPair.pem"
INSTANCE_PUBLIC_IP="13.218.239.12"
LOG_FILE="./logs/outputs.log"

# --- Prep ---
# 1. Ensure target directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# 2. Derive the EC2 host name
EC2_HOST="ec2-${INSTANCE_PUBLIC_IP//./-}.compute-1.amazonaws.com"

# --- Write out the SSH script into $LOG_FILE ---
cat > "$LOG_FILE" <<EOF
#!/usr/bin/env bash
set -euo pipefail

# Ensure SSH dir exists
mkdir -p "\$HOME/.ssh"

# Copy your key and lock permissions
cp "$PUB_KEY" "\$HOME/.ssh/$(basename "$PUB_KEY")"
chmod 600 "\$HOME/.ssh/$(basename "$PUB_KEY")"

# SSH into the EC2 instance
ssh -t \\
    -i "\$HOME/.ssh/$(basename "$PUB_KEY")" \\
    -o StrictHostKeyChecking=no \\
    ubuntu@"$EC2_HOST"
EOF

# 3. Make it executable
chmod +x "$LOG_FILE"

echo "▶ SSH script has been written to $LOG_FILE – run it later to connect."
