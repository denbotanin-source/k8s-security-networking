#!/bin/bash
set -e

echo "🧹 Cleaning up k8s-security-networking..."

kubectl delete namespace task-manager --ignore-not-found=true

eval $(minikube docker-env)
docker rmi -f task-manager:latest 2>/dev/null || echo "Image not found"

echo "✅ Cleanup complete."