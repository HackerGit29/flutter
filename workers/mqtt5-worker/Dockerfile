FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
RUN rm -f .env

# Cloudflare Containers route vers le port écouté par l'instance
# (defaultPort = 8080 dans worker.js). Le serveur de santé lit PORT ?? 8080.
ENV PORT=8080
EXPOSE 8080

USER node
CMD ["node", "index.js"]
