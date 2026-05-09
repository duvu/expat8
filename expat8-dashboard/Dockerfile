FROM node:22-alpine AS base
WORKDIR /app

FROM base AS deps
COPY package.json package-lock.json ./
RUN npm ci

FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
# Copy the entire build output — newer Next.js versions place standalone files
# under .next/app instead of .next/standalone. Using `next start` is the
# simplest compatible runtime for the built output.
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
# package.json is needed at runtime for `npm run start` to read the start script
COPY --from=builder /app/package.json ./
COPY --from=builder /app/package-lock.json ./
COPY --from=builder /app/node_modules ./node_modules
EXPOSE 3000
CMD ["npm", "run", "start"]
