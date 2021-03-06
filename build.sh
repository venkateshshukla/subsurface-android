#!/bin/bash
set -e
# Configure where we can find things here
export ANDROID_NDK_ROOT=$PWD/../android-ndk-r9d
export ANDROID_SDK_ROOT=$PWD/../android-sdk-linux
export QT5_ANDROID=$PWD/../Qt5.3.0/5.3

# arm or x86
export ARCH=${1-arm}

if [ "$ARCH" = "arm" ] ; then
	QT_ARCH="armv7"
	BUILDCHAIN=arm-linux-androideabi
else if [ "$ARCH" = "x86" ] ; then
	QT_ARCH=$ARCH
	BUILDCHAIN=i686-linux-android
fi fi
export QT5_ANDROID_BIN=${QT5_ANDROID}/android_${QT_ARCH}/bin

if [ ! -e ndk-$ARCH ] ; then
	$ANDROID_NDK_ROOT/build/tools/make-standalone-toolchain.sh --arch=$ARCH --install-dir=ndk-$ARCH --platform=android-14
fi
export BUILDROOT=$PWD
export PATH=${BUILDROOT}/ndk-$ARCH/bin:$PATH
export PREFIX=${BUILDROOT}/ndk-$ARCH/sysroot/usr
export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig
export CC=${BUILDCHAIN}-gcc
export CXX=${BUILDCHAIN}-g++

# Fetch external repos
if [ ! -e subsurface/CMakeLists.txt ] || [ ! -e libdivecomputer/configure.ac ] ; then
	git submodule init
	git submodule update
fi

if [ ! -e sqlite-autoconf-3080200.tar.gz ] ; then
	wget http://www.sqlite.org/2013/sqlite-autoconf-3080200.tar.gz
fi
if [ ! -e sqlite-autoconf-3080200 ] ; then
	tar -zxf sqlite-autoconf-3080200.tar.gz
fi
if [ ! -e $PKG_CONFIG_PATH/sqlite3.pc ] ; then
	mkdir -p sqlite-build-$ARCH
	pushd sqlite-build-$ARCH
	../sqlite-autoconf-3080200/configure --host=${BUILDCHAIN} --prefix=${PREFIX} --enable-static --disable-shared
	make -j4
	make install
	popd
fi

if [ ! -e libxml2-2.9.1.tar.gz ] ; then
	wget ftp://xmlsoft.org/libxml2/libxml2-2.9.1.tar.gz
fi
if [ ! -e libxml2-2.9.1 ] ; then
	tar -zxf libxml2-2.9.1.tar.gz
fi
if [ ! -e $PKG_CONFIG_PATH/libxml-2.0.pc ] ; then
	mkdir -p libxml2-build-$ARCH
	pushd libxml2-build-$ARCH
	../libxml2-2.9.1/configure --host=${BUILDCHAIN} --prefix=${PREFIX} --without-python --without-iconv --enable-static --disable-shared
	perl -pi -e 's/runtest\$\(EXEEXT\)//' Makefile
	perl -pi -e 's/testrecurse\$\(EXEEXT\)//' Makefile
	make -j4
	make install
	popd
fi

if [ ! -e libxslt-1.1.28.tar.gz ] ; then
	wget ftp://xmlsoft.org/libxml2/libxslt-1.1.28.tar.gz
fi
if [ ! -e libxslt-1.1.28 ] ; then
	tar -zxf libxslt-1.1.28.tar.gz
	cp libxml2-2.9.1/config.sub libxslt-1.1.28
fi
if [ ! -e $PKG_CONFIG_PATH/libxslt.pc ] ; then
	mkdir -p libxslt-build-$ARCH
	pushd libxslt-build-$ARCH
	../libxslt-1.1.28/configure --host=${BUILDCHAIN} --prefix=${PREFIX} --with-libxml-prefix=${PREFIX} --without-python --without-crypto --enable-static --disable-shared
	make
	make install
	popd
fi

if [ ! -e libzip-0.11.2.tar.gz ] ; then
	wget http://www.nih.at/libzip/libzip-0.11.2.tar.gz
fi
if [ ! -e libzip-0.11.2 ] ; then
	tar -zxf libzip-0.11.2.tar.gz
fi
if [ ! -e $PKG_CONFIG_PATH/libzip.pc ] ; then
	mkdir -p libzip-build-$ARCH
	pushd libzip-build-$ARCH
	../libzip-0.11.2/configure --host=${BUILDCHAIN} --prefix=${PREFIX} --enable-static --disable-shared
	make
	make install
	popd
fi

if [ ! -e libgit2-0.20.0.tar.gz ] ; then
	wget -O libgit2-0.20.0.tar.gz https://github.com/libgit2/libgit2/archive/v0.20.0.tar.gz
fi
if [ ! -e libgit2-0.20.0 ] ; then
	tar -zxf libgit2-0.20.0.tar.gz
fi
if [ ! -e $PKG_CONFIG_PATH/libgit2.pc ] ; then
	mkdir -p libgit2-build-$ARCH
	pushd libgit2-build-$ARCH
	# -DCMAKE_CXX_COMPILER=arm-linux-androideabi-g++
	cmake -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_VERSION=Android -DCMAKE_C_COMPILER=${CC} -DCMAKE_FIND_ROOT_PATH=${PREFIX} -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DANDROID=ON -DSHA1_TYPE=builtin -DBUILD_CLAR=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=${PREFIX} ../libgit2-0.20.0/
	make
	make install
	popd
fi

if [ ! -e libusb/configure ] ; then
	pushd libusb
	autoreconf --install
	popd
fi

if [ ! -e $PKG_CONFIG_PATH/libusb-1.0.pc ] ; then
	mkdir -p libusb-build-$ARCH
	pushd libusb-build-$ARCH
	../libusb/configure --host=${BUILDCHAIN} --prefix=${PREFIX} --enable-static --disable-shared --disable-udev
	make
	make install
	popd
fi

if [ ! -e $PKG_CONFIG_PATH/libftdi1.pc ] ; then
	mkdir -p libftdi-build-$ARCH
	pushd libftdi-build-$ARCH
	cmake ../libftdi -DCMAKE_C_COMPILER=${CC} -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_PREFIX_PATH=${PREFIX} -DBUILD_SHARED_LIBS=OFF -DSTATICLIBS=ON -DPYTHON_BINDINGS=OFF -DDOCUMENTATION=OFF -DFTDIPP=OFF
	make
	make install
	popd
	# Remove the shared parts, We Like static!
	rm $PREFIX/lib/libftdi1.so*
	# Remove the pkg-config c++ wrappers, THAT WE DIDNT BUILD!
	rm $PKG_CONFIG_PATH/libftdipp1.pc
fi

if [ ! -e libdivecomputer/configure ] ; then
	pushd libdivecomputer
	autoreconf -i
	popd
fi

if [ ! -e $PKG_CONFIG_PATH/libdivecomputer.pc ] ; then
	mkdir -p libdivecomputer-build-$ARCH
	pushd libdivecomputer-build-$ARCH
	../libdivecomputer/configure --host=${BUILDCHAIN} --prefix=${PREFIX} --enable-static --disable-shared
	make
	make install
	popd
fi

mkdir -p subsurface-build-$ARCH
cd subsurface-build-$ARCH
# Copy the template code into subsurface.
cp -fr ../template/ android/
if [ ! -e Makefile ] ; then
	$QT5_ANDROID_BIN/qmake V=1 QT_CONFIG=+pkg-config ../subsurface
fi
make -j4
make install INSTALL_ROOT=android_build
# bug in androiddeployqt? why is it looking for something with the builddir in it?
ln -fs android-libsubsurface.so-deployment-settings.json android-libsubsurface-build-${ARCH}.so-deployment-settings.json
$QT5_ANDROID_BIN/androiddeployqt --output android_build
