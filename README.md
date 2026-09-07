# Elastic Artifact Registry Image Builder

This repository builds a container image that serves Elastic binary artifacts for air-gapped Elastic Agent upgrades and component installs.

The image:

- Downloads the Elastic artifacts for a selected stack version during the container build
- Serves them with NGINX on port `9080`
- Is pushed to your chosen OCI registry from a manually triggered GitHub Actions workflow
- Runs the NGINX process as the non-root `nginx` user

## GitHub Container Registry

The workflow publishes to GitHub Container Registry (`ghcr.io`) using the built-in `GITHUB_TOKEN`; no registry secrets are required. The package is published as:

`ghcr.io/<GITHUB_OWNER>/elastic-artifact-registry:<TAG>`

## Workflow inputs

- `elastic_stack_version`: Elastic version to download. Defaults to `9.3.3`.
- `target_image_repository`: Repository path in the registry. Defaults to `elastic-artifact-registry`.
- `target_image_tag`: Image tag. Defaults to `elastic_stack_version`.
- `artifact_downloads_base_url`: Defaults to `https://artifacts.elastic.co/downloads`.

## Running the pipeline

1. Ensure the repository Actions setting permits workflows to read and write packages.
2. Open **Actions → Build Elastic Artifact Registry → Run workflow**.
3. Set or override the workflow inputs and start the workflow.

## Result

The pipeline pushes an image like:

`ghcr.io/<GITHUB_OWNER>/<TARGET_IMAGE_REPOSITORY>:<TARGET_IMAGE_TAG>`

At runtime, the container serves the downloaded files from `/opt/elastic-packages` on port `9080`.

## Runtime hardening notes

- The image runs as the non-root `nginx` user.
- NGINX logs are written to stdout and stderr.
- The PID file and temporary paths are placed under `/tmp`.
- For stricter deployment hardening, prefer a read-only root filesystem with a writable `/tmp` mount.
