# Innovatech — Frontend Despacho - Funcionamiento en rama DEPLOY

Aplicación web (SPA) de la marca Despacho de **Innovatech Chile**, construida con React + Vite y servida en producción por Nginx dentro de un contenedor Docker.

Forma parte del proyecto de **Evaluación Parcial N°2 — Introducción a Herramientas DevOps (ISY1101)**.

## Arquitectura general

```
┌────────────────────┐         ┌────────────────────┐         ┌────────────────────┐
│  EC2 Frontend       │  HTTPS │  EC2 Back-Despachos │  JDBC  │     AWS RDS         │
│  (pública, :80)     │ ─────► │  (privada, :8081)   │ ─────► │     MySQL           │
│  nginx + SPA        │        │  Spring Boot        │        └────────────────────┘
└────────────────────┘        └────────────────────┘                  ▲
         │                                                            │
         │                    ┌────────────────────┐                  │
         └─────────────────►  │  EC2 Back-Ventas    │ ─────────────────┘
                              │  (privada, :8080)   │
                              │  Spring Boot        │
                              └────────────────────┘


## Estructura del repositorio

```
front_despacho/
├── src/                          # Código React
│   ├── componentes/              # Layouts y CRUD admin
│   ├── Routes/                   # AppRoutes.jsx
│   ├── assets/
│   └── main.jsx
├── public/
├── Dockerfile                    # Multi-stage: node → nginx
├── nginx.conf                    # Configuración SPA (try_files index.html)
├── docker-compose.deploy.yml     # Compose de PRODUCCIÓN (EC2)
├── .dockerignore
├── .github/
│   └── workflows/
│       └── deploy.yml            # Pipeline CI/CD
├── package.json
├── vite.config.js
├── tailwind.config.js
└── README.md
```

---

## Ejecución local sin Docker

```bash
npm install
npm run dev
```

La app queda en http://localhost:5173.

---

## Ejecución local con Docker

```bash
docker build -t innovatech-frontend:dev .
docker run --rm -p 8080:80 innovatech-frontend:dev
```

Abrir http://localhost:8080.

Para levantar **todo el stack** (frontend + 2 backends + MySQL) usar el `docker-compose.yml` de la raíz del proyecto (`proyecto semestral/docker-compose.yml`).

---

## Build de la imagen

El [Dockerfile](./Dockerfile) está dividido en dos etapas:

| Etapa | Imagen base | Resultado |
|---|---|---|
| `builder` | `node:20-alpine` | Compila Vite y genera `/app/dist` |
| `runtime` | `nginx:1.27-alpine` | Sirve `/app/dist` con Nginx como usuario `nginx` (no-root) |

La imagen final pesa ~25 MB porque no incluye Node, `node_modules` ni el código fuente — solo el bundle estático.


## Pipeline CI/CD (GitHub Actions)

Archivo: [.github/workflows/deploy.yml](./.github/workflows/deploy.yml)

**Trigger:** `push` a la rama `deploy`.

**Pasos del workflow:**

1. **Checkout** del código
2. **Login a Docker Hub** usando `DOCKERHUB_USERNAME` + `DOCKERHUB_TOKEN`
3. **Setup Buildx** (para caché remota de capas)
4. **Build y Push** con dos tags:
   - `latest` (móvil, siempre apunta al último deploy)
   - `${{ github.sha }}` (inmutable, permite rollback exacto)
5. **SSH a la EC2** y ejecuta:
   ```bash
   docker compose -f docker-compose.deploy.yml pull
   docker compose -f docker-compose.deploy.yml up -d --remove-orphans
   docker image prune -f
   ```

### Secrets necesarios

Configurarlos en **Settings → Secrets and variables → Actions**:

| Secret | Descripción |
|---|---|
| `DOCKERHUB_USERNAME` | Usuario de Docker Hub |
| `DOCKERHUB_TOKEN` | Access Token (NO la contraseña) |
| `EC2_FRONT_HOST` | IP pública o DNS de la EC2 del frontend |
| `EC2_USER` | `ubuntu` (Ubuntu AMI) o `ec2-user` (Amazon Linux) |
| `EC2_SSH_KEY` | Contenido del `.pem` (incluye `-----BEGIN/END-----`) |

---

## Despliegue en AWS EC2

### 1. Preparar la EC2 (una sola vez)

```bash
sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker

mkdir -p ~/innovatech-frontend
cd ~/innovatech-frontend
# Subir manualmente docker-compose.deploy.yml o clonar el repo:
# git clone <repo> .
```

### 2. Security Group de la EC2 Frontend

| Puerto | Origen | Justificación |
|---|---|---|
| 80 | 0.0.0.0/0 | Acceso público a la SPA |
| 22 | Tu IP fija | SSH limitado |

### 3. Disparar el despliegue

```bash
git checkout -b deploy
git push origin deploy
```

GitHub Actions construye, sube a Docker Hub y reinicia el contenedor en la EC2. La app queda accesible en `http://<IP-pública-EC2>`.

## Información del curso

| | |
|---|---|
| Asignatura | ISY1101 — Introducción a Herramientas DevOps |
| Evaluación | EP2 (30%) |
| Institución | Duoc UC |
| Año | 2025 |
