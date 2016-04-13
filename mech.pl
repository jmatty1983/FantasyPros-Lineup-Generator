#!/usr/bin/perl
use strict;
use warnings;
use WWW::Mechanize;
use Time::HiRes qw( time );

#TODO: Whena adding players to arrays, check cost per point, ignore any players
#at similar costs that are less efficient


my $mech = WWW::Mechanize->new();

#set the web page to find the player data and the strings that precede and end the sub string
my $fanduelPage = 'https://www.fanduel.com/league/nfl-sunday-million';
my $startStr = 'FD.playerpicker.allPlayersFullData = {';
my $endStr = 'FD.playerpicker.teamIdToFixtureCompactString';
my $fantasyprosPage = 'http://www.fantasypros.com/nfl/projections/';

#set fan duel values
my $salaryCap = 60000;
my $pointsPerYard = 0.1;
my $pointsPerRec = 0.5;
my $pointsPerTD = 6;
my $pointsPerPTD = 4;
my $pointsPerPYard = 0.04;
my $pointsPerInt = -1;

#load page
print "Loading Fanduel Players\n";
$mech->get($fanduelPage);

my $mutationTime = 4;
my $attempts = 30;

my @qbs;
my @wrs;
my @rbs;
my @tes;
my @ks;
my @ds;

#make sure the strings surrounding the player data are found
if ((my $start = index($mech->content(), $startStr)) && (my $end = index($mech->content(), $endStr))){
	#adjust the start position to leave out the search string and extract the portion containing the player data
	$start += length($startStr);
	my $playerData = substr($mech->content(), $start, $end - $start);
	
	#load all the fantasy pros projections
	print "Loading Fantasy Pros Projections\n";
	my %fprosProjections = ();
	$mech->get($fantasyprosPage . "qb.php");
	$fprosProjections{'QB'} = $mech->content();
	$mech->get($fantasyprosPage . "rb.php");
	$fprosProjections{'RB'} = $mech->content();
	$mech->get($fantasyprosPage . "wr.php");
	$fprosProjections{'WR'} = $mech->content();
	$mech->get($fantasyprosPage . "te.php");
	$fprosProjections{'TE'} = $mech->content();
	$mech->get($fantasyprosPage . "k.php");
	$fprosProjections{'K'} = $mech->content();
	$mech->get($fantasyprosPage . "dst.php");
	$fprosProjections{'D'} = $mech->content();
	
	#split the data for individual players. Player data starts at index 1
	my @lines = split(':', $playerData);
	
	#iterate through the raw data
	for (my $i = 1; $i < scalar @lines; $i++)
	{
		#remove quotes and put each individual piece of data into an array
		$lines[$i] =~ s/"//g;
		my @values = split(',', $lines[$i]);
		
		my $bracketpos = index($values[0], '[') + 1;
		my $bracketToEnd = length($values[0]) - $bracketpos;
		$values[0] = substr($values[0], $bracketpos, $bracketToEnd);
		
		my $passyds = 0;
		my $passtds = 0;
		my $ints = 0;
		my $rushyds = 0;
		my $rushtds = 0;
		my $recs = 0;
		my $recyds = 0;
		my $rectds = 0;
		my $fpts = 0;
		my $playerFound = 0;
		
		#grab the data from the data row
		my $startChunk = index($fprosProjections{$values[0]}, $values[1]);
		
		if($startChunk > 0)
		{
			#extra row html
			my $chunkLen = index($fprosProjections{$values[0]}, '</tr>', $startChunk) - $startChunk;
			my $chunk = substr($fprosProjections{$values[0]}, $startChunk, $chunkLen);
			
			$chunk =~ s/<\/?td>//g;
			my @chunkLines = split("\n", $chunk);
			
			#setting values from table columns based on position of player
			if ($values[0] eq 'QB')
			{
				$passyds = $chunkLines[3];
				$passtds = $chunkLines[4];
				$ints = $chunkLines[5];
				$rushyds = $chunkLines[7];
				$rushtds = $chunkLines[8];
				$fpts = ($passyds * $pointsPerPYard) + ($passtds * $pointsPerPTD) + ($ints * $pointsPerInt) + ($rushyds * $pointsPerYard) + ($rushtds * $pointsPerTD);
				if($fpts > 15)
				{
					push(@qbs, {pos => $values[0], name => $values[1], cost => $values[5], fpts => $fpts});
				}
			}
			
			elsif ($values[0] eq 'RB')
			{
				$rushyds = $chunkLines[2];
				$rushtds = $chunkLines[3];				
				$recs = $chunkLines[4];
				$recyds = $chunkLines[5];
				$rectds = $chunkLines[6];
				$fpts = ($rushyds * $pointsPerYard) + ($rushtds * $pointsPerTD) + ($recs * $pointsPerRec) + ($recyds * $pointsPerYard) + ($rectds * $pointsPerTD);
				if($fpts > 10)
				{
					push(@rbs, {pos => $values[0], name => $values[1], cost => $values[5], fpts => $fpts});
				}
			}
			
			elsif ($values[0] eq 'WR')
			{
				$rushyds = $chunkLines[2];
				$rushtds = $chunkLines[3];				
				$recs = $chunkLines[4];
				$recyds = $chunkLines[5];
				$rectds = $chunkLines[6];
				$fpts = ($rushyds * $pointsPerYard) + ($rushtds * $pointsPerTD) + ($recs * $pointsPerRec) + ($recyds * $pointsPerYard) + ($rectds * $pointsPerTD);
				if($fpts > 10)
				{
					push(@wrs, {pos => $values[0], name => $values[1], cost => $values[5], fpts => $fpts});
				}
			}
			
			elsif ($values[0] eq 'TE')
			{
				$recs = $chunkLines[1];
				$recyds = $chunkLines[2];
				$rectds = $chunkLines[3];
				$fpts = ($recs * $pointsPerRec) + ($recyds * $pointsPerYard) + ($rectds * $pointsPerTD);
				if($fpts > 10)
				{
					push(@tes, {pos => $values[0], name => $values[1], cost => $values[5], fpts => $fpts});
				}
			}
			
			elsif ($values[0] eq 'K')
			{
				$fpts = $chunkLines[4];
				if($fpts > 3)
				{
					push(@ks, {pos => $values[0] . " ", name => $values[1], cost => $values[5], fpts => $fpts});
				}
			}
			
			elsif ($values[0] eq 'D')
			{
				$fpts = $chunkLines[10];
				if($fpts > 0)
				{
					push(@ds, {pos => $values[0] . " ", name => $values[1], cost => $values[5], fpts => $fpts});
				}
			}
					
		}
	}
	
	my @finalLineup;
	
	my $keptLineup = 0;
	while($keptLineup < $attempts)
	{
		my $start = time();
		#initialize lineup
		my @lineup;
		my @tmpLineup;
		my $rand = 0;
		my $player = 0;
		for(my $i = 0; $i < 9; $i++)
		{
			$lineup[$i] = $ds[scalar @ds - 1];
			$tmpLineup[$i] = $ds[scalar @ds - 1];
		}
		
		my $failed = 0;
		my $mutationRate = 9;
		my $mutated = 0;
		my $iterations = 0;
		my $step = -1;
		while(time() - $start < $mutationTime)
		{
			#count mutation attempts
			$iterations++;
			#if there's been 500 consecutive failed mutations, change the numberof players to randomize, trying to keep the lineup fluid
			if ($failed > 500)
			{
				$mutationRate += $step;
				$step = 1 if $mutationRate == 2;
				$step = -1 if $mutationRate == 3;
				$failed = 0;			
			}
			
			#set a temporary lineup with some random players
			for(my $i = 0; $i < $mutationRate; $i++)
			{
				$rand = int(rand(9));

				$player = $qbs[int(rand(scalar @qbs))] if $rand == 0;
				$player = $rbs[int(rand(scalar @rbs))] if $rand == 1;
				$player = $rbs[int(rand(scalar @rbs))] if $rand == 2;
				$player = $wrs[int(rand(scalar @wrs))] if $rand == 3;
				$player = $wrs[int(rand(scalar @wrs))] if $rand == 4;
				$player = $wrs[int(rand(scalar @wrs))] if $rand == 5;
				$player = $tes[int(rand(scalar @tes))] if $rand == 6;
				$player = $ks[int(rand(scalar @ks))] if $rand == 7;
				$player = $ds[int(rand(scalar @ds))] if $rand == 8;
				
				my $duped = 0;
				for(my $t = 0; $t < 9; $t++)
				{
					$duped = 1 if $tmpLineup[$t] == $player;
				}
				$tmpLineup[$rand] = $player unless $duped;
			}
			
			#check salary cap and count projected points
			my $tmpSalary = 0;
			my $curFpts = 0;
			my $tmpFpts = 0;
			for(my $i = 0; $i < 9; $i++)
			{
				$curFpts += ${$lineup[$i]}{'fpts'} if $lineup[$i];
				$tmpFpts += ${$tmpLineup[$i]}{'fpts'} if $tmpLineup[$i];
				$tmpSalary += ${$tmpLineup[$i]}{'cost'} if $tmpLineup[$i];
			}
			
			#if benefitial mutation save to line up, ortherwise reset temporary lineup
			if ($tmpFpts > $curFpts && $tmpSalary <= $salaryCap)
			{
				@lineup = @tmpLineup;
				$failed = 0;
				$mutated++;
			}
			else
			{
				@tmpLineup = @lineup;
				$failed++;
			}
		}
		
		@finalLineup = @lineup if not @finalLineup;
		
		my $curFpts = 0;
		my $tmpFpts = 0;

		for(my $i = 0; $i < 9; $i++)
		{
			$curFpts += ${$finalLineup[$i]}{'fpts'} if $finalLineup[$i];
			$tmpFpts += ${$lineup[$i]}{'fpts'} if $lineup[$i];
		}
		
		if ($tmpFpts > $curFpts)
		{
			@finalLineup = @lineup;
			$keptLineup = 0;
		}
		else
		{
			$keptLineup++;
		}
		print "$keptLineup |  $curFpts | $tmpFpts\n";
	}
	
	#output
	my $points = 0;
	my $salary = 0;
	print "\n";
	for(my $i = 0; $i < 9; $i++)
	{
		$points += ${$finalLineup[$i]}{'fpts'};
		$salary += ${$finalLineup[$i]}{'cost'};
		print ${$finalLineup[$i]}{'pos'}, " | ", ${$finalLineup[$i]}{'name'}, " | ", ${$finalLineup[$i]}{'cost'}, " | ", ${$finalLineup[$i]}{'fpts'}, "\n"  if $finalLineup[$i];
	}
	my $end = time();
	print "Pts: $points | \$: $salary \n";
}