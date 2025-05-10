#!/usr/bin/env python3
from string import Template

# Descriptions for controllers
controller = 'acks'
description = 'Umbrella Chart for all Resources on AWS'
add_description_stub(description_overrides, controller, description)

# Chart.yaml stub
glob_chart_stub1 = Template('''apiVersion: v2
name: $controller
description: $descriptions
version: 0.1.1
type: application
appVersion: "master"
dependencies:
  - name: ack-chart
    version: 46.22.5
    alias: acks
    repository: oci://public.ecr.aws/aws-controllers-k8s
  - name: network
    version: 0.1.0
    repository: file://../network
''')
glob_chart_stub1 = glob_chart_stub1.substitute(controller=controller, descriptions=description)
add_chart_stub(chart_overrides, controller, glob_chart_stub1)

# values.yaml stub
glob_values_stub1 = '''# Default values for global chart
global:
  # Deploys aws specific ingress
  aws: 
    enabled: true
  environment: devplanetv2
  # Deploys elasticsearch and postgres in k8s
  dev: true
  # Replace with your dev environment url. 
  hostname: qureshi.planx-pla.net
  # this is arn to a certificate in AWS that needs to match the hostname.
  # This one is for *.planx-pla.net
  revproxyArn: arn:aws:acm:us-east-1:707767160287:certificate/520ede2f-fc82-4bb9-af96-4b4af7deabbd


# configuration for fence helm chart. You can add it for all our services.
fence:
  # Override image
  image:
    repository: quay.io/cdis/fence
    tag: master

  # Fence config overrides 
  FENCE_CONFIG:
    APP_NAME: 'Gen3 Data Commons'
    # A URL-safe base64-encoded 32-byte key for encrypting keys in db
    # in python you can use the following script to generate one:
    #     import base64
    #     import os
    #     key = base64.urlsafe_b64encode(os.urandom(32))
    #     print(key)
    ENCRYPTION_KEY: REPLACEME

    DEBUG: True
    OPENID_CONNECT:
      google:
        client_id: ""
        client_secret: ""

    AWS_CREDENTIALS:
      'fence-bot':
        aws_access_key_id: ''
        aws_secret_access_key: ''

    S3_BUCKETS:
      # Name of the actual s3 bucket
      jq-helm-testing:
        cred: 'fence-bot'
        region: us-east-1
    
    # This is important for data upload.
    DATA_UPLOAD_BUCKET: 'jq-helm-testing'



# -- (map) To configure postgresql subchart
# Persistence is disabled by default
postgresql:
  primary:
    persistence:
      # -- (bool) Option to persist the dbs data.
      enabled: true



acks:
  acm:
    enabled: false
  acmpca:
    enabled: false
  ecr:
    enabled: false
  ecs:
    enabled: false
  elbv2:
    enabled: false
  emrcontainers:
    enabled: false

  applicationautoscaling:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  cloudfront:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  cloudtrail:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  cloudwatch:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  cloudwatchlogs:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  ec2:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  eks:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  iam:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  kms:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  lambda:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  opensearchservice:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  rds:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  route53resolver:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  s3:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  s3control:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  secretsmanager:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  sns:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  sqs:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi

  wafv2:
    enabled: true
    namespace: ack-system
    replicas: 1
    enableDevelopmentLogging: false
    logLevel: info
    reconcileDefaultMaxConcurrentSyncs: 1
    resourceTags: []
    leaderElection:
      enabled: false
      namespace: leader-election-namespace
    image:
      repository: controller
      tag: latest
    resources:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 100m
        memory: 300Mi
'''
add_values_stub(values_overrides, controller, glob_values_stub1)

glob_readme_stub1 = '''### Umbrella Chart for all Resources on AWS
This chart deploys all ACKs as a single umbrella chart. 
It is recommended to use this chart for AWS development environments.

This chart downloads the latest ACKs from the public ECR repository.
and superimposes the values.yaml file on top of their defaults.
Fill with your desired comute values and deploy. 
All controllers are usually deployed even in dev environments.
And all of them are enabled by default.
All controllers are deployed in the same namespace.
'''
add_readme_stub(readme_overrides, controller, glob_readme_stub1)