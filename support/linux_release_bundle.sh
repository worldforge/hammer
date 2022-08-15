#!/bin/bash

# This script will copy everything from work/local to work/release; it will also
# recursively detect all ember dependencies which are installed in the $WORK dir.
# It will also automatically resolve symlinks and copies the file only, because symlinks are not rpath compatible.

WORK="$PWD/work/local"
REL="$PWD/work/release"

export LD_LIBRARY_PATH="$WORK/lib"
if [ ! -d $WORK/lib ] ; then
  echo "Error: $WORK/lib directory does not exist!"
  exit 1
fi

mkdir -p $REL/bin
cp $WORK/bin/ember $REL/bin/ember
cp $WORK/bin/ember.bin $REL/bin/ember.bin

mkdir -p $REL/etc/ember
cp -r $WORK/etc/ember/* $REL/etc/ember

mkdir -p $REL/share/ember
cp -r $WORK/share/ember/* $REL/share/ember

#copy Ogre plugins and cg, which are not found automatically by the linker.
mkdir -p $REL/lib/OGRE
cp $WORK/lib/OGRE/Plugin_CgProgramManager.so $REL/lib/OGRE
cp $WORK/lib/OGRE/Plugin_OctreeSceneManager.so $REL/lib/OGRE
cp $WORK/lib/OGRE/Plugin_ParticleFX.so $REL/lib/OGRE
cp $WORK/lib/OGRE/RenderSystem_GL.so $REL/lib/OGRE

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
#lists all dependencies recursively which are installed in $WORK prefix
function list_deps()
{
  echo "`ldd \"$1\"`" | while read line ; do
    if [[ $line == *"${WORK}"* ]] ; then
      
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
  out="$REL/lib/`basename \"$1\"`"
  cp "$loc" "$out" 
  chmod 0755 "$out"
  chrpath -r "../lib:lib" "$out" || true
}
echo "gettings ember dependencies recursively"
list_deps "$REL/bin/ember.bin" | while read line; do copy_sharedlib "$line"; done


fi

#remove temporary work file.
if [ -f tmp_ldd.txt ] ; then
  rm tmp_ldd.txt
fi

