#!/bin/bash

getApplication()
{
    sed -ne 's/^ *application\s*\([^s]*\)\s*;.*$/\1/p' system/controlDict
}

LimitNumberOfBatchQueue()
{
    while :
    do
	nq=$(NumberOfBatchQueue)
        [ "$nq" -lt "$MAX_NUMBER_OF_QUEUE" ] &&  break
	sleep 5
    done
}

BatchSubmitAndWait()
{
    local batchFile=$1
    local mpi=$2

    local batchFileDone=$batchFile.done
    if [ ! -f $batchFileDone ];then
	LimitNumberOfBatchQueue
	BatchSubmit $batchFile $mpi
	
	while [ ! -f $batchFileDone ];do
	    sleep 5
	done
    fi
}

if [ "$#" -ne 1 ];then
        cat<<USAGE
Usage: ${0##*/} configuration
USAGE
    exit 1
fi

# Source configuration file
configuration=$1
if [ ! -f $configuration ]
then
    echo "Error: $configuration does not exist."
    exit 1
fi
. $configuration

batchScriptDir=$PWD/share/batchScript
solveBatchScriptDir=$batchScriptDir/solve
decomposeParDictDir=$PWD/share/decomposeParDict
fvSolutionDir=$PWD/share/fvSolution
preBatchFile=$batchScriptDir/pre.sh
decomposeParBatchFile=$batchScriptDir/decomposePar.sh

for file in $preBatchFile $decomposeParBatchFile
do
    if [ ! -f $file ];then
	echo "Error: $file does not exist."
	exit 1
    fi
done

[ ! -d cases ] && makeCases

(
    cd cases

    batchFile=pre.sh
    cp $preBatchFile $batchFile
    chmod +x $batchFile
    if [ $BATCH_PRE -eq 1 ];then
	BatchSubmitAndWait $batchFile 1
    else
	batchFileDone=$batchFile.done
	if [ ! -f $batchFileDone ];then
	    ./$batchFile $$
	fi
    fi

    loop=1
    while [ "$loop" -le "$MAX_NUMBER_OF_LOOP" ]
    do
	echo "loop= $loop"

	for decomposeParDict in ${decomposeParDictArray[@]}
	do
	    echo "decomposeParDict= $decomposeParDict"

	    decomposeParDictFile=$decomposeParDictDir/$decomposeParDict
	    if [ ! -f  $decomposeParDictFile ];then
		echo "Cannot find $decomposeParDictFile. "
		if [ "${decomposeParDict##*-}" == "method_scotch" ]
		then
		    echo "Generating from template file."
		    mpitmp=${decomposeParDict%%-*}
		    mpitmp=`echo ${mpitmp#mpi_} | bc`
		    sed s/"\(numberOfSubdomains[ \t]\)[0-9]*;"/"\1 $mpitmp;"/ $decomposeParDictDir/template > $decomposeParDictFile 
		else
		    echo "Skip running."
		    continue
		fi
	    fi

	    mpi=`sed -ne 's/^numberOfSubdomains[ \t]*\(.*\);/\1/p' $decomposeParDictFile`
	    echo "mpi= $mpi"

	    if [ ! -d $decomposeParDict ];then
		mkdir $decomposeParDict
		(cd $decomposeParDict
		    for dir in 0 constant system
		    do
			mkdir $dir
			(cd $dir 
			    ln -s ../../$dir/* ./
			)
		    done
		)
	    fi
		
	    (cd $decomposeParDict
		rm -f system/decomposeParDict
		cp $decomposeParDictFile system/decomposeParDict

		if [ "$mpi" -gt 1 ];then
		    batchFile=decomposePar.sh
		    cp $decomposeParBatchFile $batchFile
		    chmod +x $batchFile
		    if [ $BATCH_DECOMPOSEPAR -eq 1 ];then
			BatchSubmitAndWait $batchFile $mpi
		    else
			batchFileDone=$batchFile.done
			if [ ! -f $batchFileDone ];then
			    ./$batchFile $$
			fi
		    fi
		fi

		for fvSolution in ${fvSolutionArray[@]}
		do
		    echo "fvSolution= $fvSolution"

		    fvSolutionFile=$fvSolutionDir/$fvSolution
		    if [ ! -f $fvSolutionFile ];then
			echo "Cannot find $fvSolutionFile. Skip running"
			continue
		    fi

		    if [ ! -d $fvSolution ];then
			mkdir $fvSolution
		    fi

		    (cd $fvSolution
			echo "dir= cases/$decomposeParDict/$fvSolution"

			[ -d system ] || mkdir system
			cp $fvSolutionFile system/fvSolution

			for solveBatch in ${solveBatchArray[@]}
			do
			    echo "solveBatch= $solveBatch"

			    solveBatchFile=$solveBatchScriptDir/$solveBatch
			    if [ ! -f  $solveBatchFile ];then
				echo "Cannot find $solveBatchFile."
				templateFile=$solveBatchScriptDir/template
				if [ -f $templateFile ];then
				    echo "Copy template file."
				    cp -a $templateFile $solveBatchFile 
				else
				    echo "Cannot find $templateFile. Skip running"
				    continue
				fi
			    fi

			    [ -d $solveBatch ] || mkdir $solveBatch

			    (cd $solveBatch
				echo "dir= cases/$decomposeParDict/$fvSolution/$solveBatch"

				cp $solveBatchFile ./
				chmod +x $solveBatchFile

				application=`cd ../../../;getApplication`
				echo "application= $application"
				ndone=`ls log.${application}.*.done 2> /dev/null | wc -l`
				nqueue=`ls log.${application}.$$.*.queue  2> /dev/null | wc -l`
				ndoneAndQueue=`expr $ndone + $nqueue`
				echo "ndoneAndQueue = $ndoneAndQueue (ndone = $ndone, nqueue = $nqueue)"
				if [ "$ndoneAndQueue" -ge "$MAX_NUMBER_OF_LOOP" ];then
				    echo "Already run in $MAX_NUMBER_OF_LOOP time(s). Skip running"
				    continue
				fi

				rm -f 0 constant
				ln -s ../../../{0,constant} .
				rm -rf system
				mkdir system
				(cd system
				    rm -f *
				    ln -s ../../../../system/* .
				    rm -f fvSolution
				    ln -s ../../system/fvSolution .
				    rm -f decomposeParDict
				    ln -s ../../../system/decomposeParDict
				)
				if [ -d ../../processor0 ];then
				    rm -rf processor[0-9]*
				    for dir in ../../processor[0-9]*
				    do
					processorDir=${dir##*/}
					mkdir $processorDir
					(cd $processorDir
					    ln -s ../../../$processorDir/{0,constant} ./
					)
				    done
				fi

				if [ $BATCH_SOLVE -eq 1 ];then
				    LimitNumberOfBatchQueue
				    BatchSubmit $solveBatch $mpi
				    touch log.${application}.$$.$loop.queue
				else
				    GenerateHostFile $mpi
				    ./$solveBatch $mpi $$_$loop
				fi
			    )
			done
		    )
		done
	    )
	done
	loop=`expr $loop + 1`
    done
)
