#!/usr/bin/env bash

ARCHIVE_NAME="hoverfly_bundle_linux_amd64.zip"

HF_VERSION=$(curl -s https://api.github.com/repos/spectolabs/hoverfly/releases/latest | grep tag_name | sed -n 's/.*"tag_name": "\(.*\)",/\1/p')
if [[ $?  == 1 ]]; then
    error_exit "Failed to get latest release version"
fi

HF_DOWNLOAD_URL="https://github.com/SpectoLabs/hoverfly/releases/download/${HF_VERSION}"

wget -O /tmp/hoverfly.zip ${HF_DOWNLOAD_URL}/${ARCHIVE_NAME}
if [[ $?  == 1 ]]; then
    error_exit "Failed to download hoverfly release package"
fi

rm -f hoverfly
unzip -p /tmp/hoverfly.zip hoverfly > hoverfly
rm /tmp/hoverfly.zip

function error_exit
{
	echo "$1" 1>&2
	exit 1
}