#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (c) 2013-2024 Igor Pecovnik, igor@armbian.com
# Copyright (c) 2024 Armbian contributors
#
# This file is a part of the Armbian Build Framework
# https://github.com/armbian/build/

function output_images_compress_and_checksum() {
	# Skip if SEND_TO_SERVER is set (implies different handling)
	[[ -n $SEND_TO_SERVER ]] && return 0

	# Check that 'version' is set (required for context, though not directly used here)
	[[ -z $version ]] && exit_with_error "Internal error: 'version' is not set in compress-checksum context"

	# Input: prefix for image files (e.g., "output/images/Armbian_${version}_boardname_branch_")
	declare prefix_images="${1}"
	# Find all files that match the prefix
	declare -a images=("${prefix_images}"*)
	# If no files match the prefix, warn and exit the function
	if [[ ${#images[@]} -eq 0 ]]; then
		display_alert "No files found matching prefix to compress/checksum" "${prefix_images}*" "wrn"
		return 0
	fi

	# Loop over all found files
	for uncompressed_file in "${images[@]}"; do
		# Skip symlinks
		[[ -L "${uncompressed_file}" ]] && continue
		# Skip directories or anything that isn't a regular file
		[[ ! -f "${uncompressed_file}" ]] && continue
		# Skip checksum files or other text files explicitly
		[[ "${uncompressed_file}" == *.sha || "${uncompressed_file}" == *.sha256 || "${uncompressed_file}" == *.md5 || "${uncompressed_file}" == *.txt ]] && continue

		# Get just the filename, sans path
		declare uncompressed_file_basename
		uncompressed_file_basename=$(basename "${uncompressed_file}")

		# --- Compression Settings ---
		# Read compression levels from environment or use defaults
		# XZ: Level 1-9. Default 1 (fastest). Higher uses more RAM/CPU.
		declare xz_compression_ratio_image="${IMAGE_XZ_COMPRESSION_RATIO:-"1"}"
		# ZSTD: Level 1-19 (or higher with --ultra). Default 3 (good balance).
		declare zstd_compression_ratio_image="${IMAGE_ZSTD_COMPRESSION_RATIO:-"3"}"

		# Variable to store the extension of the compressed file (e.g., ".xz", ".zst")
		# Reset for each file in the loop
		declare compression_type=""
		# Variable to store the full path of the file *after* potential compression
		declare final_file_path="${uncompressed_file}" # Assume original initially

		# --- Compression Logic ---
		# Process only *one* compression type if specified in COMPRESS_OUTPUTIMAGE.
		# xz takes precedence over zst if both happen to be listed.
		if [[ $COMPRESS_OUTPUTIMAGE == *xz* ]]; then
			display_alert "Compressing with xz" "${uncompressed_file_basename} -> ${uncompressed_file_basename}.xz" "info"
			# Use xz: -T0 for multi-threading, level from variable.
			# xz deletes the source file by default on success.
			if xz -T 0 "-${xz_compression_ratio_image}" "${uncompressed_file}"; then
				compression_type=".xz"
				final_file_path="${uncompressed_file}${compression_type}"
			else
				display_alert "xz compression failed" "${uncompressed_file_basename}" "err"
				# Keep the original file if compression fails, skip checksumming it
				continue
			fi
		elif [[ $COMPRESS_OUTPUTIMAGE == *zstd* ]]; then
			# Check if zstd command exists
			if command -v zstd &> /dev/null; then
				display_alert "Compressing with zstd" "${uncompressed_file_basename} -> ${uncompressed_file_basename}.zst" "info"
				# Use zstd: -T0 for multi-threading, --rm to delete original, level from variable.
				if zstd -T0 --rm "-${zstd_compression_ratio_image}" "${uncompressed_file}"; then
					compression_type=".zst"
					final_file_path="${uncompressed_file}${compression_type}"
				else
					display_alert "zstd compression failed" "${uncompressed_file_basename}" "err"
					# Keep the original file if compression fails, skip checksumming it
					continue
				fi
			else
				display_alert "zstd command not found" "Skipping zstd compression for ${uncompressed_file_basename}" "err"
				# Keep the original file, but don't attempt checksum if compression was intended but failed due to missing tool
				continue
			fi
		fi # End of compression type checks

		# --- Checksum Logic ---
		if [[ $COMPRESS_OUTPUTIMAGE == *sha* ]]; then
			# Check if the file we intend to checksum actually exists
			# (It might not if compression failed above)
			if [[ -f "${final_file_path}" ]]; then
				display_alert "SHA256 calculating" "$(basename "${final_file_path}")" "info"
				# Use sha256sum -b for binary mode.
				# awk manipulation removes the temporary path, leaving only the filename in the .sha file.
				if sha256sum -b "${final_file_path}" | awk '{split($2, a, "/"); print $1, a[length(a)]}' > "${final_file_path}".sha; then
					: # Checksum successful
				else
					display_alert "SHA256 calculation failed" "$(basename "${final_file_path}")" "err"
				fi
			else
				# This case should ideally not be reached if logic above is correct, but good to have a fallback.
				display_alert "File not found for SHA calculation" "$(basename "${final_file_path}") (was compression skipped or failed?)" "err"
			fi
		fi # End of checksum check

	done # End loop over files

} # End function output_images_compress_and_checksum
