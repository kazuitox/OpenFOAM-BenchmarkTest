#!/bin/sh

if [ $# -ne 1 ];then
    echo "Usage: $0 case"
    exit 0
fi

case=$1

rm -f Allrun.* Allclean all.sh
ln -s ../$case/Allrun.* .
ln -s ../$case/Allclean .
ln -s ../$case/all.sh .
ln -s ../$case/case.sh .
mkdir -p share/batchScript/solve share/decomposeParDict
(cd share/batchScript/solve;rm -f template;ln -s ../../../../$case/share/batchScript/solve/template .)
(cd share/batchScript;rm -f *.sh;ln -s ../../../$case/share/batchScript/*.sh .)
(cd share/decomposeParDict;rm -f template;ln -s ../../../$case/share/decomposeParDict/template .)
(cd share;rm -rf fvSolution;ln -s ../../$case/share/fvSolution .)
