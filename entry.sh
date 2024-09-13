#!/bin/bash
set -e
source ~/.bashnvm
source /env.sh

if [[ -z "${BUCKET}" ]]; then
	echo 'No S3 bucket specified. Set BUCKET environment to start.'
	exit 1
fi

if [[ -z "${PROFILE}" ]]; then
	echo 'No AWS profile specified. Set PROFILE environment to start.'
	exit 1
fi

ROOT="/app"
MIRROR="${ROOT}/mirror"
UPLOAD="${ROOT}/upload"

mkdir -p "${MIRROR}"

if [[ -d "${UPLOAD}" ]]; then
	# delete empty directories
	find "${UPLOAD}" -mindepth 1 -type d -empty ! -delete
else
	mkdir -p "${UPLOAD}"
fi

download() {
	echo "syncing ${BUCKET} to ${MIRROR}"
	aws --profile "${PROFILE}" s3 sync --delete "s3://${BUCKET}/" "${MIRROR}/"

	echo "copying directories ${MIRROR} to ${UPLOAD}"
	rsync -av -f"+ */" -f"- *" "${MIRROR}/" "${UPLOAD}/"
}

upload() {
	while true; do
		FOUND=

		# piped from find
		while read LOCAL; do
			FILE="$(basename "${LOCAL}")"
			EXT="${FILE##*.}"

			if [[ -z "${FILE}" ]]; then
				continue
			fi

			if [[ "${EXT}" = "${FILE}" ]]; then
				echo "Skipping file without extension ${LOCAL}"
				continue
			fi

			echo "Minifying ${LOCAL}"

			case "$(echo "${FILE}" | tr '[:upper:]' '[:lower:]')" in
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

			aws --profile "${PROFILE}" s3 mv --cache-control 'public, max-age=31536000, immutable' "${LOCAL}" "s3://${BUCKET}/${LOCAL_HASH#*/}"

			FOUND=1
		done <<< "$(find "$(basename "${UPLOAD}")" -type f)"

		if [[ -n "${FOUND}" ]]; then
			echo 'Resync local mirror'
			download
		fi

		sleep 1
	done
}

set -e

cd "${ROOT}"
if ! ( nvm use 2>/dev/null ); then
	nvm install
	nvm use
fi
corepack enable
yarn install

download || echo 'Initial sync failed!' >&2
upload &

yarn dev
