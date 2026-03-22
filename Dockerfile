# Stage 1: Build Frontend
FROM node:20-alpine AS frontend-builder
WORKDIR /app
COPY package*.json ./
# Remove electron and electron-builder from package.json
RUN node -e "const fs = require('fs'); const filePath = './package.json'; \
             let rawdata = fs.readFileSync(filePath); let packageJson = JSON.parse(rawdata); \
             if (packageJson.devDependencies) { \
               delete packageJson.devDependencies.electron; \
               delete packageJson.devDependencies['electron-builder']; \
             } \
             if (packageJson.dependencies) { \
               delete packageJson.dependencies.electron; \
             } \
             fs.writeFileSync(filePath, JSON.stringify(packageJson, null, 2));"
RUN npm install
COPY . .
RUN npm run build:docker

# Stage 2: Setup Combined App
FROM node:20-alpine
WORKDIR /app

# Install Nginx
RUN apk add --no-cache nginx

# Copy API code
# Clone API submodule if not present
# 如果本地 api/ 为空（子模块未下载），则从远程克隆
COPY ./api ./api_temp
RUN if [ "$(ls -A ./api_temp)" ]; then \
        mv ./api_temp ./api; \
    else \
        rm -rf ./api_temp && \
        git clone --depth 1 https://github.com/MakcRe/KuGouMusicApi ./api; \
    fi
# Install API dependencies
WORKDIR /app/api
RUN npm install --production
# Reset WORKDIR to /app
WORKDIR /app 
RUN ls -la 
# Copy built frontend static assets from the builder stage
COPY --from=frontend-builder /app/dist/ ./dist/

# Expose ports
# For frontend served by 'serve'
EXPOSE 8080 
# For API
EXPOSE 6521 

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Command to run both services
# API runs from /app/api directory, frontend served by Nginx
# CMD ["sh", "-c", "cd /app/api && node app.js & nginx -g 'daemon off;'"]
CMD sh -c "\
  echo 'client running @ http://127.0.0.1:8080/'; \
  cd /app/api && node app.js & nginx -g 'daemon off;'"
