#!/bin/bash

DATASET=$1

function gdrive_download () {
	local gid="$1"
	local outfile="$2"

	if command -v gdown >/dev/null 2>&1; then
		gdown --id "$gid" -O "$outfile" --no-cookies >/dev/null 2>&1 || return 1
		return 0
	fi

	if command -v wget >/dev/null 2>&1; then
		CONFIRM=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate "https://docs.google.com/uc?export=download&id=$gid" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_-]+).*/\1\n/p' | head -n1)
		wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$CONFIRM&id=$gid" -O "$outfile" --no-check-certificate
		rm -rf /tmp/cookies.txt
	elif command -v curl >/dev/null 2>&1; then
		curl -s -c /tmp/cookies.txt "https://docs.google.com/uc?export=download&id=$gid" -o /tmp/gd_page.html
		CONFIRM=$(sed -rn 's/.*confirm=([0-9A-Za-z_-]+).*/\1\n/p' /tmp/gd_page.html | head -n1)
		if [ -n "$CONFIRM" ]; then
			curl -L -b /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$CONFIRM&id=$gid" -o "$outfile"
		else
			# Fallback endpoint that works for many public Google Drive files.
			curl -L "https://drive.usercontent.google.com/download?id=$gid&export=download&confirm=t" -o "$outfile"
		fi
		rm -f /tmp/gd_page.html
		rm -rf /tmp/cookies.txt
	else
		echo "Error: neither wget nor curl is installed."
		return 1
	fi

	# Guardrail: if Google returns an HTML warning page, stop early.
	if [ ! -f "$outfile" ] || [ ! -s "$outfile" ]; then
		echo "Downloaded file is empty: $outfile"
		return 1
	fi
	if head -c 512 "$outfile" | tr '[:upper:]' '[:lower:]' | grep -qE '<!doctype html|<html'; then
		echo "Downloaded content is HTML instead of dataset tar."
		echo "Tip: install gdown and rerun for reliable Google Drive download."
		return 1
	fi

	return 0
}

#Gdrive ID
Confocal_BPAE_B=1juaumcGn5QlFRXRQyrqfbZBhF7oX__iW
Confocal_BPAE_G=1Zofz11VmI1JfRIMF7rq40RVjpzM6A9vg
Confocal_BPAE_R=1QoD_vMvFdFg7yREfen3t-SGLFcnLg9YQ
Confocal_FISH=1SxmsythWfxnfKJfGWpT_7Adebi8jUK98
Confocal_MICE=11aflcrcatFRkv7EabjWjdlpT0DYRbUDZ

TwoPhoton_BPAE_B=1yVD_H_ZfNNSma5vtHZM_DTnSv1Bo1tfk
TwoPhoton_BPAE_G=125nqTfQQG1-YVUs256b2vTwt4aUNCgBt
TwoPhoton_BPAE_R=1rwxG6LYcKeiBKNT3Oq9lvwKu8mV3rz9P
TwoPhoton_MICE=1lhsFAlXsXk26yqHzT0_-3R8MUb7G0NVa

WideField_BPAE_B=19rl8zFzfXIZ2drgodCGutLPLzL4kJq6d
WideField_BPAE_G=1H67O6GqIkIlQSX-n0vfMWGPwmd4zOHQr
WideField_BPAE_R=19HXb2Ftrb-M7Lr9ZlHWMcnNT0Sbu85YL

test_mix=13bAS6Ipuk2xZkF99FTdanJ3fenvA3QDj

TARGET_DIR=./dataset
mkdir -p $TARGET_DIR


if [ -z "$DATASET" ]; then
		folders=(Confocal_BPAE_B Confocal_BPAE_G Confocal_BPAE_R Confocal_FISH Confocal_MICE 
			  TwoPhoton_BPAE_B TwoPhoton_BPAE_G TwoPhoton_BPAE_R TwoPhoton_MICE 
			  WideField_BPAE_B WideField_BPAE_G WideField_BPAE_R test_mix)
   else
   		case $DATASET in
   			"confocal"|"Confocal" )
				folders=(Confocal_BPAE_B Confocal_BPAE_G Confocal_BPAE_R Confocal_FISH Confocal_MICE)
				if [ ! -d "./dataset/test_mix" ]; then
  					folders=(Confocal_BPAE_B Confocal_BPAE_G Confocal_BPAE_R Confocal_FISH Confocal_MICE  test_mix)
				fi
   				;;
   			"twophoton"|"TwoPhoton")
				folders=(TwoPhoton_BPAE_B TwoPhoton_BPAE_G TwoPhoton_BPAE_R TwoPhoton_MICE)
				if [ ! -d "./dataset/test_mix" ]; then
  					folders=(TwoPhoton_BPAE_B TwoPhoton_BPAE_G TwoPhoton_BPAE_R TwoPhoton_MICE test_mix)
				fi
				;;
			"widefield"|"WideField")
				folders=(WideField_BPAE_B WideField_BPAE_G WideField_BPAE_R)
				if [ ! -d "./dataset/test_mix" ]; then
  					folders=(WideField_BPAE_B WideField_BPAE_G WideField_BPAE_R test_mix)
				fi
				;;
   		esac
fi


for id in ${folders[*]} 
do
	echo "Downloading dataset ${id}..."
	GDRIVE_ID=${!id}
	TAR_FILE=./dataset/${id}.tar
	gdrive_download "$GDRIVE_ID" "$TAR_FILE" || { echo "Download failed for ${id}"; exit 1; }
	if [ ! -f "$TAR_FILE" ]; then
		echo "Download did not create file: ${TAR_FILE}"
		exit 1
	fi
	echo "Extracting files from ${TAR_FILE}..."
	tar -xf "$TAR_FILE" -C "$TARGET_DIR"
	while [ ! -d "./dataset/${id}" ]; do
		echo "Seems the tar file is wrong, download again..."
		gdrive_download "$GDRIVE_ID" "$TAR_FILE" || { echo "Retry download failed for ${id}"; exit 1; }
		echo "Extracting files from ${TAR_FILE}..."
		tar -xf "$TAR_FILE" -C "$TARGET_DIR" || { echo "Extract failed for ${TAR_FILE}"; exit 1; }
	done
	rm "$TAR_FILE"
done

