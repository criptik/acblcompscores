use strict;

my $CurrBoard = 0;
my $HighestBoard = 0;
my @Data;
my %NameData;
my %TotDup;
my %PairTot;
my $NS = 1;
my $EW = 2;
my %PNums;
my $BText;
my $totalPairs = 0;
my $isMitchell = 0;

my %ScoreName = (
    'TP'   => 'TOTALPOINTS',
    'IMPS' => '    IMPS   ',
    'MP'   => 'MATCHPOINTS',
    );

die "Usage: perl compscores.pl [MP|IMPS|TP] Travs.txt" if (@ARGV < 2); 
my $ScoreType = shift @ARGV;
#print "ScoreType = <$ScoreType>\n";
#exit(0);

while (<>) {
    # format is like 4.00   0.00 9-Giordano-Giordano vs 2-Anderson-Hochens
    if (m|^ *RESULTS OF BOARD (\d+)|) {
	$CurrBoard = $1;
	$HighestBoard = $1;
    }
    elsif (m|^      \s*(\d+) .* (\d+)-(\w+-\w+) vs (\d+)-(\w+-\w+)|) {
	# a minus score for NS, plus for EW
	my $ewscore = 1*"$1";
	my $nsscore = -1*$ewscore;
	SaveScoreData($CurrBoard, $2, $3, $nsscore, $4, $5, $ewscore);
    }
    elsif (m|^\s*(\d+) .* (\d+)-(\w+-\w+) vs (\d+)-(\w+-\w+)|) {
	# a plus score for NS, minus for EW
	my $nsscore = 1*"$1";
	my $ewscore = -1*$nsscore;
	SaveScoreData($CurrBoard, $2, $3, $nsscore, $4, $5, $ewscore);
    }
    elsif (m|^ \s*(PASS) .* (\d+)-(\w+-\w+) vs (\d+)-(\w+-\w+)|) {
	# Passed out, so a zero score for both NS and EW
	SaveScoreData($CurrBoard, $2, $3, 0, $4, $5, 0);
    }
    elsif ($CurrBoard == 0 && m|^\s*(\d+)\s*\d+\.\d+ \s* \d+\.\d+|) {
	$totalPairs++;
    } 

    else {
	if ($CurrBoard>0 && !m|N-S| && !m|SCORES| && !m|-----| && !m|^ $|) {
	    print STDERR "Unmatched line: $_";
	}
    }
}

# show scoredatas by boards read (for debugging)
for (my $bd=1; $bd <= $HighestBoard; $bd++) {
    my $count=0;
    my $str;
    foreach my $pra (sort {$a <=> $b} keys %{$Data[$bd]}) {
	$str .= "$pra,";
	$count++;
    }
    # print STDERR "$bd: $count $str\n";
}
# exit(1);

# now show what we got
for (my $bd=1; $bd <= $HighestBoard; $bd++) {
    #print "-------\nBoard $bd\n";
    #foreach my $pnum (sort {$a <=> $b} keys %{$Data[$bd]}) {
    #	print ("Score for $pnum = $Data[$bd]{$pnum}{SCORE}\n");
    #}
    # for each of NS and EW compute a totalpoints diff array
    foreach my $pra (sort {$a <=> $b} keys %{$Data[$bd]}) {
	foreach my $prb (sort {$a <=> $b} keys %{$Data[$bd]}) {
	    next if ($pra == $prb);
	    next if ($Data[$bd]{$pra}{DIR} ne  $Data[$bd]{$prb}{DIR});
	    my $ascore = $Data[$bd]{$pra}{SCORE};
	    my $bscore = $Data[$bd]{$prb}{SCORE};
	    my $diff = ($ascore - $bscore);
	    my $dup;
	    $dup = $diff if ($ScoreType eq 'TP');
	    $dup = MP($diff) if ($ScoreType eq 'MP');
	    $dup = IMPS($diff) if ($ScoreType eq 'IMPS');
	    # print ("Board $bd, $pra vs. $prb, dup=$dup\n");
	    $Data[$bd]{$pra}{DUPSCORE} += $dup;
	    $TotDup{$pra} += $dup;
	    $PairTot{$pra}{$Data[$bd]{$pra}{OPP}} += $dup;
	}
    }
}
print "----------\nTotals for All Boards\n";
PrintTotals(\%TotDup);
print "\n\n";
for (my $bd=1; $bd <= $HighestBoard; $bd++) {
    PrintOneBoard($bd);
}

# compute top on a board...
my $duptot = 0;
my $pairs = 0;
foreach my $pra (keys %{$Data[1]}) {
    $duptot += $Data[1]{$pra}{DUPSCORE};
    $pairs++;
}
my $boardTop = 2*$duptot / $pairs;

# compute number of boards per round
# try 1 vs. highest
my $bpr = 0;
for (my $bd=1; $bd <= $HighestBoard; $bd++) {
    $bpr++ if ($Data[$bd]{1}{OPP} == $pairs);
}
if ($bpr == 0) {
    for (my $bd=1; $bd <= $HighestBoard; $bd++) {
	$bpr++ if ($Data[$bd]{3}{OPP} == $pairs);
    }
}
print "boards per round = $bpr\n";

# print totals pairs vs pairs
print "\n\n";
foreach my $pra (sort {$a <=> $b} keys %PairTot) {
    print "Pair vs. Pair Totals for $pra-$NameData{$pra}: \n";
    foreach my $prb (reverse sort {$PairTot{$pra}{$a} <=> $PairTot{$pra}{$b}} keys %{$PairTot{$pra}}) {
	if ($ScoreType eq 'MP') {
	    my $total = $PairTot{$pra}{$prb};
	    printf ("%5.1f (%3d%%) %s\n", $total, 100.0*$total/($bpr * $boardTop), "$prb-$NameData{$prb}");
	}
	else {
	    printf ("%5d  %s\n", $PairTot{$pra}{$prb}, "$prb-$NameData{$prb}");
	}
    }
    print "\n";
}

# print distributions of scores
print "\n\nScore Distributions\n";
foreach my $pra (sort {$a <=> $b} keys %PairTot) {
    my %h;
    for (my $bd=1; $bd <= $HighestBoard; $bd++) {
	next if ($Data[$bd]{$pra}{OPP} == 0);
	$h{$Data[$bd]{$pra}{DUPSCORE}}++;
    }
    print "$pra-$NameData{$pra}\n";
    for (my $dupscore = $boardTop; $dupscore >= 0; $dupscore -=0.5) {
	printf "%3.1f: ", $dupscore;
	print '*' x $h{$dupscore};
	print "\n";
    }
    print "\n";
}

sub SaveScoreData() {
    my ($bd, $NSPair, $NSName, $NSScore, $EWPair, $EWName, $EWScore) = @_;
    # print STDERR "SaveScoreData: $bd, $NSPair, $NSName, $NSScore, $EWPair, $EWName, $EWScore\n";
    $NSPair *= 1;
    $EWPair *= 1;
    # if first round shows that NSPair is playing same number EWPair, then it must be a mitchell movement
    $isMitchell = 1 if ($NSPair == $EWPair);
    
    # for mitchell artificially bump the EW Pairs by 1/2 totalPairs
    if ($isMitchell) {
	$EWPair += int(($totalPairs + 1) / 2);
    }
    $Data[$bd]{$NSPair}{DIR} = $NS;
    $Data[$bd]{$NSPair}{SCORE} = $NSScore;
    $Data[$bd]{$EWPair}{DIR} = $EW;
    $Data[$bd]{$EWPair}{SCORE} = $EWScore;
    $Data[$bd]{$NSPair}{OPP} = $EWPair;
    $Data[$bd]{$EWPair}{OPP} = $NSPair;
    $NameData{$NSPair} = $NSName;
    $NameData{$EWPair} = $EWName;
}


sub PrintOneBoard() {
    my $bd = shift;
    my %htmp;

    print "RESULTS OF BOARD $bd\n\n";
    print "   SCORES      $ScoreName{$ScoreType}   NAMES\n";
    print "  N-S   E-W    N-S    E-W\n";

    # build a list of NS Scores for this board
    foreach my $pnum (keys %{$Data[$bd]}) {
	my $score = $Data[$bd]{$pnum}{SCORE};
	push @{$htmp{$score}}, $pnum;
    }
    # print sorted by NS Dup score
    foreach my $score (sort {$b <=> $a} keys %htmp) {
	foreach my $pnum (@{$htmp{$score}}) {
	    next if ($Data[$bd]{$pnum}{DIR} != $NS);
	    my $NSPair = $pnum;
	    my $EWPair = $Data[$bd]{$pnum}{OPP};
	    my $NSScore = $Data[$bd]{$NSPair}{SCORE};
	    my $EWScore = $Data[$bd]{$EWPair}{SCORE};
	    my $NSName = $NameData{$NSPair};
	    my $EWName = $NameData{$EWPair};
	    my $NSDup = $Data[$bd]{$NSPair}{DUPSCORE};
	    my $EWDup = $Data[$bd]{$EWPair}{DUPSCORE};
            my $fmtscore = ($NSScore >= 0 ? sprintf("%5d      ", $NSScore) : sprintf("      %5d", $EWScore));
            my $fmtdup = sprintf(($ScoreType eq 'MP' ? "%5.2f  %5.2f" : "%5d  %5d"), $NSDup, $EWDup);
            printf "%s  %s  $NSPair-$NSName vs $EWPair-$EWName\n", $fmtscore, $fmtdup;
	}
    }
    print "----------------------------\n";
}


sub PrintTotals() {
    my $href = shift;
    my %htmp;
    # print sorted by total score
    foreach my $pnum (keys %{$href}) {
	my $score = ${$href}{$pnum};
	push @{$htmp{$score}}, $pnum;
    }
    foreach my $score (sort {$b <=> $a} keys %htmp) {
	foreach my $pnum (@{$htmp{$score}}) {
	    my $Name = $NameData{$pnum};
	    my $fmtscore = sprintf (($ScoreType eq 'MP'? "%3.2f" : "%5d"), $score);
	    printf "Pair %2d %-20s  %s\n", $pnum, $Name, $fmtscore;
	}
    }
}

sub MP() {
    my $diff = shift;	
    return 1 if ($diff > 0);
    return 0.5	if ($diff == 0);
    return 0;
}

sub IMPS() {
    my $score = shift;
    my $signscore = signof($score);
    $score = abs($score);
    my @steps = (20, 50, 90, 130, 170, 220, 270, 320, 370, 430,
		 500, 600, 750, 900, 1100, 1300, 1500,
		 1750, 2000, 2250, 2500, 3000, 3500, 4000, 99999);
    for (my $i=0; $i<=24; $i++) {
	if ($score < $steps[$i]) {
	    return $i * $signscore;
	}
    }
}

sub signof {
    my $score = shift;
    return ($score < 0 ? -1 : 1);
}
