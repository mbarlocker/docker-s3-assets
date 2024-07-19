# Docker Typescript Dev

[![Docker Image Publish](https://github.com/mbarlocker/docker-s3-assets/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/mbarlocker/docker-s3-assets/actions/workflows/docker-publish.yml)

## Contents

This repo builds a Docker container. The purpose of this container is to sync assets to/from S3 and provide a local HTTP mirror of S3 for offline development.

There are two directories that you'll probably want to have as volumes:

* The `/app/upload` directory is where you'll put files (logo.png) that you'd like to have sent to S3. These files will be minified, renamed to include an md5 hash, and uploaded with public, yearlong cache control.
* The `/app/mirror` directory is where the local mirror is served from. This is helpful during local development to browse the contents of your static files without querying S3.

Since we're using S3, you'll also need to provide the AWS profile to use in the script.

It's built on [mbarlocker/docker-typescript-dev](https://github.com/mbarlocker/docker-typescript-dev) which needs some environment variables to run. See that project for details.

## Usage

First, follow instructions to get [mbarlocker/docker-typescript-dev](https://github.com/mbarlocker/docker-typescript-dev) to work.

Second, create a script `env.sh` to put environment variables into. It **will not work** without putting these in a separate file.
Using [mbarlocker/docker-typescript-dev](https://github.com/mbarlocker/docker-typescript-dev) means environment variables are lost when uid/gid are switched.

```bash
#!/bin/bash
BUCKET="mybucket"
PROFILE="myprofile"
```

Finally, use `docker` or `docker compose` to put everything in place. This `docker-compose.yaml` is placed in the root of your application.

```yaml
services:
  myapp:
    image: mbarlocker/docker-s3-assets:latest
    environment:
      DOCKER_UID: "${DOCKER_UID}"
      DOCKER_GID: "${DOCKER_GID}"
    volumes:
      - ./mirror:/app/mirror
      - ./upload:/app/upload
      - $HOME/.aws:/home/app/.aws
```

## Docker Hub

Find the docker image on Docker Hub: [Docker Typescript Dev](https://hub.docker.com/r/mbarlocker/docker-s3-assets)

![Image pushed to Docker Hub](https://raw.githubusercontent.com/mbarlocker/docker-s3-assets/main/images/image-pushed-to-docker-hub.png)

## License

[MIT](https://choosealicense.com/licenses/mit/)
