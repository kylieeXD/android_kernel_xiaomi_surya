#!/bin/bash
SECONDS=0
set -e

# Set kernel path
KERNEL_PATH="out/arch/arm64/boot"

# Set kernel file
OBJ="${KERNEL_PATH}/Image"
GZIP="${KERNEL_PATH}/Image.gz"
CAT="${KERNEL_PATH}/Image.gz-dtb"

# Set dts file
DTB="${KERNEL_PATH}/dtb.img"
DTBO="${KERNEL_PATH}/dtbo.img"

# Set kernel name
BUILD_TYPE="BETA"
DATE="$(TZ=Asia/Jakarta date +%Y%m%d%H%M%S)"
KERNEL_NAME="rethinking${BUILD_TYPE}-${DATE}.zip"

# Clone SukiSU repo
if [ ! -d "KernelSU" ]; then curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-main; fi

function KERNEL_COMPILE() {
	if [ "$1" == "install" ]; then
		# Download required package
		sudo apt update -y && sudo apt upgrade -y && sudo apt install nano bc ccache bison ca-certificates curl flex gcc git libc6-dev libssl-dev openssl python-is-python3 ssh wget zip zstd sudo make clang gcc-arm-linux-gnueabi software-properties-common build-essential libarchive-tools gcc-aarch64-linux-gnu -y && sudo apt install build-essential -y && sudo apt install libssl-dev libffi-dev libncurses5-dev zlib1g zlib1g-dev libreadline-dev libbz2-dev libsqlite3-dev make gcc -y && sudo apt install pigz -y && sudo apt install python2 -y && sudo apt install python3 -y && sudo apt install cpio -y && sudo apt install lld -y && sudo apt install llvm -y && sudo apt-get install g++-aarch64-linux-gnu -y && sudo apt install libelf-dev -y && sudo apt install neofetch -y && neofetch
	fi

	# Set environment variables
	export USE_CCACHE=1
	export KBUILD_BUILD_HOST=builder
	export KBUILD_BUILD_USER=khayloaf

	# Create output directory and do a clean build
	rm -rf out && mkdir -p out

	# Download clang if not present
	if [[ ! -d "clang" ]]; then mkdir -p clang
		wget https://github.com/Impqxr/aosp_clang_ci/releases/download/13289611/clang-13289611-linux-x86.tar.xz -O clang.tar.gz
		tar -xf clang.tar.gz -C clang && if [ -d clang/clang-* ]; then mv clang/clang-*/* clang; fi && rm -rf clang.tar.gz
	fi

	# Add clang bin directory to PATH
	export PATH="${PWD}/clang/bin:$PATH"

	# Make the config
	make O=out ARCH=arm64 surya_defconfig

	# Build the kernel with clang and log output
	make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 2>&1 | tee -a out/compile.log
}

function KERNEL_RESULT() {
	# Check if build is successful
	if [ ! -f "$GZIP" ] || [ ! -f "$DTB" ] || [ ! -f "$DTBO" ]; then
		exit 1
	fi

	# Cat Image
	cat "$GZIP" "$DTB" > "$CAT"

	# Create anykernel
	rm -rf anykernel
	git clone https://github.com/khayloaf/AK3-Surya anykernel

	# Copying image
	cp "$CAT" anykernel/kernels/
	cp "$DTBO" anykernel/kernels/

	# Created zip kernel
	cd anykernel && zip -r9 "${KERNEL_NAME}" *

	# Upload kernel
	RESPONSE=$(curl -s -F "file=@${KERNEL_NAME}" "https://store1.gofile.io/contents/uploadfile" \
	|| curl -s -F "file=@${KERNEL_NAME}" "https://store2.gofile.io/contents/uploadfile")
	DOWNLOAD_LINK=$(echo "$RESPONSE" | grep -oP '"downloadPage":"\K[^"]+')
	echo -e "\nDownload link: $DOWNLOAD_LINK"
}

# Run functions
KERNEL_COMPILE "$1"
KERNEL_RESULT
echo -e "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !\n"
