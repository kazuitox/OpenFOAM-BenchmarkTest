#!/usr/bin/env python
# -*- coding: utf-8 -*-

import numpy as np
import sys
from distutils.version import LooseVersion, StrictVersion

if StrictVersion(np.__version__) < StrictVersion('1.14.0'):
    print('Error: numpy version is older than 1.14.0. Please use newer version.')
    exit(0)

argvs=sys.argv
argc=len(argvs)

if argc<2 or argc>3:
    print('Usage: python %s filename [maxNodes]' % argvs[0])
    exit(0)

filename=argvs[1]
maxNodes=1e+30
if argc==3:
    maxNodes=int(argvs[2])

data=np.genfromtxt(filename, names=True, delimiter=',', dtype=None, encoding='utf-8')

solveBatchList=np.unique(data['solveBatch'])
fvSolutionList=np.unique(data['fvSolution'])
nfvSolutionList=len(fvSolutionList)
idx=np.where(data['nNodes']<=maxNodes)
nNodesList=np.unique(data['nNodes'][idx])

print("#solveBatch,fvSolution,nCases,aveNodeTime,aveNodeTime/aveNodeTimeMin")

NodeTimeList=[]
nCasesList=[]
for solveBatch in solveBatchList:
    for fvSolution in fvSolutionList:
        idx=np.where(
            (data['solveBatch']==solveBatch) &
            (data['fvSolution']==fvSolution) &
            (data['nNodes']<=maxNodes)
        )
        nCases=len(idx[0])
        nCasesList.append(nCases)
        NodeTimePerNode=[]
        for nNodes in nNodesList:
            idx=np.where(
                (data['solveBatch']==solveBatch) &
                (data['fvSolution']==fvSolution) &
                (data['nNodes']==nNodes)
                )
            ExecutionTime=data['ExecutionTimePerStep'][idx]
            NodeTime=ExecutionTime*nNodes
            if len(NodeTime)==0:
                print("Warning: Number of trials is zero. nNodes:%d fvSolution:%s solveBatch:%s" \
                % (nNodes,fvSolution,solveBatch), file=sys.stderr)
            else:
                NodeTimePerNode.append(np.average(NodeTime))
        NodeTimeList.append(np.average(NodeTimePerNode))

sortIdx=np.argsort(NodeTimeList)
min=NodeTimeList[sortIdx[0]]
for i in sortIdx:
    solveBatchI=int(i/nfvSolutionList)
    fvSolutionI=i % nfvSolutionList
    print("%s,%s,%d,%g,%g" % \
        (solveBatchList[solveBatchI],
         fvSolutionList[fvSolutionI],
         nCasesList[i],
         NodeTimeList[i],
         NodeTimeList[i]/min))
