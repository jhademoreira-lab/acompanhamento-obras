FROM nginx:alpine
COPY index.html sw.js supabase.js /usr/share/nginx/html/
EXPOSE 80
