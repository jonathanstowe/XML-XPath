print "1..6\n";
use XML::XPath;
use XML::XPath::Parser;
use XML::XPath::XMLParser;

my $p = XML::XPath->new( filename => 'examples/test.xml' );
if ($p) { print "ok 1\n"; }
else { print "not ok 1\n"; }

my $pp = XML::XPath::Parser->new();
if ($pp) { print "ok 2\n"; }
else { print "not ok 2\n"; }

$pp->parse("variable('amount', number(number(./rate/text()) * number(./units_worked/text())))");

my $path = $pp->parse('.//
		tag/
		child::*/
		processing-instruction("Fred")/
		self::node()[substr("33", 1, 1)]/
		attribute::ra[../@gunk] 
			[(../../@att="va\'l") and (@bert = "geee")]
			[position() = child::para/fred]
			[0 -.3]/
		geerner[(fart | blert)[predicate[@vee]]]');

if ($path) { print "ok 3\n"; }
else { print "not ok 3\n"; }

#$path = $pp->parse('param|title');

warn "PATH: ", $path->as_string, "\n\n";

if ($path->as_string) { # eq q^(self::node()/descendant-or-self::node()/child::tag/child::*/child::processing-instruction('Fred')/child::id((child::xml/child::vccc/child::bbbb/attribute::fer))/self::node()[(substr(('33'),(1),(1)))]/attribute::ra[(parent::node()/attribute::gunk)][((parent::node()/parent::node()/attribute::att = ('va&apos;l')) and ((attribute::bert = ('geee'))))][(position() = (child::para/child::fred))][(.3)]/child::geerner[((child::fart | (child::blert))[(child::predicate[(attribute::vee)])])])^ ) { 
	print "ok 4\n"; 
}
else { print "not ok 4\n"; }

my $nodes = $p->find('/timesheet//wednesday');

# warn "$nodes size: ", $nodes->size, "\n";

if ($nodes) { print "ok 5\n"; }
else { print "not ok 5\n"; }

foreach my $node ($nodes->get_nodelist) {
	warn "NODES:\n", XML::XPath::XMLParser::as_string($node), "\n\n";
}

print "ok 6\n";
