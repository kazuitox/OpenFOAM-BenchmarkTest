#!/bin/bash

function generate_fvSolution () {
    if [  "$fvSolution_solvers_p_solver" = "PCG" -o "$fvSolution_solvers_p_solver" = "PPCG" -o "$fvSolution_solvers_p_solver" = "PPCR" ]
    then
	if [ "$fvSolution_solvers_p_preconditioner" = "GAMG" ]
	then
	    fvSolution_solvers_p_preconditioner_smoother=`cat << EOM
        preconditioner {
            preconditioner  $fvSolution_solvers_p_preconditioner;
            smoother $fvSolution_solvers_p_smoother;
            agglomerator $fvSolution_solvers_p_agglomerator;
            cacheAgglomeration $fvSolution_solvers_p_cacheAgglomeration;
            interpolateCorrection $fvSolution_solvers_p_interpolateCorrection;
            maxPostSweeps $fvSolution_solvers_p_maxPostSweeps;
            maxPreSweeps $fvSolution_solvers_p_maxPreSweeps;
            mergeLevels $fvSolution_solvers_p_mergeLevels;
            nCellsInCoarsestLevel $fvSolution_solvers_p_nCellsInCoarsestLevel;
            nFinestSweeps $fvSolution_solvers_p_nFinestSweeps;
            nPostSweeps $fvSolution_solvers_p_nPostSweeps;
            nPreSweeps $fvSolution_solvers_p_nPreSweeps;
            postSweepsLevelMultiplier $fvSolution_solvers_p_postSweepsLevelMultiplier;
            preSweepsLevelMultiplier $fvSolution_solvers_p_preSweepsLevelMultiplier;
            directSolveCoarsest $fvSolution_solvers_p_directSolveCoarsest;
            nVcycles $fvSolution_solvers_p_nVcycles;
        }
EOM
`
	else
	    fvSolution_solvers_p_preconditioner_smoother="preconditioner $fvSolution_solvers_p_preconditioner;"
	fi
    elif [ "$fvSolution_solvers_p_solver" = "GAMG" ]
    then
	fvSolution_solvers_p_preconditioner_smoother=`cat << EOM
        smoother $fvSolution_solvers_p_smoother;
        agglomerator $fvSolution_solvers_p_agglomerator;
        cacheAgglomeration $fvSolution_solvers_p_cacheAgglomeration;
        interpolateCorrection $fvSolution_solvers_p_interpolateCorrection;
        maxPostSweeps $fvSolution_solvers_p_maxPostSweeps;
        maxPreSweeps $fvSolution_solvers_p_maxPreSweeps;
        mergeLevels $fvSolution_solvers_p_mergeLevels;
        nCellsInCoarsestLevel $fvSolution_solvers_p_nCellsInCoarsestLevel;
        nFinestSweeps $fvSolution_solvers_p_nFinestSweeps;
        nPostSweeps $fvSolution_solvers_p_nPostSweeps;
        nPreSweeps $fvSolution_solvers_p_nPreSweeps;
        postSweepsLevelMultiplier $fvSolution_solvers_p_postSweepsLevelMultiplier;
        preSweepsLevelMultiplier $fvSolution_solvers_p_preSweepsLevelMultiplier;
        directSolveCoarsest $fvSolution_solvers_p_directSolveCoarsest;
        coarsestLevelCorr
        {
            preconditioner DIC;
            solver $fvSolution_solvers_p_coarsestLevelCorr_solver;
            relTol $fvSolution_solvers_p_coarsestLevelCorr_relTol;
        }
EOM
`
    fi
    if [ "$fvSolution_solvers_pFinal_solver" = "PCG" -o "$fvSolution_solvers_pFinal_solver" = "PPCG" -o "$fvSolution_solvers_pFinal_solver" = "PPCR" ]
    then
	if [ "$fvSolution_solvers_pFinal_preconditioner" = "GAMG" ]
	then
	    fvSolution_solvers_pFinal_preconditioner_smoother=`cat << EOM
        preconditioner {
            preconditioner  $fvSolution_solvers_pFinal_preconditioner;
            smoother $fvSolution_solvers_pFinal_smoother;
            agglomerator $fvSolution_solvers_pFinal_agglomerator;
            cacheAgglomeration $fvSolution_solvers_pFinal_cacheAgglomeration;
            interpolateCorrection $fvSolution_solvers_pFinal_interpolateCorrection;
            maxPostSweeps $fvSolution_solvers_pFinal_maxPostSweeps;
            maxPreSweeps $fvSolution_solvers_pFinal_maxPreSweeps;
            mergeLevels $fvSolution_solvers_pFinal_mergeLevels;
            nCellsInCoarsestLevel $fvSolution_solvers_pFinal_nCellsInCoarsestLevel;
            nFinestSweeps $fvSolution_solvers_pFinal_nFinestSweeps;
            nPostSweeps $fvSolution_solvers_pFinal_nPostSweeps;
            nPreSweeps $fvSolution_solvers_pFinal_nPreSweeps;
            postSweepsLevelMultiplier $fvSolution_solvers_pFinal_postSweepsLevelMultiplier;
            preSweepsLevelMultiplier $fvSolution_solvers_pFinal_preSweepsLevelMultiplier;
            directSolveCoarsest $fvSolution_solvers_pFinal_directSolveCoarsest;
            nVcycles $fvSolution_solvers_pFinal_nVcycles;
        }
EOM
`
	else
	    fvSolution_solvers_pFinal_preconditioner_smoother="preconditioner $fvSolution_solvers_pFinal_preconditioner;"
	fi
    elif [ "$fvSolution_solvers_pFinal_solver" = "GAMG" ]
    then
	fvSolution_solvers_pFinal_preconditioner_smoother=`cat << EOM
        smoother $fvSolution_solvers_pFinal_smoother;
        agglomerator $fvSolution_solvers_pFinal_agglomerator;
        cacheAgglomeration $fvSolution_solvers_pFinal_cacheAgglomeration;
        interpolateCorrection $fvSolution_solvers_pFinal_interpolateCorrection;
        maxPostSweeps $fvSolution_solvers_pFinal_maxPostSweeps;
        maxPreSweeps $fvSolution_solvers_pFinal_maxPreSweeps;
        mergeLevels $fvSolution_solvers_pFinal_mergeLevels;
        nCellsInCoarsestLevel $fvSolution_solvers_pFinal_nCellsInCoarsestLevel;
        nFinestSweeps $fvSolution_solvers_pFinal_nFinestSweeps;
        nPostSweeps $fvSolution_solvers_pFinal_nPostSweeps;
        nPreSweeps $fvSolution_solvers_pFinal_nPreSweeps;
        postSweepsLevelMultiplier $fvSolution_solvers_pFinal_postSweepsLevelMultiplier;
        preSweepsLevelMultiplier $fvSolution_solvers_pFinal_preSweepsLevelMultiplier;
        directSolveCoarsest $fvSolution_solvers_pFinal_directSolveCoarsest;
        coarsestLevelCorr
        {
            preconditioner DIC;
            solver $fvSolution_solvers_pFinal_coarsestLevelCorr_solver;
            relTol $fvSolution_solvers_pFinal_coarsestLevelCorr_relTol;
        }
EOM
`
    fi
    if [ "$fvSolution_solvers_UFinal_solver" = "smoothSolver" ]
    then
	fvSolution_solvers_UFinal_preconditioner_smoother="smoother $fvSolution_solvers_UFinal_smoother;"
    elif [ "$fvSolution_solvers_UFinal_solver" = "PBiCG" ]
    then
	fvSolution_solvers_UFinal_preconditioner_smoother="preconditioner $fvSolution_solvers_UFinal_preconditioner;"
    fi
    rm -f include/fvSolution
    cat > include/fvSolution <<EOF
solvers
{
  p
  {
    maxIter 5000;
    tolerance 1e-6;
    relTol $fvSolution_solvers_p_relTol;
    solver $fvSolution_solvers_p_solver;
$fvSolution_solvers_p_preconditioner_smoother
  }
  pFinal
  {
    maxIter 5000;
    tolerance 1e-6;
    relTol 0;
    solver $fvSolution_solvers_pFinal_solver;
$fvSolution_solvers_pFinal_preconditioner_smoother
  }
  UFinal
  {
    maxIter 5000;
    tolerance 1e-05;
    relTol 0;
    solver $fvSolution_solvers_UFinal_solver;
$fvSolution_solvers_UFinal_preconditioner_smoother
  }
}
PIMPLE
{
  nOuterCorrectors 1;
  nCorrectors 2;
  nNonOrthogonalCorrectors 0;
  pRefCell 0;
  pRefValue 0;
}
EOF
}

function generate_batch_and_include_files () {
    (
    cat <<EOF
#!/bin/bash
source /usr/mpi/gcc/openmpi-4.0.3rc4/bin/mpivars.sh
source /share/app/OpenFOAM/OpenFOAM-v2206/etc/bashrc
mpiexec --bind-to core --rank-by core --map-by core --display-map -mca pml ucx -x UCX_NET_DEVICES=mlx5_2:1 -x UCX_IB_TRAFFIC_CLASS=105 -x UCX_IB_GID_INDEX=3 -x HCOLL_ENABLE_MCAST_ALL=0 -x coll_hcoll_enable=0 --mca coll_hcoll_enable 0 --hostfile /data/imano/OpenFOAM-BenchmarkTest/channelReTau110/kazuito_v2206_ompi/hostfile -n $numberOfSubdomains pimpleFoam -parallel >& log.$0.\$$
echo \$$
EOF
    ) > run.sh 
chmod +x run.sh
}

#
# Main
#
# ??????????????????????????????????????????decomposeParDict.sh???????????????????????????????????????????????????
source ../decomposeParDict.sh.param
# ????????????????????????????????????????????????????????????????????????????????????
source $0.param
# ppn(process per node)????????????????????????????????????????????????
numberOfSubdomains=`expr $decomposeParDict_ppn \* $decomposeParDict_node`
# ??????????????????????????????????????????????????????????????????????????????
if [ ! -d include ]
then
    mkdir include
    (cd include
	ln -s  ../../include/* ./
    )
fi
for file in 0 constant system
do
    [ -L $file ] || ln -s ../$file .
done
# ????????????????????????????????????????????????????????????????????????????????????????????????
i=0
while [ $i -lt $numberOfSubdomains ] 
do
    file=processor$i
    [ -L $file ] || ln -s ../$file .
    i=`expr $i + 1` 
done
# Generate fvSolution
generate_fvSolution
# Generage batch and include files
generate_batch_and_include_files
# Submit job
JOBID=$(./run.sh)
echo $JOBID
exit 0
