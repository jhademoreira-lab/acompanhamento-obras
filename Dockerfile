FROM nginx:alpine
COPY index.html sw.js /usr/share/nginx/html/
EXPOSE 80
