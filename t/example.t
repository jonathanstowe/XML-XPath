print "1..2\n";

use XML::XPath;
use XML::XPath::XMLParser;

my $xp = XML::XPath->new(filename => 'examples/test.xml');
print "ok 1\n" if $xp;

my $nodeset = $xp->find('/timesheet/projects/project[@Name = "Consultancy"]');

print "ok 2\n" if $nodeset;

warn "NODESET: $nodeset\n";

foreach my $node ($nodeset->get_nodelist) {
	warn XML::XPath::XMLParser::as_string($node);
}
