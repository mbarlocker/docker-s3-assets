#!/bin/bash
set -Eeuo pipefail

APP_USER=app
APP_GROUP=app

source "${HOME}/.bashnvm"
source "/env.sh"

: "${BUCKET:?No S3 bucket specified. Set BUCKET environment to start.}"
: "${PROFILE:?No AWS profile specified. Set PROFILE environment to start.}"

ROOT="/app"
MIRROR="${ROOT}/mirror"
UPLOAD="${ROOT}/upload"

mkdir -p "${MIRROR}" "${UPLOAD}"
chown "${APP_USER}:${APP_GROUP}" "${MIRROR}" "${UPLOAD}"

find "${UPLOAD}" -mindepth 1 -type d -empty -delete
chown -R "${APP_USER}:${APP_GROUP}" "${UPLOAD}"

download() {
	echo "syncing ${BUCKET} to ${MIRROR}"
	aws --profile "${PROFILE}" s3 sync --delete "s3://${BUCKET}/" "${MIRROR}/"

	echo "copying directories ${MIRROR} to ${UPLOAD}"
	rsync -av -f '+ */' -f '- *' "${MIRROR}/" "${UPLOAD}/"
}

upload() {
	while true; do
		FOUND=

		while IFS= read -r -d '' LOCAL; do
			FILE="$(basename "${LOCAL}")"
			EXT="${FILE##*.}"

			if [[ -z "${FILE}" ]]; then
				continue
			fi

			if [[ "${EXT}" == "${FILE}" ]]; then
				echo "Skipping file without extension ${LOCAL}"
				continue
			fi

			echo "Minifying ${LOCAL}"

			case "${FILE,,}" in
				*.png | *.jpeg | *.jpg | *.bmp | *.gif )
					./node_modules/optipng-bin/cli.js -o4 "${LOCAL}"
					;;
				*.svg )
					./node_modules/svgo/bin/svgo --multipass -p 4 "${LOCAL}"
					;;
				* )
					echo "unminified extension ${LOCAL}"
					;;
			esac

			HASH="$(md5sum "${LOCAL}" | awk '{ print $1; }')"
			LOCAL_HASH="$(dirname "${LOCAL}")/$(basename "${LOCAL}" ".${EXT}").${HASH}.${EXT}"

			aws --profile "${PROFILE}" \
				s3 mv \
				--cache-control 'public, max-age=31536000, immutable' \
				"${LOCAL}" \
				"s3://${BUCKET}/${LOCAL_HASH#"${UPLOAD}/"}"

			FOUND=1
		done < <(find "${UPLOAD}" -type f -print0)

		if [[ -n "${FOUND}" ]]; then
			echo 'Resync local mirror'
			download
		fi

		sleep 1
	done
}

cd "${ROOT}"

if ! nvm use >/dev/null 2>&1; then
	nvm install
	nvm use
fi

corepack enable
yarn install

download || echo 'Initial sync failed!' >&2
upload &

yarn dev
