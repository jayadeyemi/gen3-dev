PUB_DER=$(openssl rsa -in "${KEY_BASE}.key" -pubout -outform DER | base64 | tr -d '\n')
cat > "${JWKS_FILE}" <<EOF
{
  "keys": [
    {
      "kty": "RSA",
      "use": "sig",
      "alg": "RS256",
      "kid": "1",
      "n": "${PUB_DER}",
      "e": "AQAB"
    }
  ]
}
EOF


#   # Generate per-controller RSA keypair
#   KEY_BASE="${svc}-issuer"
#   openssl genrsa -out "${KEY_BASE}.key" 2048
#   openssl rsa -in "${KEY_BASE}.key" -pubout -out "${KEY_BASE}.pub"

#   # Build JWKS
#   PUB_DER=$(openssl rsa -in "${KEY_BASE}.key" -pubout -outform DER | base64 | tr -d '
# ')
#   jwks_file="jwks-${svc}.json"
#   cat > "$jwks_file" <<EOF
# {
#   "keys": [
#     {
#       "kty": "RSA",
#       "use": "sig",
#       "alg": "RS256",
#       "kid": "1",
#       "n": "${PUB_DER}",
#       "e": "AQAB"
#     }
#   ]
# }
# EOF