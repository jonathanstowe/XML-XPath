# $Id$

print "1..5\n";

use XML::XPath;
use XML::XPath::PerlSAX;
use XML::DOM::PerlSAX;

print "ok 1\n";

my $handler = XML::DOM::PerlSAX->new();

if ($handler) { print "ok 2\n"; }
else { print "not ok 2\n"; }

my $parser = XML::XPath::PerlSAX->new(Handler => $handler);

if ($parser) { print "ok 3\n"; }
else { print "not ok 3\n"; }

my $xpp = XML::XPath->new( filename => 'examples/test.xml' );

if ($xpp) { print "ok 4\n"; }
else { print "not ok 4\n"; }

my $nodes = $xpp->find('/timesheet/projects/project');

if ($nodes->size) { print "ok 5\n"; }
else { print "not ok 5\n"; }

my $dom;
foreach my $node ($nodes->get_nodelist) {
	warn "NODES:\n", XML::XPath::XMLParser::as_string($node), "\n\n";
	$dom = $parser->parse($node);
	if (!$dom) { print "not ok 6\n"; }
	warn "DOM::\n", $dom->toString, "\n\n";
}

print "ok 6\n" if $dom;
