#!/usr/bin/env python
# -*- coding: utf-8 -*-

import matplotlib as mpl
import numpy as np
import pylab
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import argparse
import math

HUGE=1e+30

markers = [
    'o',
    's',
    '+',
    'x',
    'v',
    '^',
    '<',
    '>',
    '1',
    'p',
    'D',
    'h',
    'H',
    'd',
    '|',
    '_',
    '*',
    '2',
    '3',
    '4'
]

colors = [
    'k',
    'r',
    'b',
    'lightblue',
    'g',
    'y',
    'c',
    'm',
    'brown',
    'pink',
    'violet',
    'orange',
    'aqua',
]

def parser():
    p = argparse.ArgumentParser()
    p.add_argument('-a','--all', help='plot all data', action='store_true')
    p.add_argument('-m','--maxNumberOfSampling', help='Max number of sampling', type=int, default=1)
    p.add_argument('-L','--lineWidth', help='Line width', type=int, default=1.5)
    p.add_argument('--lineWidthLinear', help='Line width of linear', type=int, default=2)
    p.add_argument('-x','--xscaleLinear'
                   , help='x scale Linear', action='store_true')
    p.add_argument('-y','--yscaleLinear'
                   , help='y scale Linear', action='store_true')
    p.add_argument('-o','--offset'
                   , help='offset ratio of x range', type=float, default=0.03)
    p.add_argument('-r','--rotation'
                   , help='rotation degree of xticks', type=float, default=0)
    p.add_argument('--titleFontSize', help='Title font size', type=int, default=13)
    p.add_argument('--legendFontSize', help='Legend font size', type=int, default=10)
    p.add_argument('--xlabelFontSize', help='X label fontsize', type=int, default=13)
    p.add_argument('--ylabelFontSize', help='Y label fontsize', type=int, default=13)
    p.add_argument('--tickFontSize', help='Tick font size', type=int, default=13)
    p.add_argument('--topFraction'
                   , help='Top faction', type=float, default=0.97)
    p.add_argument('--bottomFraction'
                   , help='Bottom faction', type=float, default=0.12)
    p.add_argument('--leftFraction'
                   , help='Left faction', type=float, default=0.12)
    p.add_argument('--rightFraction'
                   , help='Right faction', type=float, default=0.97)
    p.add_argument('--linearY', help='Speed of linear line', type=float, default=1e4)
    p.add_argument('--xticks', help='x ticks list', type=int, nargs='+', required=False)
    p.add_argument('--ncolLegend', help='Number of column in legend', type=int, default=2)
    p.add_argument('--padInches', help='Pad inchess', type=float, default=0.03)
    p.add_argument('--markerSize', help='markersize', type=float, default=8)
    p.add_argument('--markerEdgeWidth', help='marker edge width', type=float, default=1.5)
    p.add_argument('--markerFaceColor', help='marker face color', type=str, default='none')
    p.add_argument('--lineStyle', help='line style', type=str, default='-')        
    return p.parse_args()


def result(filename,fvSolution,solveBatch):
    data=np.genfromtxt(filename, names=True, delimiter=',', dtype=None, encoding='utf-8')
    
    idx=np.where(
        (data['fvSolution']==fvSolution)
        & (data['solveBatch']==solveBatch)
        )

    x=data['nNodes'][idx]
    if data['Steps'][idx][0]==9:
        y=data['ExecutionTimePerStep'][idx]
    elif data['Steps'][idx][0]==10:
        y=data['ExecutionTimePerStepWOLastStep'][idx]
    elif data['Steps'][idx][0]==51:
        y=data['ExecutionTimePerStep'][idx]
    elif data['Steps'][idx][0]==52:
        y=data['ExecutionTimePerStepWOLastStep'][idx]
    else:
        print("Illegal Steps: "+str(data['Steps'][idx][0]))
        exit(0)
        
    t=data['ExecutionTimeFirstStep'][idx]

    node,index0 = np.unique(x, return_index=True)
    index1=index0[1:]
    index1=np.append(index1,len(y))
    clockTimeAve=np.zeros(len(node))
    clockTimeFSAve=np.zeros(len(node))

    for i in range(len(node)):
        clockTime=y[index0[i]:index1[i]]
        clockTime=np.sort(clockTime)[0:min(len(clockTime),args.maxNumberOfSampling)]
        clockTimeAve[i]=np.average(clockTime)
        sr=clockTimeAve[0]/clockTime
        pe=sr/(node[i]/node[0])*100.0
        clockTimeFS=t[index0[i]:index1[i]]
        clockTimeFS=np.sort(clockTimeFS)[0:min(len(clockTimeFS),args.maxNumberOfSampling)]
        clockTimeFSAve[i]=np.average(clockTimeFS)
    
    nTimeStepPerHourAve=3600.0/clockTimeAve
    srAve=clockTimeAve[0]/clockTimeAve
    peAve=srAve/(node/node[0])*100
    
    return node,clockTimeAve,nTimeStepPerHourAve,srAve,peAve,clockTimeFSAve

def plotInit(subfilename):
    plotfile=subfilename
    if args.xscaleLinear:
        plotfile=plotfile+'-xscalelinear'
    else:
        plotfile=plotfile+'-xscaleLog'
    if args.yscaleLinear:
        plotfile=plotfile+'-yscaleLinear'
    else:
        plotfile=plotfile+'-yscaleLog'
    plotfile=plotfile+'-maxNumberOfSampling_'+str(args.maxNumberOfSampling)
    if args.all==True:
        plotfile+="-all"
    plotfile=plotfile+'.pdf'
    print(plotfile)
    pp=PdfPages(plotfile)
    return pp
    
def plotNode(args,pp,ylabel,yMin,yMax):
    plt.subplots_adjust(
        top=args.topFraction
        ,bottom=args.bottomFraction
        ,left=args.leftFraction
        ,right=args.rightFraction
        )
    plt.grid(which='major',axis='x')
    plt.grid(which='major',axis='y',linestyle='-')
    plt.grid(which='minor',axis='y',linestyle=':')
    plt.tick_params(labelsize=args.tickFontSize)

    plt.xlabel('Number of nodes', fontsize=args.xlabelFontSize)
    if args.xticks==None:
        xmin, xmax = plt.xlim()
        xticks=[1]
        for i in range(math.ceil(math.log2(xmax))-1):
            xticks.append(xticks[-1]*2)
    else:
        xticks=args.xticks
        
    if args.xscaleLinear:
        offset=(xticks[-1]-xticks[0])*args.offset
        xmin=xticks[0]-offset
        xmax=xticks[-1]+offset
    else:
        offset=(math.log10(xticks[-1])-math.log10(xticks[0]))*args.offset
        xmin=math.pow(10,math.log10(xticks[0])-offset)
        xmax=math.pow(10,math.log10(xticks[-1])+offset)
        plt.xlim(xmin, xmax)
        plt.xscale('log', basex=2)
    plt.xticks(xticks,xticks,rotation=args.rotation)

    plt.ylabel(ylabel, fontsize=args.ylabelFontSize)
    ymin, ymax = plt.ylim()
    if args.yscaleLinear:
        ymin=0
        ymax=math.ceil(ymax/50)*50
        plt.grid(which='minor',axis='y',linestyle=':')
    else:
        offset=(math.log10(yMax)-math.log10(yMin))*args.offset
        ymin=math.pow(10,math.floor(math.log10(yMin)))
        ymax=math.pow(10,math.ceil(math.log10(yMax)))
        plt.yscale('log')
    plt.ylim(ymin, ymax)

    return xmin,xmax,ymin,ymax

def plotEnd(pp):
    plt.legend(loc='best', prop={'size':args.legendFontSize},ncol=args.ncolLegend)
    pp.savefig(bbox_inches="tight", pad_inches=args.padInches)
    plt.clf()
    pp.close()

def plotNumberOfTimeStepPerHour(args,config):
    subfilename="node-NumberOfTimeStepPerHour"
    pp=plotInit(subfilename)

    nTimeStepPerHourAveMin=HUGE
    nTimeStepPerHourAveMax=-HUGE
    i=0
    for i in range(len(config)):
        (node,clockTimeAve,nTimeStepPerHourAve,srAve,peAve,clockTimeFSAve)=result(
            config['filename'][i],config['fvSolution'][i],config['solveBatch'][i])
        nTimeStepPerHourAveMin=min(min(nTimeStepPerHourAve),nTimeStepPerHourAveMin)
        nTimeStepPerHourAveMax=max(max(nTimeStepPerHourAve),nTimeStepPerHourAveMax)
        plt.plot(
            node
            ,nTimeStepPerHourAve
            ,label=config['label'][i]
            ,linestyle=args.lineStyle
            ,linewidth=args.lineWidth
            ,marker=markers[i]
            ,markeredgewidth=args.markerEdgeWidth
            ,markersize=args.markerSize
            , markerfacecolor=args.markerFaceColor
            , color=colors[i]
            , markeredgecolor=colors[i]
        )    
        i=i+1
            
    ylabel='Speed [Steps/h] (> Higher is better)'
    xmin,xmax,ymin,ymax=plotNode(args,pp,ylabel,nTimeStepPerHourAveMin,nTimeStepPerHourAveMax)
    plt.plot([xmin, xmax], [args.linearY*xmin, args.linearY*xmax/xmin], 'k-', label="Linear", linewidth=args.lineWidthLinear)
    plotEnd(pp)    

def plotParallelEfficiency(args,config):
    subfilename="node-pe"
    pp=plotInit(subfilename)

    peMin=HUGE
    peMax=-HUGE
    i=0
    for i in range(len(config)):
        (node,clockTimeAve,nTimeStepPerHourAve,srAve,peAve,clockTimeFSAve)=result(
            config['filename'][i],config['fvSolution'][i],config['solveBatch'][i])
        peMin=min(min(peAve),peMin)
        peMax=max(max(peAve),peMax)
        plt.plot(
            node
            ,peAve
            ,label=config['label'][i]
            ,linestyle=args.lineStyle
            ,linewidth=args.lineWidth
            ,marker=markers[i]
            ,markeredgewidth=args.markerEdgeWidth
            ,markersize=args.markerSize
            ,markerfacecolor=args.markerFaceColor
            ,color=colors[i]
            ,markeredgecolor=colors[i]
        )
        i=i+1
        
    ylabel='Parallel efficiency (Strong scaling) [%]'
    xmin,xmax,ymin,ymax=plotNode(args,pp,ylabel,peMin,peMax)
    plt.plot([xmin, xmax], [100, 100], 'k-', label="Linear", linewidth=args.lineWidthLinear)
    plotEnd(pp)    


def saveAverageValue(config):
    f = open('comparison.csv', 'w')
    f.write('#filename,fvSolution,solveBatch,label')
    f.write(',node,executionTime,nTimeStepPerHour,speedup,parallelEfficiency,executionTimeFirstStep\n')
    for i in range(len(config)):
        (node,clockTimeAve,nTimeStepPerHourAve,srAve,peAve,clockTimeFSAve)=result(
            config['filename'][i],config['fvSolution'][i],config['solveBatch'][i])
        for j, nodej in enumerate(node):
            f.write(
                '{:s},{:s},{:s},{:s},{:d},{:.6g},{:.6g},{:.6g},{:.6g},{:.6g}\n'
                .format(
                    config['filename'][i],config['fvSolution'][i],config['solveBatch'][i],config['label'][i]
                    ,nodej,clockTimeAve[j],nTimeStepPerHourAve[j],srAve[j],peAve[j],clockTimeFSAve[j])
                    )

#
# main
#
if __name__ == '__main__':
    args=parser()
    config=np.genfromtxt('config.csv', names=True, delimiter=',', dtype=None, encoding='utf-8')
    saveAverageValue(config)
    args.xscaleLinear=False
    args.yscaleLinear=True
    plotParallelEfficiency(args,config)
    args.yscaleLinear=False
    plotNumberOfTimeStepPerHour(args,config)
