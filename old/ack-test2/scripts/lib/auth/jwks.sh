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