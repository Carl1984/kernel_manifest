#!/usr/bin/env bash
set -xve

# 获取 GitHub Actions 传入的参数
MANIFEST_FILE="$1"
ENABLE_LTO="$2"
ENABLE_POLLY="$3"
ENABLE_O3="$4"

# 根据 manifest_file 映射 CPUD
case "$MANIFEST_FILE" in
    "gt5pro" | "gt6CommonAce3pro" | "gt6")
        CPUD="pineapple"
        ;;
    *)
        echo "Error: Unsupported manifest_file: $MANIFEST_FILE"
        exit 1
        ;;
esac

# 设置版本变量
ANDROID_VERSION="android14"
KERNEL_VERSION="6.1"
SUSFS_VERSION="1.5.7"

# 设置工作目录
OLD_DIR="$(pwd)"
KERNEL_WORKSPACE="$OLD_DIR/kernel_platform"

# 配置编译器自然环境
export CC="clang"
export CLANG_TRIPLE="aarch64-linux-gnu-"
export LDFLAGS="-fuse-ld=lld"

# 根据参数设置优化标志
BAZEL_ARGS=""
[ "$ENABLE_O3" = "true" ] && BAZEL_ARGS="$BAZEL_ARGS --copt=-O3 --copt=-Wno-error"
[ "$ENABLE_LTO" = "true" ] && BAZEL_ARGS="$BAZEL_ARGS --copt=-flto --linkopt=-flto"
[ "$ENABLE_POLLY" = "true" ] && BAZEL_ARGS="$BAZEL_ARGS --copt=-mllvm --copt=-polly --copt=-mllvm --copt=-polly-vectorizer=stripmine"

# 清理旧的保护导出文件
rm -f "$KERNEL_WORKSPACE/common/android/abi_gki_protected_exports_*" || echo "No protected exports!"
rm -f "$KERNEL_WORKSPACE/msm-kernel/android/abi_gki_protected_exports_*" || echo "No protected exports!"
sed -i 's/ -dirty//g' "$KERNEL_WORKSPACE/build/kernel/kleaf/workspace_status_stamp.py"
sed -i 's/ -dirty//g' "$KERNEL_WORKSPACE/external/dtc/scripts/setlocalversion"
sed -i 's/ -dirty//g' "$KERNEL_WORKSPACE/msm-kernel/scripts/setlocalversion"
# sed -i 's/SUBLEVEL = 68/SUBLEVEL = 75/' "$KERNEL_WORKSPACE/msm-kernel/Makefile"

# 检查完整目录结构
cd "$KERNEL_WORKSPACE" || exit 1
find . -type d > "$OLD_DIR/kernel_directory_structure.txt"


# 添加 SukiSU Ultra
cd "$KERNEL_WORKSPACE" || exit 1
# curl -LSs "https://raw.githubusercontent.com/ShirkNeko/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-dev
curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-dev
cd ./KernelSU
KSU_VERSION=$(expr $(/usr/bin/git rev-list --count main) "+" 10606)
sed -i "s/DKSU_VERSION=12800/DKSU_VERSION=${KSU_VERSION}/" kernel/Makefile


# 设置 susfs
cd "$OLD_DIR" || exit 1
git clone https://gitlab.com/simonpunk/susfs4ksu.git -b "gki-${ANDROID_VERSION}-${KERNEL_VERSION}" --depth 1
git clone https://github.com/ShirkNeko/SukiSU_patch.git
cd "$KERNEL_WORKSPACE" || exit 1
cp ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch ./common/
cp ../susfs4ksu/kernel_patches/fs/* ./common/fs/
cp ../susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/


# 应用补丁
cd ./common || exit 1
patch -p1 < 50_add_susfs_in_gki-${ANDROID_VERSION}-${KERNEL_VERSION}.patch || true
echo "完成"

cp ../../SukiSU_patch/69_hide_stuff.patch ./
echo "正在打隐藏应用补丁"
patch -p1 -F 3 < 69_hide_stuff.patch

cp ../../SukiSU_patch/hooks/syscall_hooks.patch ./
echo "正在打vfs补丁"
patch -p1 -F 3 < syscall_hooks.patch
echo "vfs_patch完成"
          
patch -p1 < ../../.repo/manifests/patches/001-lz4.patch
patch -p1 < ../../.repo/manifests/patches/002-zstd.patch




cd "$KERNEL_WORKSPACE" || exit 1

# 这一步用于修复lz4与zstd 所导致的WiFi 5G失效等一系列问题
rm common/android/abi_gki_protected_exports_*     

#Apply new hook and add configuration
 echo "CONFIG_KSU=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KPM=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_SUS_SU=n" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_MANUAL_HOOK=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"  
 echo "CONFIG_KSU_WITH_KPROBES=n" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_SUS_OVERLAYFS=n" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
 echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"

echo "CONFIG_TMPFS_XATTR=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"
echo "CONFIG_TMPFS_POSIX_ACL=y" >> "$KERNEL_WORKSPACE/common/arch/arm64/configs/gki_defconfig"

sed -i 's/check_defconfig//' "$KERNEL_WORKSPACE/common/build.config.gki"


export OPLUS_FEATURES="OPLUS_FEATURE_BSP_DRV_INJECT_TEST=1"

#指定内核版本
sed -i '$s|echo "\$res"|echo "6.1.75-android14-11-o-g4c9c8979e2a7"|' "$KERNEL_WORKSPACE/common/scripts/setlocalversion"
 
# 构建内核
cd "$OLD_DIR" || exit 1
./kernel_platform/build_with_bazel.py -t "${CPUD}" gki \
    --config=stamp \
    --linkopt="-fuse-ld=lld" \
    $BAZEL_ARGS

# 获取内核版本
KERNEL_VERSION=$(cat "$KERNEL_WORKSPACE/out/msm-kernel-${CPUD}-gki/dist/version.txt" 2>/dev/null || echo "6.1")


# 输出变量到 GitHub Actions
echo "kernel_version=$KERNEL_VERSION" >> "$GITHUB_OUTPUT"
echo "ksu_version=$KSU_VERSION" >> "$GITHUB_OUTPUT"
echo "susfs_version=$SUSFS_VERSION" >> "$GITHUB_OUTPUT"
