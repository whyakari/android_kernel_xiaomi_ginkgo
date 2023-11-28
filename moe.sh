#!/bin/bash
#
# Compile script for MoeKernel🐇
# Copyright (C) 2020-2021 Adithya R.

SECONDS=0 # builtin bash timer
ZIPNAME="Moe-$(date '+%Y%m%d').zip"
LINKER="ld.lld"
USE_LLVM=0
TC_DIR="$HOME/tc/clang-18.0.0"
GCC_64_DIR="$HOME/tc/aarch64-linux-android-14.0"
GCC_32_DIR="$HOME/tc/arm-linux-androideabi-14.0"
AK3_DIR="$HOME/android/AnyKernel3"
DEFCONFIG="vendor/moe_defconfig"

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" && head=$(git rev-parse --verify HEAD 2>/dev/null); then
    ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi

# export PATH="$TC_DIR/bin:$PATH"

export KBUILD_BUILD_USER=Moe
export KBUILD_BUILD_HOST=Nyan

if ! [ -d "${TC_DIR}" ]; then
    echo "Clang not found! Cloning to ${TC_DIR}..."
    if ! git clone --depth=1 https://gitlab.com/moehacker/clang-r498229b ${TC_DIR}; then
        echo "Cloning failed! Aborting..."
        exit 1
    fi
fi

if ! [ -d "${GCC_64_DIR}" ]; then
    echo "gcc not found! Cloning to ${GCC_64_DIR}..."
    if ! git clone --depth=1 -b 14 https://github.com/ZyCromerZ/aarch64-zyc-linux-gnu ${GCC_64_DIR}; then
        echo "Cloning failed! Aborting..."
        exit 1
    fi
fi

if ! [ -d "${GCC_32_DIR}" ]; then
    echo "gcc_32 not found! Cloning to ${GCC_32_DIR}..."
    if ! git clone --depth=1 -b 14 https://github.com/ZyCromerZ/arm-zyc-linux-gnueabi ${GCC_32_DIR}; then
        echo "Cloning failed! Aborting..."
        exit 1
    fi
fi

if [[ $1 = "-r" || $1 = "--regen" ]]; then
    make O=out ARCH=arm64 $DEFCONFIG savedefconfig
    cp out/defconfig arch/arm64/configs/$DEFCONFIG
    exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
    rm -rf out
fi

if [[ $1 = "-m" || $1 = "--menu" ]]; then
    mkdir -p out
    make O=out ARCH=arm64 $DEFCONFIG menuconfig
elif [[ $1 = "menu" ]]; then
    mkdir -p out
    make O=out ARCH=arm64 $DEFCONFIG menuconfig
else
    mkdir -p out
    make O=out ARCH=arm64 $DEFCONFIG
fi

echo -e "\nStarting compilation... wait\n"
if [ "$USE_LLVM" -eq 1 ]; then 
	PATH="$TC_DIR/bin:$PATH" \
	make -j$(nproc --all) \
	O=out \
	ARCH=arm64 \
	CC="clang" \
	LD="${LINKER}" \
	AR=llvm-ar \
	AS=llvm-as \
	NM=llvm-nm \
	OBJCOPY=llvm-objcopy \
	OBJDUMP=llvm-objdump \
	STRIP=llvm-strip \
	CLANG_TRIPLE=aarch64-linux-gnu- \
	CROSS_COMPILE=bin/aarch64-linux-gnu- \
	CROSS_COMPILE_ARM32=arm-linux-gnueabihf- \
	CONFIG_NO_ERROR_ON_MISMATCH=y \
	CONFIG_DEBUG_SECTION_MISMATCH=y \
	Image.gz-dtb dtbo.img
else
    PATH="$TC_DIR/bin:$PATH" \
    make -j"$PROCS" \
	O=out \
    ARCH=${ARCH} \
    CC="clang" \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabihf- \
    CONFIG_NO_ERROR_ON_MISMATCH=y \
    CONFIG_DEBUG_SECTION_MISMATCH=y \
	Image.gz-dtb dtbo.img \
    V=0 2>&1 | tee out/build.log
fi

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && \
   [ -f "out/arch/arm64/boot/dtbo.img" ]; then
    echo -e "\nKernel compiled successfully! Zipping up...\n"
    if [ -d "$AK3_DIR" ]; then
        cp -r $AK3_DIR AnyKernel3
    elif ! git clone -q https://github.com/whyakari/AnyKernel3; then
        echo -e "\nAnyKernel3 repo not found locally and cloning failed! Aborting..."
        exit 1
    fi
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
    cp out/arch/arm64/boot/dtbo.img AnyKernel3
    rm -f *zip
    cd AnyKernel3
    git checkout master &> /dev/null
    zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
    cd ..
    rm -rf AnyKernel3
    rm -rf out/arch/arm64/boot
    echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
    echo "Zip: $ZIPNAME"
    # curl --upload-file $ZIPNAME https://temp.sh/$ZIPNAME; echo
else
    echo -e "\nCompilation failed!"
    exit 1
fi
