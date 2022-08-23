#!/bin/bash

set -eu
atexit() {
      [[ -n $logs ]] && for log in $logs;do rm -f $log;done
}
logs=""
trap atexit EXIT
trap 'trap - EXIT; atexit; exit -1' SIGHUP SIGINT SIGTERM

usage() {
    cat<<USAGE

Usage: ${0##*/} [OPTION] [CONFIGURATION_FILE_NAME]
options:
  -a         analyze all log files.
  -h         print the usage

CONFIGURATION_FILE_NAME is required if "-a" option is not provided.
USAGE
    exit 1
}

# MAIN SCRIPT
#~~~~~~~~~~~~
allOpt=false

# parse options
while [ "$#" -gt 0 ]
do
   case "$1" in
   -h)
      usage
      ;;
   -a)
      allOpt=true
      shift
      ;;
   -*)
      usage "invalid option '$1'"
      ;;
   *)
      break
      ;;
   esac
done

# Source configuration file
if [  "$allOpt" = true ];then
    if [ "$#" -ne 0 ];then
	usage
	exit 1
    fi
    configuration="all"
else
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
fi

caseDir=cases
csvFile=$configuration.csv
decomposeParDictDir=$PWD/share/decomposeParDict

application=`sed -ne 's/^ *application[ \t]*\([a-zA-Z]*\)[ \t]*;.*$/\1/p' cases/system/controlDict`

line="#decomposeParDict,method,fvSolution,solveBatch,log"
line="$line,Build,Date,Time,nNodes,nProcs"
line="$line,CoMean,CoMax"
line="$line,UxInitRes,UxFinalRes,UxNoIter"
line="$line,UyInitRes,UyFinalRes,UyNoIter"
line="$line,UzInitRes,UzFinalRes,UzNoIter"
line="$line,UNoIterSum"
line="$line,p0InitRes,p0FinalRes,p0NoIter"
line="$line,p1InitRes,p1FinalRes,p1NoIter"
line="$line,pNoIterSum"
line="$line,contErrSumLocal0,contErrGlobal0,contErrCum0"
line="$line,contErrSumLocal1,contErrGlobal1,contErrCum1"
line="$line,Steps"
line="$line,ClockTimeFirstStep,ClockTimeNextToLastStep,ClockTimeLastStep"
line="$line,ExecutionTimeFirstStep,ExecutionTimeNextToLastStep,ExecutionTimeLastStep"
line="$line,ClockTimePerStepWOLastStep,ClockTimePerStep"
line="$line,ExecutionTimePerStepWOLastStep,ExecutionTimePerStep"

echo $line > $csvFile

if [  "$allOpt" = true ];then
    decomposeParDictList=`cd $caseDir;ls -d */ | tr -d '/' | egrep -v '^(processor[0-9]*|0|constant|plot|system)'`
    fvSolutionList=`cd share/fvSolution;echo *`
    solveBatchList=`cd share/batchScript/solve;echo * | egrep -v '^template'`
else
    decomposeParDictList=`echo ${decomposeParDictArray[@]} | tr ' ' '\n' | sort -d | tr '\n' ' '`
    fvSolutionList=`echo ${fvSolutionArray[@]} | tr ' ' '\n' | sort -d | tr '\n' ' '`
    solveBatchList=`echo ${solveBatchArray[@]} | tr ' ' '\n' | sort -d | tr '\n' ' '`
fi

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
		case $log  in
		    *.done|*.queue|*.vtune|*.vtune.csv|*~)
			continue
			;;
		esac
		grep "^Exec *: $application" $log >& /dev/null || continue 
		grep "^End" $log >& /dev/null || continue 
		[ -f $log.done ] || continue 
		echo $log

		decomposeParDictFile=$decomposeParDictDir/$decomposeParDict		
		method=`grep '^ *method ' $decomposeParDictFile | sed "s/^[ 	]*method[ 	]*\([^ 	]*\);.*/\1/"`

		BuildDataTime=`awk -F ' : ' '\
                /^Build  *:/ {Build=$2} \
                /^Date *:/ {Date=$2} \
                /^Time *:/ {Time=$2} \
                END {printf "%s,%s,%s",Build,Date,Time}' $log`
		nProcs=`grep '^nProcs  *:' $log | sed "s/.*: \(.*\)$/\1/"`
		Host=`grep '^Host  *:' $log | sed "s/.*: *\(.*\)$/\1/" | tr -d '"'`
		Slave=`grep '^Slave *: 1(' $log | sed "s/.*: \"\(.*\)\".*/\1/"`
		if [ -z "$Slave" ]
		then
		    Slave=`sed -e '/^Slave/,/.*)/!d' $log | grep "^\""  | sed -e "s/^\"//" -e "s/\.[^\.]*$//"`
		    if [ -z "$Slave" ]
		    then
			Slave=`sed -e '/^Hosts/,/^)/!d' $log | grep "^\ "  | sed -e "s/^ *(//" -e "s/ [0-9]*)$//"`
		    fi
		fi
		nNodes=`echo $Host $Slave | tr ' ' '\n' | sort | uniq | wc -l`
		Co=`grep "^Courant Number" $log | tail -n 1 | cut -d ' ' -f 4,6 | tr ' ' ','`
		Ux=`grep "Solving for Ux," $log | tail -n 1 | cut -d ' ' -f 9,13,16 | tr -d ' '`
		Uy=`grep "Solving for Uy," $log | tail -n 1 | cut -d ' ' -f 9,13,16 | tr -d ' '`
		Uz=`grep "Solving for Uz," $log | tail -n 1 | cut -d ' ' -f 9,13,16 | tr -d ' '`
		UNoIterSum=`awk '/Solving for U/ {n+=$15} END {print n}' < $log`
		p0=`grep "Solving for p," $log | tail -n 2 | head -n 1 | cut -d ' ' -f 9,13,16 | tr -d ' '`
		p1=`grep "Solving for p," $log | tail -n 1 | cut -d ' ' -f 9,13,16 | tr -d ' '`
		pNoIterSum=`awk '/Solving for p/ {n+=$15} END {print n}' < $log`
		err0=`grep "^time step continuity errors" $log \
                  | tail -n 2 | head -n 1 | cut -d ' ' -f 9,12,15  | tr -d ' '`
		err1=`grep "^time step continuity errors" $log \
                  | tail -n 1 | cut -d ' ' -f 9,12,15  | tr -d ' '`
		ExecutionTime=`awk 'BEGIN {n=0;t=0;c=0} \
		/^ExecutionTime/ {told=t;t=$3;cold=c;c=$7;n++;if (n==1) {t1=t;c1=c}} \
		END {printf "%d,%g,%g,%g,%g,%g,%g,%g,%g,%g,%g"\
                ,n\
                ,c1,cold,c\
                ,t1,told,t\
                ,(cold-c1)/(n-2),(c-c1)/(n-1)\
                ,(told-t1)/(n-2),(t-t1)/(n-1)\
                }' \
		$log`

		newlog=$Dir/log.${application}.No${n}
		    
		line="$decomposeParDict,$method,$fvSolution,$solveBatch,${newlog##*/}"
		line="$line,$BuildDataTime"
		line="$line,$nNodes,$nProcs"
    	        line="$line,$Co,$Ux,$Uy,$Uz,$UNoIterSum,$p0,$p1,$pNoIterSum,$err0,$err1"
		line="$line,$ExecutionTime"
		echo $line >> $csvFile
		
		n=`expr $n + 1`
	    done
	done
    done
done
