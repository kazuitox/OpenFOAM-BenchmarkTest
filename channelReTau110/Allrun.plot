#!/bin/sh

for dir in $*
do
    echo $dir
    cd $dir
    ./Allrun.plot
    base=`basename ${PWD}`
    open ${base}.pdf
    cd ..
done

