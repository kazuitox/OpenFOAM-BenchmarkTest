#!/bin/bash

usage() {
    cat<<USAGE

Usage: ${0##*/} [CONFIGURATION_FILE_NAME]
USAGE
    exit 1
}

# MAIN SCRIPT
#~~~~~~~~~~~~

if [ "$#" -ne 1 ];then
    usage
    exit 1
fi
configuration=$1
if [ ! -f $configuration ]
then
    echo "Error: $configuration does not exist."
    exit 1
fi
. $configuration

caseDir=cases
application=`sed -ne 's/^ *application[ \t]*\([a-zA-Z]*\)[ \t]*;.*$/\1/p' cases/system/controlDict`
decomposeParDictList=`echo ${decomposeParDictArray[@]} | tr ' ' '\n' | sort -d | tr '\n' ' '`
fvSolutionList=`echo ${fvSolutionArray[@]} | tr ' ' '\n' | sort -d | tr '\n' ' '`
solveBatchList=`echo ${solveBatchArray[@]} | tr ' ' '\n' | sort -d | tr '\n' ' '`

for decomposeParDict in $decomposeParDictList
do
    for fvSolution in $fvSolutionList
    do
	for solveBatch in $solveBatchList
	do
	    Dir=$caseDir/$decomposeParDict/$fvSolution/$solveBatch
	    n=1
	    for log in `ls $Dir/log.${application}.*[0-9]* 2> /dev/null`
	    do
		case $log in
		    *.done|*.queue|*.vtune|*.vtune.csv|*~)
			continue
			;;
		esac
		grep "^Exec *: $application" $log >& /dev/null || continue 
		grep "^End" $log >& /dev/null || continue 
		[ -f $log.done ] || continue 

		newlog=$Dir/log.${application}.No${n}

  		awk -F ' ' 'BEGIN {n=0}
                {
                  if ($1=="Build") n=1;
                  if (n==1) {
                    if ($1=="Host")
                      { $0="Host   :"}
                    else if ($1=="Case")
                      { $0="Case   :"}
                    else if ($1 ~ /["]/)
                      { $0="\"\"" }
                    else if ($0 ~ /^\s+Reading /)
                      { gsub(/\/.*\//,"") }
                    print $0;
                  };
                  if ($1=="End") {n=0};
                }' $log > $newlog

		logs="$logs $newlog"

		n=`expr $n + 1`
	    done
	done
    done
done

tar jcf $configuration.tar.bz2 $logs cases/system/controlDict
for log in $logs;do rm -f $log;done
