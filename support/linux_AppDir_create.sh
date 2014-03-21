#!/bin/bash

# Script to create, and copy appropriate libraries into, the AppDir 
# directory; thus to allow creation of an ember AppImage.
# This script assumes that the AppImageKit source directory is installed 
# in the same parent directory that the hammer directory is installed in.
# Incorporates portions of linux_release_bundle.sh by the WorldForge project.
# This script is designed to be run from hammer.sh, 
# running it directly is NOT recommended.
# Copyright: 2013-2014 Olek Wojnar
# License: GPL-2+

APP_DIR="$APP_DIR_ROOT/usr"
EMBER_BIN="$APP_DIR/bin/ember.bin"

# Create and populate the AppDir

mkdir -p $APP_DIR
cd $APP_DIR_ROOT
curl -OL https://raw.github.com/worldforge/ember/master/ember.desktop
curl -OL https://raw.github.com/worldforge/ember/master/media/ember.png
cp -a "ember.png" ".DirIcon"
cp $HAMMERDIR/../AppImageKit/AppRun .


####Adapted from linux_release_bundle.sh####
#This script will copy everything from work/local to the AppDir.
#It will recursively detect all ember dependencies, 
#which are installed into the $PREFIX directory.
#Also, it will automatically resolve symlinks and copy the file only, 
#because symlinks are not rpath compatible.

export LD_LIBRARY_PATH=$PREFIX/lib
if [ ! -d $PREFIX/lib ] ; then
  echo "Error: $PREFIX/lib directory does not exist!"
  exit 1
fi

mkdir -p $APP_DIR/bin
cp $PREFIX/bin/ember $APP_DIR/bin/ember
cp $PREFIX/bin/ember.bin $APP_DIR/bin/ember.bin

mkdir -p $APP_DIR/etc/ember
cp -r $PREFIX/etc/ember/* $APP_DIR/etc/ember

mkdir -p $APP_DIR/share/ember
cp -r $PREFIX/share/ember/* $APP_DIR/share/ember

#copy Ogre plugins and cg, which are not found automatically by the linker.
mkdir -p $APP_DIR/lib/OGRE
cp $PREFIX/lib/OGRE/Plugin_CgProgramManager.so $APP_DIR/lib/OGRE
cp $PREFIX/lib/OGRE/Plugin_OctreeSceneManager.so $APP_DIR/lib/OGRE
cp $PREFIX/lib/OGRE/Plugin_ParticleFX.so $APP_DIR/lib/OGRE
cp $PREFIX/lib/OGRE/RenderSystem_GL.so $APP_DIR/lib/OGRE
cp $PREFIX/lib/libCg.so $APP_DIR/lib

#remove temporary work file.
if [ -f tmp_ldd.txt ] ; then
  rm tmp_ldd.txt
fi
touch tmp_ldd.txt

function is_processed()
{
  cat tmp_ldd.txt | while read line2 ; do
    if [ "$line2" == "$1" ] ; then
      echo yes
      break;
    fi
  done
}

#lists all dependencies recursively which are installed in $PREFIX 
function list_deps()
{
  echo "`ldd \"$1\"`" | while read line ; do
    if [[ $line == *"${PREFIX}"* ]] ; then
      
      #cut text until > character
      line="`echo $line | cut -s -d '>' -f 2`"
      #cut text after ( character
      line="`echo $line | cut -s -d '(' -f 1`"
      #trim
      line="`echo $line`"

      if [ "$line" != "" ] && [ -f $line ] ; then
        #check in the tested list if it was already processed(endless loop protection)
        ret="`is_processed $line`"
        if [ "$ret" != "yes" ] ; then
          echo $line >> tmp_ldd.txt
          echo $line
          list_deps $line
        fi
      fi
    fi
  done
}

function copy_sharedlib()
{
  echo "copying $1"
  if [ -s "$1" ] ; then
    loc="`readlink -f $1`"
  else
    loc="$1"
  fi
  out="$APP_DIR/lib/`basename \"$1\"`"
  cp "$loc" "$out" 
  chmod 0755 "$out"
  chrpath -r "../lib:lib" "$out" || true
}
echo "Recursively obtaining ember dependencies."
list_deps "$APP_DIR/bin/ember.bin" | while read line; do copy_sharedlib "$line"; done

#remove temporary work file.
if [ -f tmp_ldd.txt ] ; then
  rm tmp_ldd.txt
fi
####End adapted from linux_release_bundle.sh####


cd $APP_DIR/lib

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

rm $APP_DIR/lib/ld-linux*
rm $APP_DIR/lib/libc.so*
rm $APP_DIR/lib/libdl.so*
rm $APP_DIR/lib/libGL.so*
rm $APP_DIR/lib/libglapi.so*
rm $APP_DIR/lib/libm.so*
rm $APP_DIR/lib/libpthread.so*
rm $APP_DIR/lib/libresolv.so*
rm $APP_DIR/lib/librt.so*
rm $APP_DIR/lib/librtmp.so*
rm $APP_DIR/lib/libX11.so*

cp -d $PREFIX/lib/libCEGUI* $APP_DIR/lib
cp -r $PREFIX/lib/cegui* $APP_DIR/lib
