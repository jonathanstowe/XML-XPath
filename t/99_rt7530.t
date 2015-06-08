#!perl

use strict;
use warnings;

use Test::More;

use XML::XPath;

my $xp = XML::XPath->new( ioref => *DATA);

my @nodes = $xp->findnodes('/AAA/DDD/BBB');

my %tests = (
   ns1 => {
      should_see => 1,
      uri   => 'uri:namespace1',
   },
   ns2 => {
      should_see => 0,
      uri   => 'uri:namespace2',
   },
   ns3 => {
      should_see => 1,
      uri   => 'uri:namespace3',
   },
   ns4 => {
      should_see => 1,
      uri   => 'uri:namespace4',
   },
);

foreach my $node (@nodes) {
    my @nsps = $xp->findnodes('namespace::*', $node);
    foreach my $nsp (@nsps) {
        my $pref = $nsp->getPrefix;
        my $uri = $nsp->getExpanded;
        $tests{$pref}->{seen} = 1;
        $tests{$pref}->{seen_uri} = $uri;
    }    

}

foreach my $ns ( keys %tests ) {
   my $test = $tests{$ns};

   if (! exists $test->{should_see} ) {
      fail "saw unexpected namspace prefix $ns";
   }
   else {
      if ( $test->{should_see} ) {
         ok(exists $test->{seen}, "got expected namespace prefix $ns");
         ok(exists $test->{seen_uri} and ( $test->{uri} eq $test->{seen_uri}), "got the correct namespace URI for $ns");
      }
      else {
         ok(!exists $test->{seen}, "didn't get namespace prefix $ns");
      }

   }
}

done_testing();
__DATA__
<AAA xmlns:ns1="uri:namespace1">
    <BBB/>
    <CCC xmlns:ns2="uri:namespace2"/>
    <BBB/>
    <CCC/>
    <BBB/>
    <!-- comment -->
    <DDD xmlns:ns3="uri:namespace3">
        <BBB xmlns:ns4="uri:namespace4"/>
        Text
        <BBB/>
    </DDD>
    <CCC/>
</AAA>





