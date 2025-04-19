# Generate the keypair
PRIV_KEY="sa-signer.key"
PUB_KEY="sa-signer.key.pub"
PKCS_KEY="sa-signer-pkcs8.pub"
# Generate a key pair
ssh-keygen -t rsa -b 2048 -f $PRIV_KEY -m pem
# convert the SSH pubkey to PKCS8
ssh-keygen -e -m PKCS8 -f $PUB_KEY > $PKCS_KEY

# Create S3 bucket with a random name. Feel free to set your own name here
export S3_BUCKET=${S3_BUCKET:-oidc-test-$(cat /dev/random | LC_ALL=C tr -dc "[:alpha:]" | tr '[:upper:]' '[:lower:]' | head -c 32)}
# Create the bucket if it doesn't exist
_bucket_name=$(aws s3api list-buckets  --query "Buckets[?Name=='$S3_BUCKET'].Name | [0]" --out text)
if [ $_bucket_name == "None" ]; then
    if [ "$AWS_REGION" == "us-east-1" ]; then
        aws s3api create-bucket --bucket $S3_BUCKET
    else
        aws s3api create-bucket --bucket $S3_BUCKET --create-bucket-configuration LocationConstraint=$AWS_REGION
    fi
fi
echo "export S3_BUCKET=$S3_BUCKET"
export HOSTNAME=s3.$AWS_REGION.amazonaws.com
export ISSUER_HOSTPATH=$HOSTNAME/$S3_BUCKET

cat <<EOF > discovery.json
{
    "issuer": "https://$ISSUER_HOSTPATH",
    "jwks_uri": "https://$ISSUER_HOSTPATH/keys.json",
    "authorization_endpoint": "urn:kubernetes:programmatic_authorization",
    "response_types_supported": [
        "id_token"
    ],
    "subject_types_supported": [
        "public"
    ],
    "id_token_signing_alg_values_supported": [
        "RS256"
    ],
    "claims_supported": [
        "sub",
        "iss"
    ]
}
EOF

go run ./hack/self-hosted/main.go -key $PKCS_KEY  | jq '.keys += [.keys[0]] | .keys[1].kid = ""' > keys.json

aws s3 cp --acl public-read ./discovery.json s3://$S3_BUCKET/.well-known/openid-configuration
aws s3 cp --acl public-read ./keys.json s3://$S3_BUCKET/keys.json

kube-apiserver --service-account-key-file=$PKCS_KEY --oidc-issuer-url=https://$ISSUER_HOSTPATH --oidc-client-id=sts.amazonaws.com --oidc-groups-claim=groups --oidc-username-claim=sub --oidc-signing-key-file=$PKCS_KEY --oidc-ca-file=$PKCS_KEY