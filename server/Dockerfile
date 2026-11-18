FROM node:20-alpine
WORKDIR /app
COPY package.json arena-server.js ./
RUN mkdir -p /app/data
EXPOSE 51938
ENV PORT=51938
CMD ["node", "arena-server.js"]
