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
RUN apk add --no-cache nginx iproute2

# Copy API code
COPY ./api ./api
# Install API dependencies
WORKDIR /app/api
RUN ls -la 
RUN npm install --production
# Reset WORKDIR to /app
WORKDIR /app 

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
# 替换第 51-53 行的 CMD
CMD sh -c "\
  echo 'Starting API server...'; \
  cd /app/api && node app.js --platform=lite --port=6521 > /app/api.log 2>&1 & \
  echo 'Starting Nginx...'; \
  echo 'client running @ http://127.0.0.1:8080/'; \
  nginx -g 'daemon off;'"

