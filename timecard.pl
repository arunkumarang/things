use strict;
use Error::Die; # DEPEND
use TimeCard; # DEPEND
use Editor; # DEPEND

my $TIMECARD = $ENV{TIMECARD} || "$ENV{HOME}/.timecard";

my $YEARLY_RATE = 100000;

my $CURRENCY = "INR";

my $what = shift;

sub help {
  print "\nusage:\n";
  print "  timecard in \'working on foo\' \n";
  print "  timecard out    \n";
  print "  timecard edit   # manually munge the data\n";
  print "  timecard sum    # total hours worked\n";
  print "  timecard list   # per-slot report\n";
  print "  timecard daily  \n";
  print "  timecard rate   \n";
}

if ($what eq 'in') {
  my $tc = TimeCard->new($TIMECARD);
  $tc->punch_in(@ARGV ? join(' ', @ARGV) : undef);
  $tc->save($TIMECARD);
}

elsif ($what eq 'out') {
  my $tc = TimeCard->new($TIMECARD);
  $tc->punch_out(@ARGV ? join(' ', @ARGV) : undef);
  $tc->save($TIMECARD);
}

elsif ($what eq 'comment') {
  my $tc = TimeCard->new($TIMECARD);
  $tc->comment(@ARGV ? join(' ', @ARGV) : undef);
  $tc->save($TIMECARD);
}

elsif ($what eq 'edit') {
  my $e = Editor::guess;
  exec $e, $TIMECARD
    or die "unable to exec editor '$e': $!";
}

elsif ($what eq 'sum') {
  my $tc = TimeCard->new($TIMECARD);
  my $total = DateTime::Duration->new;
  $total += $_->duration foreach $tc->slots;
  print $total->timecard_hours, " hours\n";
}

elsif ($what eq 'list') {
  my $tc = TimeCard->new($TIMECARD);
  foreach my $slot ($tc->slots) {
    print $slot->duration->timecard_hours, ' ';
    print join(' / ', $slot->comments);
    print "\n";
  }
}

elsif ($what eq 'daily') {
  my $tc = TimeCard->new($TIMECARD);
  my @slots = $tc->slots;
  my $total = 0;
  my $i = 0;
  while ($i < @slots) {
    my $date = $slots[$i]->date;
    my $end = $i + 1;
    while ($end < @slots && $date eq $slots[$end]->date) {
      $end++;
    }

    my $sum = 0;
    $sum += $_->duration->timecard_hours for (@slots[$i..$end-1]);
    $sum = round_up_to($sum, 0.25);
    $total += $sum;
    printf "%s %.02f\n", $date, $sum;

    my %seen;
    print map { " - $_\n" }
          grep { !$seen{$_}++ }
          map { $_->comments }
          @slots[$i..$end-1];
    $i = $end;
  }
  print "total: $total\n";
}

elsif ($what eq 'rate') {
  my $work_hour = 40;
  my $work_week = 52;
  my $hourly_rate = $YEARLY_RATE / ($work_hour * $work_week);
  my $daily_rate = $hourly_rate * 8;

  printf "hourly rate : %d %s\n", int($hourly_rate), $CURRENCY;
  printf "daily rate  : %d %s\n", int($daily_rate),  $CURRENCY;
}

elsif ($what eq 'help') {
  help()
}

elsif (!$what) {
  my $tc = TimeCard->new($TIMECARD);
  my $slot = $tc->recent;
  if ($slot && $slot->in_progress) {
    print "You are currently punched IN (",
            $slot->duration->timecard_hours, " hours)\n";
    if ($slot->comments) {
      print "Comments:\n";
      print " - ", $_, "\n" foreach $slot->comments;
    }
  }
  else {
    print "You are currently punched OUT.\n";
    help()
  }
}

else {
  die "unknown subcommand: $what";
}

sub round_up_to {
  my ($n, $increment) = @_;
  my $units = $n / $increment;
  $units++ unless $units == int($units);
  return int($units) * $increment;
}
