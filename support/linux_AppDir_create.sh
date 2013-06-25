#!/bin/bash

# Script to copy appropriate libraries into the release directory 
# to allow creation of an ember AppDir and AppImage.
# Copyright: 2013 Olek Wojnar
# License: GPL-2+

. $PWD/support/linux_release_bundle.sh

EMBER_BIN="$REL/bin/ember.bin"
APP_DIR="$PWD/Ember.AppDir"

cd $REL/lib

for LIBNAME in `ldd $EMBER_BIN | grep -o "/.*\s" ` 
do 
	echo $LIBNAME 
	cp -uL $LIBNAME .
done

#count number of libraries which could not be found
LIBMISSING=0
echo "The following libraries could not be located:"

for LIBNAME in `ldd $EMBER_BIN | grep "not found" | cut -d= -f1 `
do 
        echo "    " $LIBNAME
        LIBMISSING=$(($LIBMISSING+1))
done

if [ "$LIBMISSING" -gt 0 ]; then
  echo "The above $LIBMISSING libraries could not be located in the ldd search path."
  echo "Please manually copy them to the hammer/release/lib folder."
else
  echo "None"
fi

# Manually add and remove libraries which don't behave appropriately.

rm $REL/lib/ld-linux*
rm $REL/lib/libc.so*
rm $REL/lib/libdl.so*
rm $REL/lib/libGL.so*
rm $REL/lib/libglapi.so*
rm $REL/lib/libm.so*
rm $REL/lib/libpthread.so*
rm $REL/lib/libresolv.so*
rm $REL/lib/librt.so*
rm $REL/lib/librtmp.so*
rm $REL/lib/libX11.so*

cp $WORK/lib/libCEGUIFalagardWRBase* $REL/lib
cp $WORK/lib/libCEGUIFreeImageImageCodec* $REL/lib
cp $WORK/lib/libCEGUITinyXMLParser* $REL/lib

# Create and populate the AppDir

mkdir -p $APP_DIR/usr
cd $APP_DIR
cp -r $REL/* usr
curl -OL https://raw.github.com/worldforge/ember/master/ember.desktop
curl -OL https://raw.github.com/worldforge/ember/master/media/ember.png
cp -a "ember.png" ".DirIcon"
