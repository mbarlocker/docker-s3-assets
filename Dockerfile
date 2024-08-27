FROM mbarlocker/docker-typescript-dev:latest

ENV TZ="UTC"
ARG DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y tzdata ca-certificates rsync awscli \
    && rm -rf /var/lib/apt/lists/

COPY app /app
RUN mkdir -p /app/mirror /app/upload \
    && chown -R app:app /app

WORKDIR /app
VOLUME ["/home/app/.aws", "/app/mirror", "/app/upload"]
EXPOSE 9000

COPY entry.sh /startup/app/999-app
COPY env.sh /env.sh
