#!/bin/bash
set -e
################## SETUP BEGIN
THREAD_COUNT=$(sysctl hw.ncpu | awk '{print $2}')
HOST_ARC=$( uname -m )
XCODE_ROOT=$( xcode-select -print-path )
LZ4_VER=v1.10.0.0
MACOSX_VERSION_ARM=12.3
MACOSX_VERSION_X86_64=10.13
IOS_VERSION=13.4
IOS_SIM_VERSION=13.4
CATALYST_VERSION=13.4
TVOS_VERSION=13.0
TVOS_SIM_VERSION=13.0
WATCHOS_VERSION=11.0
WATCHOS_SIM_VERSION=11.0
################## SETUP END

IOSSYSROOT=$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer
IOSSIMSYSROOT=$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer
MACSYSROOT=$XCODE_ROOT/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
XROSSYSROOT=$XCODE_ROOT/Platforms/XROS.platform/Developer
XROSSIMSYSROOT=$XCODE_ROOT/Platforms/XRSimulator.platform/Developer
TVOSSYSROOT=$XCODE_ROOT/Platforms/AppleTVOS.platform/Developer
TVOSSIMSYSROOT=$XCODE_ROOT/Platforms/AppleTVSimulator.platform/Developer
WATCHOSSYSROOT=$XCODE_ROOT/Platforms/WatchOS.platform/Developer
WATCHOSSIMSYSROOT=$XCODE_ROOT/Platforms/WatchSimulator.platform/Developer

BUILD_PLATFORMS_ALL="macosx,macosx-arm64,macosx-x86_64,macosx-both,ios,iossim,iossim-arm64,iossim-x86_64,iossim-both,catalyst,catalyst-arm64,catalyst-x86_64,catalyst-both,xros,xrossim,xrossim-arm64,xrossim-x86_64,xrossim-both,tvos,tvossim,tvossim-both,tvossim-arm64,tvossim-x86_64,watchos,watchossim,watchossim-both,watchossim-arm64,watchossim-x86_64"

LZ4_VER_NAME=lz4_${LZ4_VER//./_}
BUILD_DIR="$( cd "$( dirname "./" )" >/dev/null 2>&1 && pwd )"
INSTALL_DIR="$BUILD_DIR/frameworks"

if [[ "$HOST_ARC" == "arm64" ]]; then
	BUILD_ARC=arm
    FOREIGN_ARC=x86_64
    FOREIGN_BUILD_ARC=x86_64
    FOREIGN_BUILD_FLAGS="" && [[ ! -z "${MACOSX_VERSION_X86_64}" ]] && FOREIGN_BUILD_FLAGS="-mmacosx-version-min=$MACOSX_VERSION_X86_64"
    NATIVE_BUILD_FLAGS="" && [[ ! -z "${MACOSX_VERSION_ARM}" ]] && NATIVE_BUILD_FLAGS="-mmacosx-version-min=$MACOSX_VERSION_ARM"
else
	BUILD_ARC=$HOST_ARC
    FOREIGN_ARC=arm64
    FOREIGN_BUILD_ARC=arm
    FOREIGN_BUILD_FLAGS="" && [[ ! -z "${MACOSX_VERSION_ARM}" ]] && FOREIGN_BUILD_FLAGS="-mmacosx-version-min=$MACOSX_VERSION_ARM"
    NATIVE_BUILD_FLAGS="" && [[ ! -z "${MACOSX_VERSION_X86_64}" ]] && NATIVE_BUILD_FLAGS="-mmacosx-version-min=$MACOSX_VERSION_X86_64"
fi

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

if [[ ! -d $LZ4_VER_NAME ]]; then
	echo downloading $LZ4_VER ...
	git clone --depth 1 -b $LZ4_VER https://github.com/lz4/lz4 $LZ4_VER_NAME
fi

sed -i '' 's/cmake_minimum_required(VERSION 2.8.12)/cmake_minimum_required(VERSION 3.10)/' $BUILD_DIR/$LZ4_VER_NAME/build/cmake/CMakeLists.txt

echo building $LZ4_VER "(-j$THREAD_COUNT)" ...

# (type, arc, target, cflags)
generic_build()
{
    BUILD_FOLDER=$LZ4_VER_NAME-$1-build
    BUILD_NAME=$LZ4_VER_NAME-$1-${2//;/_}-build
    if [[ $REBUILD == true ]] || [[ ! -f $BUILD_NAME.success ]]; then
        
        rm -f $LZ4_VER_NAME-$1-*.success
        
        echo preparing build folder $BUILD_FOLDER-build ...
        [[ -d $BUILD_FOLDER ]] && rm -rf $BUILD_FOLDER
        mkdir -p $BUILD_FOLDER
        echo "building lz4 ($1 $2)..."
        pushd $BUILD_FOLDER

        cmake $4 -DCMAKE_C_FLAGS="$5" -DCMAKE_CXX_FLAGS="$5" -DCMAKE_EXE_LINKER_FLAGS="$6" -DCMAKE_OSX_ARCHITECTURES=$2 -DBUILD_SHARED_LIBS=OFF -GXcode ../$LZ4_VER_NAME/build/cmake
		
        cmake --build . --config Release --target lz4_static -- $3 -j $THREAD_COUNT

        popd
        touch $BUILD_NAME.success
    fi
}

LIBS_TO_BUILD="lz4"

if false; then
build_libs()
{
    [[ -d $LZ4_VER_NAME-$1-build ]] && rm -rf $LZ4_VER_NAME-$1-build
    mkdir -p $LZ4_VER_NAME-$1-build/source/lib

    if [[ "$BUILD_PLATFORMS" == *$1-arm64* ]]; then
        if [[ "$BUILD_PLATFORMS" == *$1-x86_64* ]]; then
            for i in $LIBS_TO_BUILD; do :;
                lipo -create $LZ4_VER_NAME-$1-arm64-build/source/lib/lib$i.a $LZ4_VER_NAME-$1-x86_64-build/source/lib/lib$i.a -output $ICU_VER_NAME-$1-build/source/lib/lib$i.a
            done
        else
            for i in $LIBS_TO_BUILD; do :;
                cp $LZ4_VER_NAME-$1-arm64-build/source/lib/lib$i.a $LZ4_VER_NAME-$1-build/source/lib/
            done
        fi
    elif [[ "$BUILD_PLATFORMS" == *$1-x86_64* ]]; then
        for i in $LIBS_TO_BUILD; do :;
            cp $LZ4_VER_NAME-$1-x86_64-build/source/lib/lib$i.a $LZ4_VER_NAME-$1-build/source/lib/
        done
    fi
}
fi

# (type, coomon_cflags, triple)
generic_double_build()
{
    if [[ "$BUILD_PLATFORMS" == *$1-arm64* ]]; then
        if [[ "$BUILD_PLATFORMS" == *$1-x86_64* ]]; then
            generic_build $1 "arm64;x86_64" "$2" "$3"
        else
            generic_build $1 "arm64" "$2" "$3"
        fi
    elif [[ "$BUILD_PLATFORMS" == *$1-x86_64* ]]; then
        generic_build $1 "x86_64" "$2" "$3"
    fi
    #build_libs $1
}

build_catalyst_libs()
{
    if [[ "$BUILD_PLATFORMS" == *$1-arm64* ]]; then
        generic_build catalyst-arm64 "arm64" "-sdk macosx" "-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=macosx -DCMAKE_XCODE_ATTRIBUTE_SUPPORTS_MACCATALYST=YES" "-target arm64-apple-ios$CATALYST_VERSION-macabi" "-target arm64-apple-ios$CATALYST_VERSION-macabi"
    fi
    if [[ "$BUILD_PLATFORMS" == *$1-x86_64* ]]; then
        generic_build catalyst-x86_64 "x86_64" "-sdk macosx" "-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=macosx -DCMAKE_XCODE_ATTRIBUTE_SUPPORTS_MACCATALYST=YES" "-target x86_64-apple-ios$CATALYST_VERSION-macabi" "-target x86_64-apple-ios$CATALYST_VERSION-macabi"
    fi
    BUILD_FOLDER=$LZ4_VER_NAME-catalyst-build
    [[ -d $BUILD_FOLDER ]] && rm -rf $BUILD_FOLDER
    mkdir -p $BUILD_FOLDER/Release

    if [[ "$BUILD_PLATFORMS" == *$1-arm64* ]]; then
        if [[ "$BUILD_PLATFORMS" == *$1-x86_64* ]]; then
            lipo -create $LZ4_VER_NAME-catalyst-arm64-build/Release/liblz4.a $LZ4_VER_NAME-catalyst-x86_64-build/Release/liblz4.a -output $LZ4_VER_NAME-catalyst-build/Release/liblz4.a
        else
            cp $LZ4_VER_NAME-catalyst-arm64-build/Release/liblz4.a $LZ4_VER_NAME-catalyst-build/Release/liblz4.a
        fi
    elif [[ "$BUILD_PLATFORMS" == *$1-x86_64* ]]; then
        cp $LZ4_VER_NAME-catalyst-x86_64-build/Release/liblz4.a $LZ4_VER_NAME-catalyst-build/Release/liblz4.a
    fi
}

build_iossim_libs()
{
    generic_double_build iossim "-sdk iphonesimulator" "-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_SIM_VERSION"
}

build_xrossim_libs()
{
    generic_double_build xrossim "-sdk xrsimulator" "-DCMAKE_SYSTEM_NAME=visionOS -DCMAKE_OSX_SYSROOT=xrsimulator"
}

build_tvossim_libs()
{
    generic_double_build tvossim "-sdk appletvsimulator" "-DCMAKE_SYSTEM_NAME=tvOS -DCMAKE_OSX_SYSROOT=appletvsimulator -DCMAKE_OSX_DEPLOYMENT_TARGET=$TVOS_SIM_VERSION"
}

build_watchossim_libs()
{
    generic_double_build watchossim "-sdk watchsimulator" "-DCMAKE_SYSTEM_NAME=watchOS -DCMAKE_OSX_SYSROOT=watchsimulator -DCMAKE_OSX_DEPLOYMENT_TARGET=$WATCHOS_SIM_VERSION"
}

################### BUILD

[[ "$BUILD_PLATFORMS" == *macosx* ]] && generic_double_build macosx "" "-DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO -DCMAKE_IOS_INSTALL_COMBINED=YES"

[[ "$BUILD_PLATFORMS" == *catalyst* ]] && build_catalyst_libs

[[ "$BUILD_PLATFORMS" == *iossim* ]] && build_iossim_libs

[[ "$BUILD_PLATFORMS" == *xrossim* ]] && build_xrossim_libs

[[ "$BUILD_PLATFORMS" == *tvossim* ]] && build_tvossim_libs

[[ "$BUILD_PLATFORMS" == *watchossim* ]] && build_watchossim_libs

[[ "$BUILD_PLATFORMS" == *"ios "* ]] && generic_build ios arm64 "-sdk iphoneos" "-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_VERSION"

[[ "$BUILD_PLATFORMS" == *"xros "* ]] && generic_build xros arm64 "-sdk xros" "-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_VERSION"

[[ "$BUILD_PLATFORMS" == *"tvos "* ]] && generic_build tvos arm64 "-sdk appletvos" "-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=$TVOS_VERSION"

[[ "$BUILD_PLATFORMS" == *"watchos "* ]] && generic_build watchos arm64 "-sdk watchos" "-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=$WATCHOS_VERSION"

[[ -d $INSTALL_DIR/frameworks ]] && rm -rf $INSTALL_DIR/frameworks
mkdir -p $INSTALL_DIR/frameworks

build_xcframework()
{
    LIBARGS=
    [[ "$BUILD_PLATFORMS" == *macosx* ]] && LIBARGS="$LIBARGS -library $LZ4_VER_NAME-macosx-build/Release/lib$1.a"
    [[ "$BUILD_PLATFORMS" == *catalyst* ]] && LIBARGS="$LIBARGS -library $LZ4_VER_NAME-catalyst-build/Release/lib$1.a"
    [[ "$BUILD_PLATFORMS" == *iossim* ]] && LIBARGS="$LIBARGS -library $LZ4_VER_NAME-iossim-build/Release-iphonesimulator/lib$1.a"
    [[ "$BUILD_PLATFORMS" == *xrossim* ]] && LIBARGS="$LIBARGS -library $LZ4_VER_NAME-xrossim-build/Release-xrsimulator/lib$1.a"
    [[ "$BUILD_PLATFORMS" == *tvossim* ]] && LIBARGS="$LIBARGS -library $LZ4_VER_NAME-tvossim-build/Release-appletvsimulator/lib$1.a"
    [[ "$BUILD_PLATFORMS" == *watchossim* ]] && LIBARGS="$LIBARGS -library $LZ4_VER_NAME-watchossim-build/Release-watchsimulator/lib$1.a"
    [[ "$BUILD_PLATFORMS" == *"ios "* ]] && LIBARGS="$LIBARGS -library $LZ4_VER_NAME-ios-build/Release-iphoneos/lib$1.a"
    [[ "$BUILD_PLATFORMS" == *"xros "* ]] && LIBARGS="$LIBARGS -library $LZ4_VER_NAME-xros-build/Release-xros/lib$1.a"
    [[ "$BUILD_PLATFORMS" == *"tvos "* ]] && LIBARGS="$LIBARGS -library $LZ4_VER_NAME-tvos-build/Release-appletvos/lib$1.a"
    [[ "$BUILD_PLATFORMS" == *"watchos "* ]] && LIBARGS="$LIBARGS -library $LZ4_VER_NAME-watchos-build/Release-watchos/lib$1.a"

    xcodebuild -create-xcframework $LIBARGS -output $INSTALL_DIR/$1.xcframework
}

for i in $LIBS_TO_BUILD; do :;
    build_xcframework $i
done

[[ ! -d $INSTALL_DIR/Headers ]] && mkdir $INSTALL_DIR/Headers
cp $LZ4_VER_NAME/lib/*.h $INSTALL_DIR/Headers/
