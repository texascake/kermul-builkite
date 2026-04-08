#!/bin/bash
# scripts/build.sh

export TZ="Asia/Jakarta"

# --- ⚙️ Variabel Repositori Kernel ---
# GANTI URL DI BAWAH dengan link repositori kernel X00TD kamu
KERNEL_REPO="https://github.com/Tiktodz/android_kernel_asus_sdm636.git"
TARGET_BRANCH="caf"

echo "--- 🧹 Membersihkan Workspace Lama"
if [ -d "kernel" ]; then
    echo "Folder 'kernel' lama ditemukan. Menghapus agar workspace selalu bersih (Fresh Build)..."
    rm -rf kernel
fi

echo "--- 📥 Mengunduh (Cloning) Source Code Kernel"
git clone --depth=1 -b "$TARGET_BRANCH" "$KERNEL_REPO" kernel

echo "--- 🔍 Mengecek Direktori Kerja"
cd kernel || { echo "Gagal masuk ke folder kernel! Aborting..."; exit 1; }

if [ -f arch/arm64/configs/X00TD_defconfig ]; then
    echo "Berhasil menemukan konfigurasi X00TD di branch $TARGET_BRANCH. Lanjut ke proses berikutnya..."
else
    echo "File X00TD_defconfig tidak ditemukan di dalam repositori! Aborting..."
    exit 1
fi

# Additional command (if you're lazy to commit :v)
sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-perf+"/g' arch/arm64/configs/X00TD_defconfig

echo "--- 💉 Mengunduh dan Memasang KernelSU-Next"
curl -LSs "https://raw.githubusercontent.com/Sorayukii/KernelSU-Next/stable/kernel/setup.sh" | bash -s hookless

# Set the Variables
KERNELDIR=$(pwd)
CODENAME="TZY"
DEVICENAME="X00TD"
KERNELNAME="TOM"
VARIANT="HMP"
VERSION="CLO"
KERVER=$(make kernelversion)
BONUS_MSG="*Note:* KernelSU-Next and WildKSU Supported!! 🤫"

HOST=$(uname -a | awk '{print $2}')
CI_BRANCH=$(git rev-parse --abbrev-ref HEAD)
TERM=xterm

# Set compiler
COMP=1
LTO=0
SIGN=1
TG_SUPER=0

# Additional Variables
KERNEL_DEFCONFIG=X00TD_defconfig
DATE=$(date '+%d%m%Y')
DATE2=$(date '+%d%m%Y-%H%M')
FINAL_ZIP="$KERNELNAME-$VARIANT-$VERSION-$KERVER-$DATE"
export KBUILD_BUILD_TIMESTAMP=$(date)
export KBUILD_BUILD_USER="eunjix"
export KBUILD_BUILD_HOST="$HOST"

echo "--- 🤖 Menyiapkan Fungsi Telegram"
tg_post_msg(){
    if [ $TG_SUPER = 1 ]; then
        curl -s -o /dev/null -X POST \
        "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d message_thread_id="$TG_TOPIC_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
    else
        curl -s -o /dev/null -X POST \
        "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
    fi
}

tg_post_build() {
    if [ $TG_SUPER = 1 ]; then
        MSGID=$(curl -s -F document=@"$1" \
        "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F message_thread_id="$TG_TOPIC_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=Markdown" \
        -F caption="$2" \
        | cut -d ":" -f 4 | cut -d "," -f 1)
    else
        MSGID=$(curl -s -F document=@"$1" \
        "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=Markdown" \
        -F caption="$2" \
        | cut -d ":" -f 4 | cut -d "," -f 1)
    fi
}

tg_post_msg "<b>$(date '+%d %b %Y, %H:%M %Z')</b> Masterpiece creation starts! Kernel version <b>$KERVER</b> for <b>$DEVICENAME</b>. Log URL <a href='$BUILDKITE_BUILD_URL'>Click Here</a>."

echo "--- 🧰 Menyiapkan Compiler"
if [ $COMP = "1" ]; then
    sudo apt-get install wget libncurses5 -y
    git clone --depth=1 https://github.com/RyuujiX/SDClang -b 14 sdclang
    git clone --depth=1 https://github.com/Kneba/aarch64-linux-android-4.9 gcc64
    git clone --depth=1 https://github.com/Kneba/arm-linux-androideabi-4.9 gcc32
    cd $KERNELDIR
    export PATH="$KERNELDIR/sdclang/bin:$KERNELDIR/gcc64/bin:$KERNELDIR/gcc32/bin:$PATH"
    export LD_LIBRARY_PATH="$KERNELDIR/sdclang/lib:$LD_LIBRARY_PATH"
    CLANG_VER="Snapdragon™ clang version 14.1.5"
    export KBUILD_COMPILER_STRING="$CLANG_VER"
    if ! [ -f "$KERNELDIR/sdclang/bin/clang" ]; then
        echo "Cloning failed! Aborting..."; exit 1
    fi
else
    exit 1
fi

if [ $LTO = "1" ]; then
    export LD=ld.lld
    export LD_LIBRARY_PATH=$TC_DIR/lib
fi

export ARCH=arm64
export SUBARCH=arm64

BUILD_START=$(date +"%s")
mkdir -p out
make O=out clean

echo "+++ ⚙️ Konfigurasi Kernel $KERNEL_DEFCONFIG"
make $KERNEL_DEFCONFIG O=out 2>&1 | tee -a error.log

echo "+++ 🚀 Memulai Kompilasi Kernel"
if [ $COMP = 5 ]; then
    ClangMoreStrings="AR=llvm-ar NM=llvm-nm AS=llvm-as STRIP=llvm-strip HOST_PREFIX=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf HOSTAR=llvm-ar HOSTAS=llvm-as"
    make -j$(nproc --all) O=out LLVM=1 \
    ARCH=arm64 \
    SUBARCH=arm64 \
    CC=clang \
    CROSS_COMPILE=aarch64-linux-android- \
    CROSS_COMPILE_ARM32=arm-linux-androideabi- \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    HOSTCC=gcc \
    HOSTCXX=g++ ${ClangMoreStrings} 2>&1 | tee -a error.log
fi

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

echo "--- 📦 Verifikasi dan AnyKernel3"
if ! [ -f $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb ]; then
    tg_post_build "error.log" "Compile Error!!"
    echo "Compile Failed!!!"
    exit 1
fi

if ! [ -d "$KERNELDIR/AnyKernel3" ]; then
    echo "AnyKernel3 not found! Cloning..."
    if ! git clone --depth=1 https://github.com/Kneba/AnyKernel3 -b polos AnyKernel3; then
        tg_post_build "$KERNELDIR/out/arch/arm64/boot/Image.gz-dtb" "Failed to Clone Anykernel, Sending image file instead"
        exit 1
    fi
fi

AK3DIR=$KERNELDIR/AnyKernel3
cp -af $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb $AK3DIR

cd $AK3DIR
echo "--- 🤐 Zipping Hasil Build"
zip -r9 $FINAL_ZIP.zip * -x .git README.md ./*placeholder anykernel-real.sh .gitignore zipsigner* *.zip

if ! [ -f $FINAL_ZIP* ]; then
    tg_post_build "$KERNELDIR/out/arch/arm64/boot/Image.gz-dtb" "Failed to zipping the kernel, Sending image file instead."
    exit 1
fi

mv $FINAL_ZIP* $KERNELDIR/$FINAL_ZIP.zip
cd $KERNELDIR

if [ $SIGN = 1 ]; then
    echo "--- ✍️ Menandatangani (Signing) Zip"
    mv $FINAL_ZIP.zip krenul.zip
    curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
    java -jar zipsigner-3.0.jar krenul.zip krenul-signed.zip
    FINAL_ZIP="$FINAL_ZIP-signed"
    mv krenul-signed.zip $FINAL_ZIP.zip
fi

MD5CHECK=$(md5sum "$FINAL_ZIP.zip" | cut -d' ' -f1)

echo "+++ 📤 Mengunggah ke Telegram"
tg_post_build "$FINAL_ZIP.zip" "⏳ *Compile Time* $(($DIFF / 60)) min(s) and $(($DIFF % 60)) seconds
📱 *Device* - ${DEVICENAME}
🐧 *Kernel Version* - ${KERVER}
🛠 *Compiler* - ${KBUILD_COMPILER_STRING}
Ⓜ *MD5* - ${MD5CHECK}
🆕 *Last Changelogs* \`\`\` $(git log --oneline -n3 | cut -d" " -f2- | awk '{print "• " $0}')\`\`\`
${BONUS_MSG}"
