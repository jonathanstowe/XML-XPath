# $Id: Root.pm,v 1.3 2000/02/24 19:46:03 matt Exp $

package XML::XPath::Root;
use strict;
use XML::XPath::XMLParser;
use XML::XPath::NodeSet;

sub new {
	my $class = shift;
	my $self; # actually don't need anything here - just a placeholder
	bless \$self, $class;
}

sub as_string {
	# do nothing
}

sub evaluate {
	my $self = shift;
	my $nodeset = shift;
	
#	warn "Eval ROOT\n";
	
	# must only ever occur on 1 node
	die "Can't go to root on > 1 node!" unless $nodeset->size == 1;
	
	my $node = $nodeset->get_node(1);
	while($node->[node_parent]) {
		$node = $node->[node_parent];
	}
	
	my $newset = XML::XPath::NodeSet->new();
	$newset->push($node);
	return $newset;
}

1;
