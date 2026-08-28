#!/bin/bash
set -e

echo "🚀 Deploying k8s-security-networking..."

# Проверяем, запущен ли Minikube
if ! minikube status &>/dev/null; then
    echo "Starting Minikube..."
    minikube start --cpus=4 --memory=8192 --cni=calico --driver=docker
else
    echo "Minikube is already running."
fi

# Переключаем Docker на Minikube
eval $(minikube docker-env)

# Собираем образ
echo "Building Docker image..."
docker build -t task-manager:latest .

# Применяем манифесты
echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/role.yaml
kubectl apply -f k8s/rolebinding.yaml
kubectl apply -f k8s/postgres-deploy.yaml
kubectl apply -f k8s/postgres-svc.yaml

echo "Waiting for PostgreSQL to start..."
sleep 15

kubectl apply -f k8s/flask-deploy.yaml
kubectl apply -f k8s/flask-svc.yaml
kubectl apply -f k8s/network-policies/

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n task-manager --timeout=60s || true
kubectl wait --for=condition=ready pod -l app=flask -n task-manager --timeout=60s || true

echo "Pods status:"
kubectl get pods -n task-manager

echo "Services:"
kubectl get svc -n task-manager

echo "✅ Deployment complete!"
echo "To access the application, run: kubectl port-forward -n task-manager svc/flask-service 5000:5000"