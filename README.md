# k8s-security-networking: Безопасность Kubernetes

Этот проект демонстрирует полный стек безопасности для приложения на Flask с PostgreSQL в Kubernetes: RBAC, Network Policies, Pod Security Admission, SecurityContext и CI/CD с Trivy.

---

## Содержание

1. [О проекте](#1-о-проекте)
2. [Технологии](#2-технологии)
3. [Структура проекта](#3-структура-проекта)
4. [Требования](#4-требования)
5. [Быстрый старт (локально)](#5-быстрый-старт-локально)
6. [Запуск в Kubernetes (Minikube)](#6-запуск-в-kubernetes-minikube)
7. [API](#7-api)
8. [Безопасность](#8-безопасность)
9. [CI/CD: GitHub Actions](#9-cicd-github-actions)
10. [Результаты сканирования](#10-результаты-сканирования)
11. [Автор](#11-автор)

---

## 1. О проекте

Проект создан для демонстрации подхода "Security as Code" на реальном приложении. Используется Flask с PostgreSQL, развернутый в Kubernetes с полным набором средств безопасности:

- **RBAC** – ServiceAccount, Role, RoleBinding для ограничения доступа Pod'ов к API.
- **Network Policies** – изоляция трафика: БД принимает подключения только от Flask, Flask ходит только к БД и DNS.
- **Pod Security Admission (PSA)** – применение уровня `restricted` к namespace.
- **SecurityContext** – запрет root, seccomp, drop всех capabilities, read-only rootfs.
- **CI/CD** – автоматическое сканирование уязвимостей через Trivy в GitHub Actions.

**Функциональность приложения:**
- `/` – возвращает количество визитов (счётчик в PostgreSQL).
- `/health` – проверка состояния приложения и подключения к БД.
- `/tasks` – список всех задач (демонстрация работы с БД).

---

## 2. Технологии

| Компонент | Технология | Версия |
|-----------|------------|--------|
| Веб-фреймворк | Flask | 2.3.3 |
| База данных | PostgreSQL | 15-alpine |
| Драйвер БД | psycopg2-binary | 2.9.10 |
| Язык | Python | 3.12 |
| База (ОС) | Debian bookworm (slim) | 12.15 |
| Контейнеризация | Docker | 27.0.3 |
| Оркестрация | Kubernetes (Minikube) | v1.30.0 |
| CNI | Calico | v3.27 |
| Сканер безопасности | Trivy | 0.74.0 |
| CI/CD | GitHub Actions | ubuntu-latest |

---

## 3. Структура проекта

```
k8s-security-networking/
├── .github/
│   └── workflows/
│       └── security.yml          # CI/CD с Trivy
├── k8s/
│   ├── namespace.yaml            # Namespace + PSA лейблы (restricted)
│   ├── serviceaccount.yaml       # ServiceAccount для Flask
│   ├── role.yaml                 # Role (чтение pods/services)
│   ├── rolebinding.yaml          # RoleBinding для ServiceAccount
│   ├── postgres-deploy.yaml      # Deployment PostgreSQL (с PGDATA)
│   ├── postgres-svc.yaml         # Service PostgreSQL
│   ├── flask-deploy.yaml         # Deployment Flask (с SecurityContext)
│   ├── flask-svc.yaml            # Service Flask (NodePort)
│   └── network-policies/
│       ├── default-deny-ingress.yaml
│       ├── allow-flask-to-db.yaml
│       ├── flask-egress.yaml
│       └── allow-ingress-to-flask.yaml
├── app.py                        # Flask-приложение
├── Dockerfile                    # Многостадийная сборка (Debian bookworm)
├── requirements.txt              # Зависимости Python
├── .dockerignore                 # Исключения для Docker
├── .gitignore                    # Исключения для Git
├── .trivyignore                  # Игнорируемые CVE
└── README.md                     # Этот файл
```

---

## 4. Требования

- Docker (версия 23.0 или выше)
- Minikube (для локального Kubernetes-кластера)
- kubectl (для управления кластером)
- Trivy (устанавливается через `brew install trivy` или `apt`)
- Git (для клонирования)

---

## 5. Быстрый старт (локально)

**Клонируйте репозиторий:**
```bash
git clone https://github.com/<ваш-username>/k8s-security-networking.git
cd k8s-security-networking
```

**Соберите Docker-образ:**
```bash
eval $(minikube docker-env)
docker build -t task-manager:latest .
```

**Запустите сканирование Trivy локально:**
```bash
trivy image --severity CRITICAL task-manager:latest
```

**Запустите контейнер для теста:**
```bash
docker run -d -p 5000:5000 --name task-manager task-manager:latest
curl http://localhost:5000/
# {"message":"Hello from Flask + PostgreSQL!","visits":1}
docker stop task-manager && docker rm task-manager
```

---

## 6. Запуск в Kubernetes (Minikube)

Проект включает полный набор манифестов для развертывания в Minikube.

**1. Запустите Minikube с поддержкой Network Policies:**
```bash
minikube start --cpus=4 --memory=8192 --cni=calico --driver=docker
```

**2. Соберите образ и примените манифесты:**
```bash
eval $(minikube docker-env)
docker build -t task-manager:latest .

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/role.yaml
kubectl apply -f k8s/rolebinding.yaml
kubectl apply -f k8s/postgres-deploy.yaml
kubectl apply -f k8s/postgres-svc.yaml
sleep 15
kubectl apply -f k8s/flask-deploy.yaml
kubectl apply -f k8s/flask-svc.yaml
kubectl apply -f k8s/network-policies/
```

**3. Проверьте статус:**
```bash
kubectl get pods -n task-manager
kubectl get svc -n task-manager
kubectl get networkpolicies -n task-manager
```

**4. Доступ к приложению (проброс порта):**
```bash
kubectl port-forward -n task-manager svc/flask-service 5000:5000
```

Откройте браузер: `http://localhost:5000`

---

## 7. API

### `GET /`
Возвращает приветствие и текущее количество визитов.

**Пример ответа:**
```json
{
  "message": "Hello from Flask + PostgreSQL!",
  "visits": 42
}
```

### `GET /health`
Проверяет состояние приложения и подключение к базе данных.

**Пример ответа (успех):**
```json
{
  "status": "healthy",
  "db": "connected"
}
```

**Пример ответа (ошибка):**
```json
{
  "status": "unhealthy",
  "db": "connection to server failed: Connection refused"
}
```

### `GET /tasks`
Возвращает список всех задач (демонстрация работы с БД).

---

## 8. Безопасность

В проекте применены следующие меры безопасности:

| Мера | Описание | Где применено |
|------|----------|---------------|
| Non-root пользователь | Приложение запускается от `appuser` (UID 1000) | `Dockerfile`, `k8s/flask-deploy.yaml` |
| Минимальный базовый образ | Использован `python:3.12-slim-bookworm` с минимумом пакетов | `Dockerfile` |
| Многостадийная сборка | Компиляторы и заголовки удалены из финального образа | `Dockerfile` |
| Seccomp профиль | Ограничение системных вызовов через `RuntimeDefault` | `k8s/flask-deploy.yaml`, `k8s/postgres-deploy.yaml` |
| Запрет повышения привилегий | `allowPrivilegeEscalation: false` | `k8s/*-deploy.yaml` |
| Read-only корневая ФС | `readOnlyRootFilesystem: true` (кроме PostgreSQL) | `k8s/flask-deploy.yaml` |
| Capabilities | Удалены все лишние capabilities (`drop: ["ALL"]`) | `k8s/*-deploy.yaml` |
| RBAC | Ограниченный доступ для ServiceAccount (только чтение pods/services) | `k8s/role.yaml` |
| Network Policies | БД изолирована от всего, кроме Flask; Flask ходит только к БД и DNS | `k8s/network-policies/` |
| PSA (restricted) | Запрет root, seccomp, отключение привилегий | `k8s/namespace.yaml` |

---

## 9. CI/CD: GitHub Actions

Проект использует GitHub Actions для автоматического сканирования безопасности.

**Что делает пайплайн (`.github/workflows/security.yml`):**

1. Клонирует репозиторий
2. Устанавливает Trivy последней версии
3. Собирает Docker-образ
4. Запускает сканирование Trivy (уязвимости, секреты)
5. Загружает отчет в формате SARIF в GitHub Security Tab
6. Блокирует пайплайн, если обнаружены уязвимости уровня `CRITICAL`
7. Сканирует Kubernetes-манифесты на наличие misconfigurations

**Файл пайплайна (`.github/workflows/security.yml`):**
```yaml
name: Security Scan

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

permissions:
  contents: read
  security-events: write

jobs:
  security-scan:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Install Trivy
      run: |
        sudo apt-get update
        sudo apt-get install -y wget
        wget https://github.com/aquasecurity/trivy/releases/download/v0.74.0/trivy_0.74.0_Linux-64bit.deb
        sudo dpkg -i trivy_0.74.0_Linux-64bit.deb
        trivy --version

    - name: Build Docker image
      run: docker build -t task-manager:${{ github.sha }} .

    - name: Run Trivy image scan (SARIF for GitHub Security)
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'task-manager:${{ github.sha }}'
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL'
        exit-code: '0'

    - name: Upload Trivy results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: 'trivy-results.sarif'

    - name: Run Trivy severity scan (fail on CRITICAL)
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'task-manager:${{ github.sha }}'
        format: 'table'
        severity: 'CRITICAL'
        exit-code: '1'

    - name: Scan Kubernetes manifests
      run: |
        trivy config --severity CRITICAL --exit-code 1 k8s/
```

**Для просмотра результатов:**
Перейдите на вкладку вашего репозитория на GitHub: `Security` → `Code scanning alerts`.

---

## 10. Результаты сканирования

После оптимизации Dockerfile (многостадийная сборка, удаление компиляторов и заголовков) количество уязвимостей значительно сократилось:

| Показатель | Исходно | После оптимизации |
|------------|---------|-------------------|
| Пакетов в образе | 178 | 109 |
| Уязвимостей всего | 299 | 31 |
| CRITICAL | 16 | 0 (игнорируются) |
| HIGH | 283 | 30 (не блокируют) |
| Размер образа | ~500 MB | ~150 MB |

**CRITICAL-уязвимости (не используемые в приложении) добавлены в `.trivyignore`:**

- CVE-2026-13221 (Perl)
- CVE-2026-42496 (Perl)
- CVE-2026-8376 (Perl)
- CVE-2023-45853 (zlib)
- CVE-2025-7458 (SQLite)

**HIGH-уязвимости** не блокируют пайплайн, так как они находятся в системных пакетах Debian и не эксплуатируемы в контексте приложения.

---

## 11. Автор

**denbotanin-source**

GitHub: [https://github.com/denbotanin-source](https://github.com/denbotanin-source)

---

*Проект выполнен в рамках курса по DevOps и Kubernetes Security.*
