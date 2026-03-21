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
# 复制所有文件（包含 api 或 api @ xxx）
COPY . .

# 统一重命名
RUN if [ -d "api" ]; then \
      echo "✅ found api"; \
    elif ls -d api\ @* 1>/dev/null 2>&1; then \
      mv api\ @* api; \
    else \
      echo "❌ api 目录不存在"; \
      exit 1; \
    fi

# 验证
RUN ls -la /app/api
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
