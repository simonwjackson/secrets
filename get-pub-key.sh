#!/usr/bin/env bash

# Check if correct number of arguments provided
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <hostname> <remote_host>"
  echo "Example: $0 myserver 192.168.1.100"
  exit 1
fi

HOSTNAME=$1
REMOTE_HOST=$2
KEY_DIR="keys/hosts"
SECRETS_FILE="agenix/secrets.nix"

# Create keys directory if it doesn't exist
mkdir -p "$KEY_DIR"

# Get remote host's public key
KEY_FILE="${KEY_DIR}/x86_64-linux_${HOSTNAME}_ssh_host_rsa_key.pub"
ssh-keyscan -t rsa "$REMOTE_HOST" 2>/dev/null | grep "ssh-rsa" | head -n 1 | cut -f2- -d" " >"$KEY_FILE"

if [ ! -s "$KEY_FILE" ]; then
  echo "Failed to retrieve public key from $REMOTE_HOST"
  rm -f "$KEY_FILE"
  exit 1
else
  git add "$KEY_FILE"
fi

# Run agenix rekey
echo "Running agenix rekey..."
(cd agenix && agenix --rekey)

# Check if hostname already exists in secrets.nix
if grep -q "^  ${HOSTNAME} = " "$SECRETS_FILE"; then
  echo "Successfully rekeyed secrets"
  echo "Note: Host $HOSTNAME already exists in $SECRETS_FILE"
  exit 0
fi

# Add host definition if it doesn't exist
if ! grep -q "^  ${HOSTNAME} = " "$SECRETS_FILE"; then
  # Add host definition after the last host definition
  sed -i "/^  zao = /a\\  ${HOSTNAME} = builtins.readFile ..\/keys\/hosts\/x86_64-linux_${HOSTNAME}_ssh_host_rsa_key.pub;" "$SECRETS_FILE"
  
  # Add to systems list
  sed -i "/^  systems = \[/a\\    ${HOSTNAME}" "$SECRETS_FILE"
fi

echo "Successfully added host $HOSTNAME and rekeyed secrets"
