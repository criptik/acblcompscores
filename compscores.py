import argparse
import re
import sys
import collections
import json

def recursively_default_dict():
    return collections.defaultdict(recursively_default_dict)

#globals
isMitchell= False
args = None
highestBoard = None

PairData = {}
maxResultsPerBoard = 0
numResultsBoard = {}

class ResultObj(object):
    def __init__(self, isNS, score, oppPair):
        self.isNS = isNS
        self.score = score
        self.opp = oppPair
        
class PairObj(object):
    def __init__(self, pairnum):
        self.results = {}
        self.name = None
        self.pairnum = pairnum
        self.vsDup = {}
        
        
def MP(diff):
    if diff > 0:
        return 1
    elif diff == 0:
        return 0.5
    else:
        return 0

    
def handleScoreLine(bd, m):
    global isMitchell
    # print('<%s> <%s> %s %s %s %s' % (m[1], m[2], m[3], m[4], m[5], m[6]))
    scoreText = m[1]
    if 'PASS' in scoreText:
        ewscore = 0
        nwscore = 0
    else:
        # separate m[1] into ns and ew scores
        nstext = scoreText[0:4]
        ewtext = scoreText[6:10]
        # print('nstext=<%s>, ewtext=<%s>' % (nstext,ewtext))
        if nstext == '    ':
            ewscore = int(ewtext)
            nsscore = -1 * ewscore
        else:
            nsscore = int(nstext)
            ewscore = -1 * nsscore
    # print('ns=', nsscore, ', ew=', ewscore)
    NSPair = int(m[2])
    NSName = m[3]
    EWPair = int(m[4])
    EWName = m[5]
    print('handle score line for bd %d, ns %d, ew %d' % (bd, NSPair, EWPair))
    
    # if first round shows that NSPair is playing same number EWPair, then it must be a mitchell movement
    if NSPair == EWPair:
        isMitchell = True
    
    # for mitchell artificially bump the EW Pairs by 1/2 totalPairs
    if isMitchell:
        EWPair += int((args.numPairs + 1) / 2)

    if PairData.get(NSPair) == None:
        PairData[NSPair] = PairObj(NSPair)
    if PairData.get(EWPair) == None:
        PairData[EWPair] = PairObj(EWPair)
    
    PairData[NSPair].results[bd] = ResultObj(True, nsscore, EWPair)
    PairData[EWPair].results[bd] = ResultObj(False, ewscore, NSPair)
    PairData[NSPair].name = NSName
    PairData[EWPair].name = EWName


def dumpPairData():
    print(json.dumps(PairData, indent=1, default=lambda x: x.__dict__))

#=========================================    
# main program
# argument stuff
parser = argparse.ArgumentParser()
parser.add_argument('-f', '--file', required=True, help='input file')
parser.add_argument('-n', '--numPairs', required=True, type=int, help='number of Pairs')
parser.add_argument('-k', '--scoreKind', default='MP', help='scoring Kind (MP, IMP, TP)')
parser.add_argument('-v', '--verbose', action='store_true', help='increase output verbosity')
args = parser.parse_args()


print('input file is', args.file)
resultsPerBoard = 0
with open(args.file) as fp:
    currBoard = 0
    for line in fp:
        m = re.match('^ *RESULTS OF BOARD (\d+)', line)
        if m:
            currBoard = int(m[1])
            highestBoard = currBoard
            resultsPerBoard = 0
            print('currBoard =', currBoard)
            continue
        # line which matches traveler entry
        # the first section (with scores or PASS)will be parsed in handleScoreLine
        # if plus for N/S, then m[1] will be non-blank.
        # if plus for E/W, then m[2] will be non-blank.
        m = re.match('^ (.{10}).*(\d+)-(\w+-\w+) vs (\d+)-(\w+-\w+)', line)
        if m:
            handleScoreLine(currBoard, m)
            resultsPerBoard += 1
            numResultsBoard[currBoard] = resultsPerBoard
            maxResultsPerBoard = max(maxResultsPerBoard, resultsPerBoard)
            # print(line.rstrip())
            continue
        # print(line.rstrip())
maxResultsPerBoard = max(maxResultsPerBoard, resultsPerBoard)
print('maxPerBoard = %d' % (maxResultsPerBoard))
if False:
    dumpPairData()

# for each of pair on each board compute a "duplicate" score
for bd in range(1, highestBoard+1):
    for pra in sorted(PairData.keys()):
        aresult = PairData[pra].results.get(bd)
        if aresult == None:
            continue
        # now go thru other pairs and compute duplicate score vs. ones sitting same direction
        dupBoard = 0
        for prb in sorted(PairData.keys()):
            # print(bd, pra, prb)
            bresult = PairData[prb].results.get(bd)
            if  bresult == None or pra == prb or aresult.isNS != bresult.isNS:
                 continue
            
            ascore = aresult.score
            bscore = bresult.score
            diff = ascore - bscore
            # print ('%d : %d,%d  --> %d' % (bd, pra, prb, diff))
            if args.scoreKind == 'MP':
                dup = MP(diff)
            else:
                # todo: handle other scoring types like TP or IMP
                print('%s scoring not supported yet' % (args.scoreKind))
            # $dup = $diff if ($ScoreType eq 'TP');
            dupBoard += dup
        # print('total dup for %d on bd %d is %f' % (pra, bd, dupBoard))
        # MP only, adjust duplicates for boards which have fewer plays
        if args.scoreKind == 'MP':
            numResults = numResultsBoard[bd]
            if numResults != maxResultsPerBoard:
                oldDup = dupBoard
                dupBoard = ((oldDup + 0.5) * (maxResultsPerBoard/numResults) - 0.5)
                print('on bd %d, changed dup score for pair %d from %f to %f' % (bd, pra, oldDup, dupBoard))
        # store in result object
        aresult.dup = dupBoard

# compute total duplicate for each pair, adjusting for noplays
dupTotals = {}
for pnum in sorted(PairData.keys()):
    dupTotal = 0
    numBoards = 0
    for bd in range(1, highestBoard+1):
        # get dup for that board if it exists, else 0
        result = PairData[pnum].results.get(bd)
        if result == None:
            dup = 0
        else:
            dup = result.dup
            numBoards += 1
        dupTotal += dup
    if args.scoreKind == 'MP' and numBoards != highestBoard:
        dupTotal = dupTotal * (highestBoard/numBoards)
    dupTotals[pnum] = dupTotal
    print('dupTotal for pair %d is %.2f' % (pnum, dupTotal), end='')
    if args.scoreKind == 'MP':
        maxPossible = highestBoard * (maxResultsPerBoard - 1)
        pct = 100 * dupTotal / maxPossible
        print(' or %.2f%%' % (pct))
    else:
        print()
