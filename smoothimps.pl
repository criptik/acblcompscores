use strict;

my @tbl = (0, 20, 50, 90, 130, 170, 220, 270,
		   320, 370, 430, 500, 600, 750, 900,
		   1100, 1300, 1500, 1750, 2000, 2250,
		   2500, 3000, 3500, 4000);

my $board;
my @PairMapping;

sub StepImps {
	my $pts = shift;
	if ($pts < 0) {return -1*StepImps(-1*$pts);}
	my $imps = 0;
	if ($pts >= 4000) {return 24;}
	for ($imps = 0; $imps<24; $imps++)
	{
		if ($pts < $tbl[$imps+1])
		{
			return $imps;
		}
	}
}

sub SmoothImps {
	my $pts = shift;
	if ($pts < 0) {return -1*SmoothImps(-1*$pts);}
	if    ($pts <= 45)  {return ($pts / 30)      }
	elsif ($pts <= 165) {return ($pts +   15)/ 40}
	elsif ($pts <= 365) {return ($pts +   60)/ 50}
	elsif ($pts <= 425) {return ($pts +  145)/ 60}
	elsif ($pts <= 495) {return ($pts +  240)/ 70}
	elsif ($pts <= 595) {return ($pts +  555)/100}
	elsif ($pts <= 895) {return ($pts + 1130)/150}
	elsif ($pts <=1495) {return ($pts + 1805)/200}
	elsif ($pts <=2495) {return ($pts + 2630)/250}
	elsif ($pts <=4245) {return ($pts + 7755)/500}
	else                {return 24}   # maximum score
}


sub Show {
	my @scores = splice(@_, 0, 3);
	my @BRes = splice(@_, 0, 3);
	my $BAvg = shift;
	my @BSRes = splice(@_, 0, 3);
	my $BSAvg = shift;
	my @ZRes = splice(@_, 0, 3);
	my $ZAvg = shift;
	my @CRes = splice(@_, 0, 3);
	my @MRes = splice(@_, 0, 3);
	for (my $i=0; $i<3; $i++) {
		printf "%4d: %5.1f  %5.1f  %5.1f  %5.1f  %5.1f\n", $scores[$i], $BRes[$i], $BSRes[$i], $CRes[$i], $ZRes[$i], $MRes[$i];
	}
	printf "Avgs: %5.1f  %5.1f  %5.1f\n", $BAvg, $BSAvg, $ZAvg;

}

sub ShowTot {
	my $nam = shift;
	my @res = @_;
	printf "%s:  %7.3f  %7.3f  %7.3f  %7.3f  %7.3f  %7.3f\n", $nam, $res[0], $res[1], $res[2], $res[3], $res[4], $res[5];
}

sub AddToInd {
	my $ismp = shift;  # set if using mp calcs
	my $aref = shift;
	my @bref = @_;
	my @pmap =  @PairMapping;
	for (@bref) 
	{
		my $ns = $_;
		my $ew = (!$ismp ?  -1*$ns : 2-$ns);
		my $ixns = (shift @pmap) - 1;
		my $ixew = (shift @pmap) - 1;
		$$aref[$ixns] += $ns;
		$$aref[$ixew] += $ew;
	}
}


sub ButlerStep {
	# discrete
	my @scores = @_;
	my @results;
	my $avg = ($scores[0] + $scores[1] + $scores[2])/3;
	# round avg do nearest multiple of 10
	# $avg = int (($avg + 5) - ($avg+5)%10);
	for (my $i=0; $i<3; $i++) {
		$results[$i] = StepImps($scores[$i] - $avg);
	}
	return (@results, $avg);
}

sub ButlerSmooth {
	# discrete
	my @scores = @_;
	my @results;
	my $avg = ($scores[0] + $scores[1] + $scores[2])/3;   # no rounding needed here
	for (my $i=0; $i<3; $i++) {
		$results[$i] = SmoothImps($scores[$i] - $avg);
	}
	return (@results, $avg);
}

sub CrossImps {
	my @scores = @_;
	my @results;
	for (my $i=0; $i<3; $i++) {
		my $sum = 0;
		for (my $j=0; $j<3; $j++) {
			if ($i != $j) {$sum += StepImps($scores[$i] - $scores[$j]);}
		}
		$results[$i] = $sum / 2;
	}
	return @results;
}

sub ZeroPar {
    # now find the zero-based par for a threesome of scores
	my @scores = @_;
	my @res;
	my $ressum;
	my $avg = ($scores[0] + $scores[1] + $scores[2])/3;
	do {
		for (my $i=0; $i<3; $i++) {
			$res[$i] = SmoothImps($scores[$i] - $avg);
		}
	    $ressum = $res[0] + $res[1] + $res[2];
		#print "-- Avg: $avg\n";
		$avg += $ressum;
	}while (abs($ressum) > 0.01);
	return (@res, $avg);
}

sub MatchPoints {
	my @scores = @_;
	my $i;
	my $j;
	my @res;
	foreach $i (@scores) {
		my $mp = 0;
		foreach $j (@scores) {
			if ($i > $j) {$mp += 1;}
			elsif ($i == $j) {$mp += 0.5;}
		}
		$mp -= 0.5;   # ignore self match
		$mp -= 1;     # to make zero relative
		push @res, $mp;
	}
	return @res;
}

my $x;
foreach $x (0, 100, 200, 169) {
	printf "%4d IMPS: %2d,  SmoothImps: %4.2f\n", $x, StepImps($x), SmoothImps($x);
}

my @samples =
	(
#	 620, 620, -100,
#	 620, -100, -100,
#	 620, 620, 620,
#	100, 0, -100,
#	620, 170, -100,
#	620, 620, 170,
#	1430, -100, 620,
#	1430, 1430, -100,
#	100, 170, -50,

	 140, -50, -50,
	 500, 620, 150,
	 500, -110, 100,
	 -100, -120, 200,
	 -120, -100, -180,

	 -50, 800, -100,
	 140, 140, 140,
	 -100, -500, 50,
	 -100, -560, -140,
	 -200, -100, 600,

	 -110, -50, -110,
	 -100, 100, 140,
	 -130, -110, -800,
	 50, -110, -130,
	 620, -100, -100,

	 100, 110, 0,
	 200, 100, -50,
	 -150, 50, -200,
	 -150, -100, -300,
	 620, 1440, 690,

	 650, -100, 690,
	 400, -50, -50,
	 -130, -620, -150,
	 100, -550, -100,
	 -650, -680, -650,
			   );

my @PairRounds = 
	(
	 4,2,5,3,6,1,
	 1,5,4,3,6,2,
	 2,1,5,4,6,3,
	 2,5,3,1,6,4,
	 1,4,3,2,6,5,
	 );


my @BTot; 
my @BSTot;
my @ZTot;
my @CTot;
my @MTot;

while (@samples)
{
	my @scores = splice @samples, 0, 3;
	# find butler scoring
	
	my @BRes = ButlerStep @scores;
	my @BSRes = ButlerSmooth @scores;
	my @ZRes = ZeroPar @scores;
	my @CRes = CrossImps @scores;
	my @MRes = MatchPoints @scores;
	print "=== Board ", $board+1, "  ==================================\n";
	Show (@scores, @BRes, @BSRes, @ZRes, @CRes, @MRes);

	# get rid of averages
	pop @BRes;
	pop @BSRes;
	pop @ZRes;
	
	if (($board % 5)  == 0) {@PairMapping = splice(@PairRounds, 0, 6);}

	AddToInd (0, \@BTot, @BRes);
	AddToInd (0, \@BSTot, @BSRes);
	AddToInd (0, \@ZTot, @ZRes);
	AddToInd (0, \@CTot, @CRes);
	AddToInd (0, \@MTot, @MRes);  # 1 means matchpoint calcs

	if (($board % 5)  == 4)
	{
		print "--------------\n";
		ShowTot "B ", @BTot;
		ShowTot "BS", @BSTot;
		ShowTot "Z ", @ZTot;
		ShowTot "C ", @CTot;
		ShowTot "MP", @MTot;
	}
	$board++;
}	
	






