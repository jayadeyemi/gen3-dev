# 2) Generate an RSA keypair for JWKS
openssl genrsa -out oidc-issuer.key 2048
openssl rsa -in oidc-issuer.key -pubout -out oidc-issuer.pub

# 3) Build a minimal JWKS document (single key)
PUB_DER=$(openssl rsa -in oidc-issuer.key -pubout -outform DER | base64 | tr -d '\n')
cat > jwks.json <<EOF
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