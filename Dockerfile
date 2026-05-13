# ============================================
# Etapa 1: Build de la aplicación React/Vite
# ============================================
FROM node:20-alpine AS builder

WORKDIR /app

# Copiamos manifiestos primero para cachear la capa de dependencias
COPY package*.json ./
RUN npm ci

# Copiamos el resto del código y construimos la SPA (genera /app/dist)
COPY . .
RUN npm run build

# ============================================
# Etapa 2: Imagen final (nginx sirviendo el dist)
# ============================================
FROM nginx:1.27-alpine AS runtime

# Copiamos configuración personalizada de nginx (soporta SPA / React Router)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copiamos solo el bundle estático desde la etapa de build
COPY --from=builder /app/dist /usr/share/nginx/html

# Ejecutar como usuario no-root (mínimo privilegio)
# La imagen oficial trae el usuario 'nginx' (uid 101). Le damos permiso sobre lo necesario.
RUN chown -R nginx:nginx /usr/share/nginx/html \
 && chown -R nginx:nginx /var/cache/nginx \
 && chown -R nginx:nginx /var/log/nginx \
 && touch /var/run/nginx.pid \
 && chown -R nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
