#!/usr/bin/env bash

# Release versions per controller
declare -A RELEASE_VERSIONS
RELEASE_VERSIONS=(
    [s3]="1.0.28"
    [ec2]="1.0.20"
    [vpc]="1.0.16"
    [rds]="1.0.25"
)
# Services to deploy
SERVICES=(
    "s3"
    "ec2"
    "vpc"
    "rds"
)