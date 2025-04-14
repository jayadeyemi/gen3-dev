# Helm Access Chart

This chart deploys AWS S3 and CloudFront distribution resources using AWS Controllers for Kubernetes (ACK).

## Prerequisites

- AWS Controllers for Kubernetes must be installed and configured.
- Ensure the required IAM permissions are available.
- Helm 3.8+ should be installed on your local machine.

## Variables - values.yaml

- **accessUrl:** The S3 bucket name and CloudFront alias.
- **accessCert:** The ARN of the ACM certificate.
- **region:** AWS region (default is "us-east-1").
- **s3WebsiteEndpoint:** The S3 Website endpoint (format: `{bucket}.s3-website-{region}.amazonaws.com`).

## Installing the Chart

```bash
helm install my-helm-access ./helm-access
```
