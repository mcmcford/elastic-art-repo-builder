# Elastic Artifact Registry Image Builder

This repository builds a container image that serves Elastic binary artifacts for air-gapped Elastic Agent upgrades and component installs.

The image:

- Downloads the Elastic artifacts for a selected stack version during the container build
- Serves them with NGINX on port `9080`
- Is pushed to your chosen OCI registry from a manually triggered GitLab pipeline
- Runs the NGINX process as the non-root `nginx` user

## Required GitLab CI/CD variables

- `REGISTRY_ENDPOINT`: Registry hostname, for example `registry.example.com`
- `REGISTRY_USERNAME`: Registry username
- `REGISTRY_PASSWORD`: Registry password
- `ELASTIC_STACK_VERSION`: Elastic version to download, for example `9.3.3`
- `TARGET_IMAGE_REPOSITORY`: Repository path in the registry, for example `platform/elastic-artifact-registry`

## Optional GitLab CI/CD variables

- `TARGET_IMAGE_TAG`: Image tag to use. Defaults to `ELASTIC_STACK_VERSION`
- `ARTIFACT_DOWNLOADS_BASE_URL`: Defaults to `https://artifacts.elastic.co/downloads`

## Running the pipeline

1. In GitLab, run a new pipeline manually from the UI or API.
2. Set or override the CI/CD variables for the target version and registry.
3. Start the `build_elastic_artifact_registry` manual job.

## Result

The pipeline pushes an image like:

`<REGISTRY_ENDPOINT>/<TARGET_IMAGE_REPOSITORY>:<TARGET_IMAGE_TAG>`

At runtime, the container serves the downloaded files from `/opt/elastic-packages` on port `9080`.

## Runtime hardening notes

- The image runs as the non-root `nginx` user.
- NGINX logs are written to stdout and stderr.
- The PID file and temporary paths are placed under `/tmp`.
- For stricter deployment hardening, prefer a read-only root filesystem with a writable `/tmp` mount.
