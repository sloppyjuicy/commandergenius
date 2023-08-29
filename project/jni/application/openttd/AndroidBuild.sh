#!/bin/sh

LOCAL_PATH=`dirname $0`
LOCAL_PATH=`cd $LOCAL_PATH && pwd`

VER=build

export CMAKE_BUILD_PARALLEL_LEVEL=$BUILD_NUM_CPUS

[ -d openttd-$VER-$1 ] || mkdir -p openttd-$VER-$1/bin/baseset

export ARCH=$1
[ -z "$BUILD_NUM_CPUS" ] && $BUILD_NUM_CPUS=8

[ -e openttd-$VER-$1/Makefile ] || {
	CMAKE_SDL=openttd-$VER-$1/cmake/AndroidSDL.cmake
	mkdir -p openttd-$VER-$1/cmake
	rm -f src/src/rev.cpp openttd-$VER-$1/CMakeCache.txt $CMAKE_SDL

	APP_MODULES="`sh -c '. ../setEnvironment-'$1'.sh true ; echo $APP_MODULES' ../setEnvironment-$1.sh true`"
	APILEVEL="`sh -c '. ../setEnvironment-'$1'.sh true ; echo $APILEVEL' ../setEnvironment-$1.sh true`"
	NDK="`sh -c '. ../setEnvironment-'$1'.sh true ; echo $NDK' ../setEnvironment-$1.sh true`"
	APP_AVAILABLE_STATIC_LIBS="`sh -c '. ../setEnvironment-'$1'.sh true ; echo $APP_AVAILABLE_STATIC_LIBS' ../setEnvironment-$1.sh true`"

	for LIB in $APP_MODULES; do
		STATIC=`echo $APP_AVAILABLE_STATIC_LIBS | grep '\b'"$LIB"'\b'`

		TARGET=`echo $LIB | tr 'a-z' 'A-Z'`
		LIB_FILE=$LIB

		case $LIB in
			lzma)
				TARGET=LIBLZMA
				;;
			lzo2)
				TARGET=LZO
				;;
			sdl-1.2)
				TARGET=SDL
				;;
			timidity)
				TARGET=Timidity
				;;
			expat)
				# Different .so file name to avoid linking to system libexpat.so
				LIB_FILE=expat-sdl
				;;
			png)
				# Hack for PNG_PNG_INCLUDE_DIR
				echo "set(${TARGET}_${TARGET}_INCLUDE_DIR $LOCAL_PATH/../../$LIB/include)" >> $CMAKE_SDL
				;;
			freetype)
				# Hack for FREETYPE_INCLUDE_DIRS
				echo "set(${TARGET}_INCLUDE_DIRS $LOCAL_PATH/../../$LIB/include)" >> $CMAKE_SDL
				;;
			fontconfig)
				TARGET=Fontconfig
				;;
			icui18n|iculx|icuuc|icudata|icule|icuio)
				TARGET="ICU_`echo $LIB | sed 's/icu//'`"
				echo "set(PC_${TARGET}_INCLUDE_DIRS $LOCAL_PATH/../../$LIB/include)" >> $CMAKE_SDL
				echo "set(PC_${TARGET}_LIBRARY
						$LOCAL_PATH/../../../obj/local/$ARCH/lib$LIB_FILE.a
						$LOCAL_PATH/../../../obj/local/$ARCH/libicu-le-hb.a
						$LOCAL_PATH/../../../obj/local/$ARCH/libharfbuzz.a
						$LOCAL_PATH/../../../obj/local/$ARCH/libicudata.a
						$LOCAL_PATH/../../../obj/local/$ARCH/libicuuc.a)" >> $CMAKE_SDL
				echo "set(PC_${TARGET}_FOUND YES)" >> $CMAKE_SDL
				;;
		esac

		echo "set(${TARGET}_FOUND YES)" >> $CMAKE_SDL
		echo "set(${TARGET}_INCLUDE_DIR $LOCAL_PATH/../../$LIB/include)" >> $CMAKE_SDL

		if [ -n "$STATIC" ] ; then
			echo "set(${TARGET}_LIBRARY $LOCAL_PATH/../../../obj/local/$ARCH/lib$LIB_FILE.a)" >> $CMAKE_SDL
			echo "add_library(${TARGET} STATIC IMPORTED)" >> $CMAKE_SDL
		else
			echo "set(${TARGET}_LIBRARY $LOCAL_PATH/../../../obj/local/$ARCH/lib$LIB_FILE.so)" >> $CMAKE_SDL
			echo "add_library(${TARGET} SHARED IMPORTED)" >> $CMAKE_SDL
		fi
		echo "target_include_directories(${TARGET} INTERFACE "'${'"${TARGET}"'_INCLUDE_DIR})' >> $CMAKE_SDL
		echo "set_target_properties(${TARGET} PROPERTIES IMPORTED_LOCATION "'${'"${TARGET}"'_LIBRARY})' >> $CMAKE_SDL
	done

	if [ -n "${CMAKE_BIN_LOC}" ]; then
		NINJA_PATH=${CMAKE_BIN_LOC}/ninja
	else
		NINJA_PATH=$(which ninja)
	fi
	NINJA_ARGS=
	[ -n "$NINJA_PATH" ] && NINJA_ARGS="-DCMAKE_MAKE_PROGRAM=$NINJA_PATH -GNinja"

	${CMAKE_BIN_LOC}cmake \
		-DCMAKE_MODULE_PATH=$LOCAL_PATH/openttd-$VER-$1/cmake \
		-DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
		-DANDROID_ABI=$1 \
		-DANDROID_NATIVE_API_LEVEL=$APILEVEL \
		-DANDROID_STL=c++_shared \
		-DGLOBAL_DIR="." \
		-DHOST_BINARY_DIR=$LOCAL_PATH/build-tools \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DCMAKE_PREFIX_PATH=$LOCAL_PATH/../../iconv/src/$ARCH/ \
		"$([ -n "$CMAKE_C_FLAGS_RELWITHDEBINFO" ] && echo -DCMAKE_C_FLAGS_RELWITHDEBINFO="$CMAKE_C_FLAGS_RELWITHDEBINFO")" \
		"$([ -n "$CMAKE_CXX_FLAGS_RELWITHDEBINFO" ] && echo -DCMAKE_CXX_FLAGS_RELWITHDEBINFO="$CMAKE_CXX_FLAGS_RELWITHDEBINFO")" \
		$NINJA_ARGS \
		-B ./openttd-$VER-$1 -S ./src

} || exit 1

mkdir -p staging-openttd-$VER-$1

set -e

${CMAKE_BIN_LOC}cmake --build openttd-$VER-$1 --verbose;
${CMAKE_BIN_LOC}cmake --install openttd-$VER-$1 --prefix ./staging-openttd-$VER-$1;
cp staging-openttd-$VER-$1/games/libapplication.so libapplication-$1.so;
mkdir -p ./data
cp -r staging-openttd-$VER-$1/share/games/application/* data/
./pack-data.sh "${ARCH}"

set +e
