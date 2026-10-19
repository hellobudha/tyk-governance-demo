#!/usr/bin/env bash
# Deletes the kind cluster and everything in it.
source "$(dirname "$0")/env.sh"
kind delete cluster --name "$KIND_CLUSTER"
