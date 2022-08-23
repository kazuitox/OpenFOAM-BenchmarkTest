#!/bin/bash

if [ $# -ne 1 ];then
    echo "Usage: $0 decomposedCase"
    exit 0
fi

name=$1

mkdir cases
cd cases
cp -a ../../$name/cases/system ./
rm -f {0,constant}
ln -s ../../$name/cases/{0,constant} ./
touch pre.sh.done
for mpi in ../../$name/cases/mpi_*
do
    dir=${mpi##*/}
    mkdir $dir
    cd $dir
    rm -f {0,constant,system,processor*}
    ln -s ../../../$name/cases/$dir/{0,constant,system,processor*}  ./
    rm -f decomposePar.sh*
    touch decomposePar.sh.done
    cd ..
done


