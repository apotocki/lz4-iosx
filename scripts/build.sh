#!/bin/bash
set -euo pipefail

################## SETUP BEGIN
THREAD_COUNT=$(sysctl hw.ncpu | awk '{print $2}')
HOST_ARC=$( uname -m )
XCODE_ROOT=$( xcode-select -print-path )
LZ4_VER=v1.10.0
MACOSX_VERSION_ARM=12.3
MACOSX_VERSION_X86_64=10.13
IOS_VERSION=13.4
IOS_SIM_VERSION=13.4
CATALYST_VERSION=13.4
TVOS_VERSION=13.0
TVOS_SIM_VERSION=13.0
WATCHOS_VERSION=11.0
WATCHOS_SIM_VERSION=11.0
XROS_VERSION=1.0
XROS_SIM_VERSION=1.0
################## SETUP END

XROSSYSROOT=$XCODE_ROOT/Platforms/XROS.platform/Developer
XROSSIMSYSROOT=$XCODE_ROOT/Platforms/XRSimulator.platform/Developer
TVOSSYSROOT=$XCODE_ROOT/Platforms/AppleTVOS.platform/Developer
TVOSSIMSYSROOT=$XCODE_ROOT/Platforms/AppleTVSimulator.platform/Developer
WATCHOSSYSROOT=$XCODE_ROOT/Platforms/WatchOS.platform/Developer
WATCHOSSIMSYSROOT=$XCODE_ROOT/Platforms/WatchSimulator.platform/Developer

BUILD_PLATFORMS_ALL="macosx,macosx-arm64,macosx-x86_64,macosx-both,ios,iossim,iossim-arm64,iossim-x86_64,iossim-both,catalyst,catalyst-arm64,catalyst-x86_64,catalyst-both,xros,xrossim,xrossim-arm64,xrossim-x86_64,xrossim-both,tvos,tvossim,tvossim-both,tvossim-arm64,tvossim-x86_64,watchos,watchossim,watchossim-both,watchossim-arm64,watchossim-x86_64"

LZ4_VER_NAME=lz4_${LZ4_VER//./_}
BUILD_DIR="$( cd "$( dirname "./" )" >/dev/null 2>&1 && pwd )"

BUILD_PLATFORMS="macosx,ios,iossim,catalyst"
[[ -d $XROSSYSROOT/SDKs/XROS.sdk ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,xros"
[[ -d $XROSSIMSYSROOT/SDKs/XRSimulator.sdk ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,xrossim"
[[ -d $TVOSSYSROOT/SDKs/AppleTVOS.sdk ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,tvos"
[[ -d $TVOSSIMSYSROOT/SDKs/AppleTVSimulator.sdk ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,tvossim"
[[ -d $WATCHOSSYSROOT/SDKs/WatchOS.sdk ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,watchos"
[[ -d $WATCHOSSIMSYSROOT/SDKs/WatchSimulator.sdk ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,watchossim-both"

REBUILD=false

# parse command line
for i in "$@"; do
  case $i in
    -p=*|--platforms=*)
      BUILD_PLATFORMS="${i#*=},"
      shift # past argument=value
      ;;
    --rebuild)
      REBUILD=true
      shift # past argument with no value
      ;;
    -*|--*)
      echo "Unknown option $i"
      exit 1
      ;;
    *)
      ;;
  esac
done

[[ "$BUILD_PLATFORMS" == *"macosx-both"* ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,macosx-arm64,macosx-x86_64"
[[ "$BUILD_PLATFORMS" == *"iossim-both"* ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,iossim-arm64,iossim-x86_64"
[[ "$BUILD_PLATFORMS" == *"catalyst-both"* ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,catalyst-arm64,catalyst-x86_64"
[[ "$BUILD_PLATFORMS" == *"xrossim-both"* ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,xrossim-arm64,xrossim-x86_64"
[[ "$BUILD_PLATFORMS" == *"tvossim-both"* ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,tvossim-arm64,tvossim-x86_64"
[[ "$BUILD_PLATFORMS" == *"watchossim-both"* ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,watchossim-arm64,watchossim-x86_64"
[[ "$BUILD_PLATFORMS," == *"macosx,"* ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,macosx-$HOST_ARC"
[[ "$BUILD_PLATFORMS," == *"iossim,"* ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,iossim-$HOST_ARC"
[[ "$BUILD_PLATFORMS," == *"catalyst,"* ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,catalyst-$HOST_ARC"
[[ "$BUILD_PLATFORMS," == *"xrossim,"* ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,xrossim-$HOST_ARC"
[[ "$BUILD_PLATFORMS," == *"tvossim,"* ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,tvossim-$HOST_ARC"
[[ "$BUILD_PLATFORMS," == *"watchossim,"* ]] && BUILD_PLATFORMS="$BUILD_PLATFORMS,watchossim-$HOST_ARC"

BUILD_PLATFORMS=" ${BUILD_PLATFORMS//,/ } "

for i in $BUILD_PLATFORMS; do :;
if [[ ! ",$BUILD_PLATFORMS_ALL," == *",$i,"* ]]; then
    echo "Unknown platform '$i'"
    exit 1
fi
done

# An interrupted clone can leave a directory with .git but an incomplete work tree,
# so validate the files we need and clone into a temporary directory renamed on success.
if [[ ! -f $LZ4_VER_NAME/build/cmake/CMakeLists.txt || ! -f $LZ4_VER_NAME/lib/lz4.h ]]; then
    echo downloading $LZ4_VER ...
    rm -rf $LZ4_VER_NAME $LZ4_VER_NAME.download
    git clone --depth 1 -b $LZ4_VER https://github.com/lz4/lz4 $LZ4_VER_NAME.download
    mv $LZ4_VER_NAME.download $LZ4_VER_NAME
fi

echo building $LZ4_VER "(-j$THREAD_COUNT)" ...

# (type, arc, cmake args...)
generic_build()
{
    local type=$1 arc=$2
    shift 2
    local folder=$BUILD_DIR/build.$type.$arc
    if [[ $REBUILD == true ]] || [[ ! -f $folder.success ]] || [[ ! -f $folder/liblz4.a ]]; then
        [[ -f $folder.success ]] && rm $folder.success
        [[ -d $folder ]] && rm -rf $folder
        echo "building liblz4 ($type $arc)..."
        # older lz4 releases declare a CMake minimum that CMake 4 no longer accepts
        cmake -S $BUILD_DIR/$LZ4_VER_NAME/build/cmake -B $folder -G "Unix Makefiles" \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DLZ4_BUILD_CLI=OFF -DLZ4_BUILD_LEGACY_LZ4C=OFF \
            -DCMAKE_OSX_ARCHITECTURES=$arc "$@"
        cmake --build $folder --config Release --target lz4_static -j $THREAD_COUNT
        touch $folder.success
    fi
}

# (type, deployment-target, cmake args...): an Apple platform with its own CMake system name
apple_build()
{
    local type=$1 arc=$2 version=$3
    shift 3
    generic_build $type $arc -DCMAKE_OSX_DEPLOYMENT_TARGET=$version "$@"
}

build_libs()
{
    [[ -d $BUILD_DIR/build.$1 ]] && rm -rf $BUILD_DIR/build.$1
    mkdir -p $BUILD_DIR/build.$1

    if [[ "$BUILD_PLATFORMS" == *$1-arm64* ]]; then
        if [[ "$BUILD_PLATFORMS" == *$1-x86_64* ]]; then
            lipo -create $BUILD_DIR/build.$1.arm64/liblz4.a $BUILD_DIR/build.$1.x86_64/liblz4.a -output $BUILD_DIR/build.$1/liblz4.a
        else
            cp $BUILD_DIR/build.$1.arm64/liblz4.a $BUILD_DIR/build.$1/
        fi
    elif [[ "$BUILD_PLATFORMS" == *$1-x86_64* ]]; then
        cp $BUILD_DIR/build.$1.x86_64/liblz4.a $BUILD_DIR/build.$1/
    fi
}

# (type, system name, sdk, deployment target)
generic_double_build()
{
    [[ "$BUILD_PLATFORMS" == *$1-arm64* ]] && apple_build $1 arm64 $4 -DCMAKE_SYSTEM_NAME=$2 -DCMAKE_OSX_SYSROOT=$3
    [[ "$BUILD_PLATFORMS" == *$1-x86_64* ]] && apple_build $1 x86_64 $4 -DCMAKE_SYSTEM_NAME=$2 -DCMAKE_OSX_SYSROOT=$3
    build_libs $1
}

build_macosx_libs()
{
    [[ "$BUILD_PLATFORMS" == *macosx-arm64* ]] && apple_build macosx arm64 $MACOSX_VERSION_ARM -DCMAKE_OSX_SYSROOT=macosx
    [[ "$BUILD_PLATFORMS" == *macosx-x86_64* ]] && apple_build macosx x86_64 $MACOSX_VERSION_X86_64 -DCMAKE_OSX_SYSROOT=macosx
    build_libs macosx
}

build_catalyst_libs()
{
    [[ "$BUILD_PLATFORMS" == *catalyst-arm64* ]] && generic_build catalyst arm64 -DCMAKE_OSX_SYSROOT=macosx "-DCMAKE_C_FLAGS=-target arm64-apple-ios$CATALYST_VERSION-macabi"
    [[ "$BUILD_PLATFORMS" == *catalyst-x86_64* ]] && generic_build catalyst x86_64 -DCMAKE_OSX_SYSROOT=macosx "-DCMAKE_C_FLAGS=-target x86_64-apple-ios$CATALYST_VERSION-macabi"
    build_libs catalyst
}

[[ "$BUILD_PLATFORMS" == *macosx* ]] && build_macosx_libs
[[ "$BUILD_PLATFORMS" == *catalyst* ]] && build_catalyst_libs
[[ "$BUILD_PLATFORMS" == *iossim* ]] && generic_double_build iossim iOS iphonesimulator $IOS_SIM_VERSION
[[ "$BUILD_PLATFORMS" == *xrossim* ]] && generic_double_build xrossim visionOS xrsimulator $XROS_SIM_VERSION
[[ "$BUILD_PLATFORMS" == *tvossim* ]] && generic_double_build tvossim tvOS appletvsimulator $TVOS_SIM_VERSION
[[ "$BUILD_PLATFORMS" == *watchossim* ]] && generic_double_build watchossim watchOS watchsimulator $WATCHOS_SIM_VERSION

[[ "$BUILD_PLATFORMS" == *"ios "* ]] && apple_build ios arm64 $IOS_VERSION -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos
[[ "$BUILD_PLATFORMS" == *"xros "* ]] && apple_build xros arm64 $XROS_VERSION -DCMAKE_SYSTEM_NAME=visionOS -DCMAKE_OSX_SYSROOT=xros
[[ "$BUILD_PLATFORMS" == *"tvos "* ]] && apple_build tvos arm64 $TVOS_VERSION -DCMAKE_SYSTEM_NAME=tvOS -DCMAKE_OSX_SYSROOT=appletvos
[[ "$BUILD_PLATFORMS" == *"watchos "* ]] && apple_build watchos arm64 $WATCHOS_VERSION -DCMAKE_SYSTEM_NAME=watchOS -DCMAKE_OSX_SYSROOT=watchos

LIBARGS=
[[ "$BUILD_PLATFORMS" == *macosx* ]] && LIBARGS="$LIBARGS -library $BUILD_DIR/build.macosx/liblz4.a"
[[ "$BUILD_PLATFORMS" == *catalyst* ]] && LIBARGS="$LIBARGS -library $BUILD_DIR/build.catalyst/liblz4.a"
[[ "$BUILD_PLATFORMS" == *iossim* ]] && LIBARGS="$LIBARGS -library $BUILD_DIR/build.iossim/liblz4.a"
[[ "$BUILD_PLATFORMS" == *xrossim* ]] && LIBARGS="$LIBARGS -library $BUILD_DIR/build.xrossim/liblz4.a"
[[ "$BUILD_PLATFORMS" == *tvossim* ]] && LIBARGS="$LIBARGS -library $BUILD_DIR/build.tvossim/liblz4.a"
[[ "$BUILD_PLATFORMS" == *watchossim* ]] && LIBARGS="$LIBARGS -library $BUILD_DIR/build.watchossim/liblz4.a"
[[ "$BUILD_PLATFORMS" == *"ios "* ]] && LIBARGS="$LIBARGS -library $BUILD_DIR/build.ios.arm64/liblz4.a"
[[ "$BUILD_PLATFORMS" == *"xros "* ]] && LIBARGS="$LIBARGS -library $BUILD_DIR/build.xros.arm64/liblz4.a"
[[ "$BUILD_PLATFORMS" == *"tvos "* ]] && LIBARGS="$LIBARGS -library $BUILD_DIR/build.tvos.arm64/liblz4.a"
[[ "$BUILD_PLATFORMS" == *"watchos "* ]] && LIBARGS="$LIBARGS -library $BUILD_DIR/build.watchos.arm64/liblz4.a"

[[ -d $BUILD_DIR/frameworks ]] && rm -rf $BUILD_DIR/frameworks
mkdir -p $BUILD_DIR/frameworks/Headers
xcodebuild -create-xcframework $LIBARGS -output $BUILD_DIR/frameworks/lz4.xcframework
cp $LZ4_VER_NAME/lib/*.h $BUILD_DIR/frameworks/Headers/
