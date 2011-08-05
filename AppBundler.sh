#!/bin/bash

#This script will create a portable App for Mac OS X.


set -e

export HAMMERDIR=$PWD
export WORKDIR=$HAMMERDIR/work
export PREFIX=$WORKDIR/local
export DEPS_SOURCE=$WORKDIR/build/deps
export MAKEOPTS="-j3"
export EMBER_APP="$HAMMERDIR/ember.app"
export DYLIBBUNDLER="$PREFIX/bin/dylibbundler"
export OPENAL_FRAMEWORK="/opt/local/Library/Frameworks/OpenAl.framework"

#install dylibbundler if its not installed
if [ ! -f $DYLIBBUNDLER ]; then
  #dylibbundler will automatically search every .dylib file used by a program,
  #then it will copy it to the given directory and set the absolute path to relative path.
  
  mkdir -p $DEPS_SOURCE
  cd $DEPS_SOURCE
  FILENAME="dylibbundler0.3.1.zip"
  wget -c http://switch.dl.sourceforge.net/project/macdylibbundler/macdylibbundler/0.3.1/$FILENAME
  unzip $FILENAME
  cd dylibbundler
  make
  cp dylibbundler $DYLIBBUNDLER
fi


if [ $# -eq 0 ] ; then
    echo "Usage: AppBundler.sh <command>"
    echo "Commands:"
    echo "  ember -  creates ember.app"

#bundle ember
elif [ $1 = "ember" ] ; then

  #prepare directories
  mkdir -p $EMBER_APP/Contents/MacOS
  mkdir -p $EMBER_APP/Contents/Frameworks
  mkdir -p $EMBER_APP/Contents/Plugins
  mkdir -p $EMBER_APP/Contents/libs
  mkdir -p $EMBER_APP/Contents/Resources
  
  #install App configuration file
  echo -e \
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n\
<plist version=\"1.0\">\n\
<dict>\n\
  <key>CFBundleGetInfoString</key>\n\
  <string>ember</string>\n\
  <key>CFBundleExecutable</key>\n\
  <string>ember.bin</string>\n\
  <key>CFBundleIdentifier</key>\n\
  <string>com.worldforge.ember</string>\n\
  <key>CFBundleName</key>\n\
  <string>ember</string>\n\
  <key>CFBundleIconFile</key>\n\
  <string>ember.png</string>\n\
  <key>CFBundleShortVersionString</key>\n\
  <string>0.6.1</string>\n\
  <key>CFBundleInfoDictionaryVersion</key>\n\
  <string>6.0</string>\n\
  <key>CFBundlePackageType</key>\n\
  <string>APPL</string>\n\
</dict>\n\
</plist>\n" > $EMBER_APP/Contents/Info.plist
 
  #install executable
  cp $PREFIX/bin/ember.bin $EMBER_APP/Contents/MacOS/ember.bin
  
  #install media
  cp -r $PREFIX/etc $EMBER_APP/Contents/Resources
  cp -r $PREFIX/share/ember/media $EMBER_APP/Contents/Resources
  cp $PREFIX/share/icons/worldforge/ember.png $EMBER_APP/Contents/Resources/ember.png
  
  #install libraries
  $DYLIBBUNDLER -od -b -x $EMBER_APP/Contents/MacOS/ember.bin -d $EMBER_APP/Contents/libs
  
  #install Ogre plugins
  cp -r $PREFIX/lib/Plugin_* $EMBER_APP/Contents/Plugins
  cp $PREFIX/lib/RenderSystem_GL.dylib $EMBER_APP/Contents/Plugins/RenderSystem_GL.dylib
  
  #install frameworks
  cp -r $PREFIX/lib/Ogre.framework $EMBER_APP/Contents/Frameworks
  cp -r $OPENAL_FRAMEWORK $EMBER_APP/Contents/Frameworks
fi