#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import optuna
import sys
import socket
import argparse
import numpy
import shutil
import subprocess
import pathlib
import time
import json
import hashlib
from collections import OrderedDict
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
import itertools
import psutil

def parseOptions():
    """
    Parse options
    """
    p = argparse.ArgumentParser()

    p.add_argument('--debug', action='store_true')
    p.add_argument('--fileCheckSleepSecond', type=int, default=3)
    p.add_argument('--nJobs', type=int, default=1)
    p.add_argument('--nTrials', type=int, default=1)
    p.add_argument('--nJobTrials', type=int, default=1)
    p.add_argument('--studyName', type=str, default='tuneOpenFOAM')
    p.add_argument('--storage', type=str, default='sqlite:///tuneOpenFOAM.db')
    p.add_argument('--seed',type=int, default=10)
    p.add_argument('--initialStep',type=str, default="")
    p.add_argument('--numberSteps',type=int, default=0)
    p.add_argument('--outputTime', action='store_true')
    p.add_argument('--jsonFilename', type=str, default='tuneOpenFOAM.json')
    p.add_argument('--caseDir', type=str, default='cases')
    p.add_argument('--useDefaultFirst', action='store_true')
    p.add_argument('--bestLinkName', type=str, default='best')
    p.add_argument('--gridSearch', action='store_true')
    p.add_argument('--nice', action='store_true')
    p.add_argument('--useMinimumExecutionTime', action='store_true')

    p.add_argument('--plot', action='store_true')
    p.add_argument('--xSize', type=float, default=8)
    p.add_argument('--ySize', type=float, default=3)
    p.add_argument('--xlimMin', type=float, nargs='+', default=[0])
    p.add_argument('--xlimMax', type=float, nargs='+', default=[1])
    p.add_argument('--ylimMin', type=float, nargs='+', default=[0])
    p.add_argument('--ylimMax', type=float, nargs='+',  default=[100])
    p.add_argument('--legendFontSize', type=int, default=16)
    p.add_argument('--xlabelFontSize', type=int, default=16)
    p.add_argument('--ylabelFontSize', type=int, default=16)
    p.add_argument('--xtickFontSize', type=int, default=16)
    p.add_argument('--ytickFontSize', type=int, default=16)
    p.add_argument('--lineWidth', type=float, default=1.5)
    p.add_argument('--topFraction' , type=float, default=0.95)
    p.add_argument('--bottomFraction', type=float, default=0.2)
    p.add_argument('--rightFraction', type=float, default=0.95)
    p.add_argument('--leftFraction', type=float, default=0.1)

    p.add_argument('-v', '--visualization_parameters', type=str, nargs='+', default=None)
    p.add_argument('-c', '--plot_contour', action='store_true')
    p.add_argument('-o', '--plot_optimization_history', action='store_true')
    p.add_argument('-p', '--plot_parallel_coordinate', action='store_true')
    p.add_argument('-s', '--plot_slice', action='store_true')

    return p.parse_args()


def readConfig():
    """
    Read JSON format configuration file
    """
    with open(args.jsonFilename) as f:
        df = json.load(f, object_pairs_hook=OrderedDict)

    return(df)


def doneJobs(dirPath, batchName):
    """
    Number of done jobs
    """
    doneJobsList = []
    logPathList = list(dirPath.glob("log."+batchName + ".[0-9]*"))
    for logPath in logPathList:
        with open(logPath) as f:
            lines = f.readlines()
        if 'End\n' in lines:
            doneJobsList.append(logPath)
        if 'End.\n' in lines:
            doneJobsList.append(logPath)
        if 'Killed\n' in lines:
            doneJobsList.append(logPath)
        if 'Exit\n' in lines:
            doneJobsList.append(logPath)

    return(doneJobsList)


def waitJob(batchDirPath, batchName, jobid):
    """
    Wait for finishing the job
    """
    logFile = "log.{}.{}".format(batchName, jobid)
    logFilePath = batchDirPath / logFile
    init = True
    while not logFilePath.exists():
        if init:
            print("Waiting for creating", logFilePath, file=sys.stderr)
            init = False
        time.sleep(args.fileCheckSleepSecond)

    init = True
    while True:
        with open(logFilePath) as f:
            lines = f.readlines()
        if 'End\n' in lines:
            return 0
        if 'End.\n' in lines:
            return 0
        if 'Killed\n' in lines:
            return 1
        if 'Exit\n' in lines:
            return 1
        if init:
            print("Waiting for finishing", logFilePath, file=sys.stderr)
            init = False
        time.sleep(args.fileCheckSleepSecond)


def executionTimePerStep(doneJobsPath):
    """
    Get execution time
    """
    with open(doneJobsPath) as f:
        lines = f.readlines()

    if 'Killed\n' in lines:
        print("Warning: Killed. Ignore {}.".format(doneJobsPath), file=sys.stderr)
        return -3

    if 'Exit\n' in lines:
        print("Warning: Exit. Ignore {}.".format(doneJobsPath), file=sys.stderr)
        return -4

    timeStepLines = [line for line in lines if line.startswith('Time = ')]
    timeLines = [line for line in lines if line.startswith('ExecutionTime ')]
    n=len(timeLines)

    # Calculate execution time per time step
    if n == 0:
        print("Warning: Number of steps is zero. Ignore {}.".format(doneJobsPath), file=sys.stderr)
        tave= 0
    elif n < args.numberSteps:
        print("Warning: Number of steps {} is too small. Ignore {}.".format(n, doneJobsPath), file=sys.stderr)
        tave = -1
    else:
        timeStep0=timeStepLines[0].split(' ')[2].strip()
        if args.initialStep != "" and timeStep0 != args.initialStep:
            print("Warning: Illegal initial time step {}. Ignore {}.".format(timeStep0, doneJobsPath), file=sys.stderr)
            tave = -2
        else:
            t0 = float(timeLines[0].split(' ')[2])
            if args.numberSteps>0:
                n=args.numberSteps-1
                t1 = float(timeLines[args.numberSteps-1].split(' ')[2])
            else:
                n=len(timeLines)-1
                t1 = float(timeLines[-1].split(' ')[2])
            lap = t1-t0
            tave = lap/float(n)

    # Print time
    print("log={} n={} t0={:g} t1={:g} tave={:g}".format(
            doneJobsPath, args.numberSteps, t0, t1, tave
            ), file=sys.stderr)

    return tave


def executionTimePerStepStat(doneJobsList):
    """
    Get average of execution time per time step
    """
    ExecutionTimePerStepList = []
    for doneJobsPath in doneJobsList:
        t = executionTimePerStep(doneJobsPath)
        if t > 0:
            ExecutionTimePerStepList.append(t)
            if len(ExecutionTimePerStepList)==args.nJobTrials:
                break

    if len(ExecutionTimePerStepList) > 0:
        if args.useMinimumExecutionTime:
            return numpy.min(ExecutionTimePerStepList)
        else:
            return numpy.mean(ExecutionTimePerStepList)
    else:
        return numpy.nan


def submitJob(printOnly = False, symlink = False):
    """
    Submit job
    """
    batchCaseDir = args.caseDir
    batchCasePath = pathlib.Path(batchCaseDir)
    batchCasePath.mkdir(exist_ok = True)
    for index, batchName in enumerate(config):
        # Directory name is SHA1 digest of batch shell script
        paramFile='\n'.join(parameters[batchName])+'\n'
        batchCaseDirSub = "_"+hashlib.sha1(paramFile.encode('utf-8')).hexdigest()
        print('Directory: {}'.format(batchCaseDir), file=sys.stderr)
        print('Parameters:\n---\n{}---'.format(paramFile), file=sys.stderr)

        bestSymlinkDir = batchCaseDir + "/" + args.bestLinkName
        bestSymlinkPath = pathlib.Path(bestSymlinkDir)
        batchCaseDir += "/" + batchCaseDirSub
        batchDirPath = pathlib.Path(batchCaseDir)

        if symlink:
            if bestSymlinkPath.exists() and bestSymlinkPath.is_symlink():
                os.remove(bestSymlinkPath)
            if not bestSymlinkPath.exists():
                print('Generate symblic link {} -> {}.'.format(batchDirPath,args.bestLinkName), file=sys.stderr)
                os.symlink(batchCaseDirSub, bestSymlinkPath)
            else:
                print('Warning: Unable to generate symblic link {}.'.format(bestSymlinkPath), file=sys.stderr)

        if printOnly:
            continue;

        batchDirPath.mkdir(exist_ok = True)

        # Copy batch job file
        shutil.copy(batchName, batchDirPath)

        # Write paramer file
        batchNameParam = batchName+".param"
        batchDestPath = batchDirPath / batchNameParam
        with batchDestPath.open(mode = 'w') as f:
            f.write(paramFile)

        if index == len(config)-1:
            nJobTrialsTmp=args.nJobTrials
            createLockFile=False
        else:
            nJobTrialsTmp=1
            createLockFile=True
            lockFileName=batchName+".lock"
            lockFilePath = batchDirPath / lockFileName

        while True:
            doneJobsList = doneJobs(batchDirPath, batchName)
            nDoneJobs = len(doneJobsList)
            print('Number of done jobs of {}/{} is {}'.format(batchDirPath, batchName, nDoneJobs), file=sys.stderr)
            if nDoneJobs>=nJobTrialsTmp:
                break

            if createLockFile:
                while lockFilePath.exists():
                    print("Waiting for finishing other job in {}".format(batchDirPath), file=sys.stderr)
                    time.sleep(args.fileCheckSleepSecond)

            # Submit jobs
            command = [ "bash",  batchName ]
            print('Execute job {} at {}'.format(' '.join(command),batchDestPath), file=sys.stderr)
            jobid=0
            try:
                if args.nice:
                    proc.nice(0)
                submit_output = subprocess.check_output(
                    command,
                    cwd=batchDirPath,
                    universal_newlines=True
                )
                if args.nice:
                    proc.nice(19)
                jobid=submit_output.strip()
                try:
                    jobid=int(jobid)
                except ValueError:
                    print("Error in submit job {}. {}".format(batchDirPath,jobid), file=sys.stderr)
                    return numpy.nan
                if createLockFile:
                    lockFilePath.touch()
            except subprocess.CalledProcessError as e:
                print('Error in submit job {}. Retry.'.format(batchDirPath), file=sys.stderr)

            if jobid>0:
                status = waitJob(batchDirPath, batchName, jobid)
                if createLockFile:
                    if lockFilePath.exists():
                        print("Remove lock file.", lockFilePath, file=sys.stderr)
                        try:
                            lockFilePath.unlink()
                        except subprocess.CalledProcessError as e:
                            print('Warning. Fail to remove lock file {}.'.format(lockFilePath), file=sys.stderr)

                if status == 0:
                    print("Finish job of {}/{}.".format(batchDirPath, batchName), file=sys.stderr)
                else:
                    print("Kill job of {}/{}.".format(batchDirPath, batchName), file=sys.stderr)
                    return numpy.nan
            elif jobid==0:
                if createLockFile:
                    if lockFilePath.exists():
                        print("Remove lock file.", lockFilePath, file=sys.stderr)
                        try:
                            lockFilePath.unlink()
                        except subprocess.CalledProcessError as e:
                            print('Warning. Fail to remove lock file {}.'.format(lockFilePath), file=sys.stderr)

    if printOnly:
        return 0
    else:
        return executionTimePerStepStat(doneJobsList)


def suggest(configBatch, trial, parametersBatch, noSuggest=False):
    for key in configBatch:
        if not noSuggest:
            param[key] = trial.suggest_int(key, 0, len(configBatch[key])-1)
        val=configBatch[key][param[key]]
        if isinstance(val, dict):
            value=list(val.keys())[0]
        else:
            value=val

        if args.debug:
            print("key:{} value={}".format(key,value))

        parametersBatch.append("{}={}".format(key,value))

        if isinstance(val, dict):
            subConfigBatch=list(val.values())[0]
            suggest(subConfigBatch, trial, parametersBatch, noSuggest)

    return


def objective(trial):
    """
    Generate objective function
    """
    if hasattr(trial, 'number'):
        print("\ntrial.number={}".format(trial.number), file=sys.stderr)

    # Generate trial object
    for batchName in config:
        parameters[batchName]=[]
        suggest(config[batchName],trial,parameters[batchName])
        parameters[batchName].sort()

    f = submitJob()

    return f


def plot(study):
    """
    Plot CPU time of trials
    """

    plt.plot(pd.DataFrame([t.value for t in study.trials])
             , linewidth=args.lineWidth, label="Trial")
    plt.plot(pd.DataFrame([t.value for t in study.trials]).cummin()
             , linewidth=args.lineWidth, label="Best")

    plt.subplots_adjust(
        top=args.topFraction
        ,bottom=args.bottomFraction
        ,right=args.rightFraction
        ,left=args.leftFraction
        )
    plt.legend(fontsize=args.legendFontSize, loc='best')
    plt.grid()
    plt.xlabel("Trial No.", fontsize=args.xlabelFontSize)
    plt.tick_params(axis='x',labelsize=args.xtickFontSize)
    plt.tick_params(axis='y',labelsize=args.ytickFontSize)

    for i in range(len(args.xlimMin)):
        plt.xlim(args.xlimMin[i],args.xlimMax[i])
        plt.ylim(args.ylimMin[i],args.ylimMax[i])
        plotfile="{}-{:g}-{:g}-{:g}-{:g}".format(
            args.studyName,
            args.xlimMin[i],
            args.xlimMax[i],
            args.ylimMin[i],
            args.ylimMax[i])
        plotfile=plotfile.replace(".","_")+".pdf"
        plt.savefig(plotfile)

    
def gridSearch(objective):
    paramGrid={}
    paramGrid2={}
    lines="#Value"
    for batchName in config:
        for key1 in config[batchName]:
            paramGrid[key1]=range(len(config[batchName][key1]))
            paramGrid2[key1]=config[batchName][key1]
            lines+=",{}".format(key1)
    lines+="\n"

    for paramList in itertools.product(*paramGrid.values()):
        linesParam=""
        for paramKeyI, paramKey in enumerate(paramGrid.keys()):
            i = paramList[paramKeyI]
            param[paramKey] = i
            linesParam+=",{}".format(paramGrid2[paramKey][i])
        f = objective(optuna.trial.FixedTrial(param))
        lines+="{:g}".format(f)+linesParam+"\n"

    outputPath=pathlib.Path(args.jsonFilename+".csv")
    with outputPath.open(mode = 'w') as f:
        f.write(lines)


def main():
    """
    Main
    """
    hostname=socket.gethostname()
    print(f"Hostname: {hostname}", file=sys.stderr)
    pid=os.getpid()
    print(f"PID: {pid}".format(), file=sys.stderr)

    global args
    args = parseOptions()

    global config
    config = readConfig()

    global proc
    if args.nice:
        proc = psutil.Process(pid)
        proc.nice(19)

    study = optuna.create_study(
        study_name = args.studyName,
        storage = args.storage,
        sampler = optuna.samplers.TPESampler(seed=args.seed),
        load_if_exists = True
        )

    global param
    param = {}
    global parameters
    parameters = {}

    if args.plot_optimization_history:
        # visualize optimization_history
        optuna.visualization.plot_optimization_history(study)
    elif args.plot_contour:
        # Plot the parameter relationship as contour plot in a study.
        optuna.visualization.plot_contour(study, params=args.visualization_parameters)
    elif args.plot_parallel_coordinate:
        # Plot the high-dimentional parameter relationships in a study.
        optuna.visualization.plot_parallel_coordinate(study, params=args.visualization_parameters)
    elif args.plot_slice:
        # Plot the parameter relationship as slice plot in a study.
        optuna.visualization.plot_slice(study, params=args.visualization_parameters)
    elif args.plot:
        # plot optimization_history
        plot(study)
    elif args.gridSearch:
        gridSearch(objective)
    else:
        study.optimize(objective, n_trials = args.nTrials, n_jobs = args.nJobs)

        pruned_trials = [t for t in study.trials if t.state == optuna.trial.TrialState.PRUNED]
        timeout_trials = [t for t in study.trials if t.state == optuna.trial.TrialState.FAIL]
        complete_trials = [t for t in study.trials if t.state == optuna.trial.TrialState.COMPLETE]

        print('\nStudy statistics: ', file=sys.stderr)
        print('  Number of finished trials: ', len(study.trials), file=sys.stderr)
        print('  Number of pruned trials: ', len(pruned_trials), file=sys.stderr)
        print('  Number of timeout trials: ', len(timeout_trials), file=sys.stderr)
        print('  Number of complete trials: ', len(complete_trials), file=sys.stderr)
        trial = study.best_trial
        print('Best trial value: {:g}'.format(trial.value), file=sys.stderr)
        param=trial.params 
        for batchName in config:
            parameters[batchName]=[]
            suggest(config[batchName],trial,parameters[batchName],noSuggest=True)
            parameters[batchName].sort()
        submitJob(printOnly=True, symlink=True)

if __name__ == '__main__':
    main()
