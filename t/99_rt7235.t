#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use XML::XPath;

my $val='<ROOT_NODE><SUBNODE>test</SUBNODE></ROOT_NODE>';
my $xp=XML::XPath->new(xml=>$val);
eval {
   my $nodes = $xp->find('\\');
};
if ( defined $@ && $@ =~ /Invalid query somewhere around here/ ) {
   ok(1, "clearly says that it is an invalid query");
}
else {
   ok(0, "doesn't say it's an invalid query");
}


done_testing;
