# One-URL image: the API plus the Flutter web build, served from /.
# Build the web app first, then build this image from the repo root:
#   flutter build web --dart-define=API_BASE=<the-public-url>
#   docker build -f backend/Dockerfile -t resonant .
#   docker run -p 3000:3000 -e MODEL_API_KEY=... resonant
# Runs on Fly.io, Railway, or any VPS with Docker.
FROM node:20-slim
WORKDIR /app/backend
COPY backend/package.json backend/package-lock.json ./
RUN npm install --omit=dev
COPY backend/ ./
COPY build/web/ ../build/web/
ENV NODE_ENV=production PORT=3000
EXPOSE 3000
CMD ["npm", "start"]
