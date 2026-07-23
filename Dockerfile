FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY backend/package*.json ./backend/

# Install dependencies
RUN npm install
RUN cd backend && npm install --production=false

# Copy project files
COPY . .

# Generate Prisma Client
RUN npx prisma generate --schema=backend/prisma/schema.prisma

# Expose port
EXPOSE 3000

ENV NODE_ENV=production

CMD ["node", "start.js"]
