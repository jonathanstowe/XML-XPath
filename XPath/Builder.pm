# $Id: Builder.pm,v 1.2 2000/02/24 19:46:03 matt Exp $

package XML::XPath::Builder;

use strict;

# to get array index constants
use XML::XPath::XMLParser;

sub new {
	my $class = shift;
	my $self = ($#_ == 0) ? { %{ (shift) } } : { @_ };

	bless $self, $class;
}


# SHOWSTOPPER!
#
# Perl SAX doesn't yet define how to handle namespaces

sub mkelement {
	my ($self, $current, $tag, $attribs) = @_;
	
	my $node = bless [], 'element';
	
	$node->[node_parent] = $current;
	$node->[node_name] = $tag;
	$node->[node_prefix] = "#default";
	#$node->[node_namespace] = $e->namespace($tag);
	$node->[node_children] = [];
	
	while (@$attribs) {
		my ($key, $val) = (shift @$attribs, shift @$attribs);
		my @newattr;
		$newattr[node_parent] = $node;
		$newattr[node_key] = $key;
		$newattr[node_value] = $val;
		$newattr[node_prefix] = "#default";
		push @{$node->[node_attribs]}, bless(\@newattr, 'attribute');
		$newattr[node_pos] = $#{$node->[node_attribs]};
	}
	
	return $node;
}

sub start_document {
	my $self = shift;
}

sub characters {
	my $self = shift;
	my $characters = shift;
	my @node;
	$node[node_parent] = $self->{Current};
	$node[node_text] = $characters->{Data};
	push @{$self->{Current}->[node_children]}, bless(\@node, 'text');
	$node[node_pos] = $#{$self->{Current}->[node_children]};
}

sub start_element {
	my $self = shift;
	my $element = shift;
	my $node = mkelement($self, $self->{Current}, $element->{Name}, $element->{Attributes});
	push @{$self->{Current}->[node_children]}, $node;
	$node->[node_pos] = $#{$self->{Current}->[node_children]};
	$self->{Current} = $node;
}

sub end_element {
	my $self = shift;
	$self->{Last} = $self->{Current};
	$self->{Current} = $self->{Current}->[node_parent];
}

sub end_document {
	my $self = shift;
	my $root = bless [], 'element';
	
	$root->[node_children] = [$self->{Last}];
	$self->{Last}->[node_parent] = $root;
	
	delete $self->{Last};
	delete $self->{Current};
	return $root;
}

sub processing_instruction {
	my $self = shift;
	my $pi = shift;
	my @node;
	$node[node_parent] = $self->{Current};
	$node[node_target] = $pi->{Target};
	$node[node_data] = $pi->{Data};
	push @{$self->{Current}->[node_children]}, bless(\@node, 'pi');
	$node[node_pos] = $#{$self->{Current}->[node_children]};
}

sub comment {
	my $self = shift;
	my $comment = shift;
	my @node;
	$node[node_parent] = $self->{Current};
	$node[node_comment] = $comment->{Data};
	push @{$self->{Current}->[node_children]}, bless(\@node, 'comment');
	$node[node_pos] = $#{$self->{Current}->[node_children]};
}

1;

__END__

=head1 NAME

XML::XPath::Builder - SAX handler for building an XPath tree

=head1 SYNOPSIS

 use AnySAXParser;
 use XML::XPath::Builder;

 $builder = XML::XPath::Builder->new();
 $parser = AnySAXParser->new( Handler => $builder );

 $root_node = $parser->parse( Source => [SOURCE] );

=head1 DESCRIPTION

C<XML::XPath::Builder> is a SAX handler for building an XML::XPath
tree.

C<XML::XPath::Builder> is used by creating a new instance of
C<XML::XPath::Builder> and providing it as the Handler for a SAX
parser.  Calling `C<parse()>' on the SAX parser will return the
root node of the tree built from that parse.

=head1 AUTHOR

Ken MacLeod, <ken@bitsko.slc.ut.us>

=head1 SEE ALSO

perl(1), XML::XPath(3)

PerlSAX.pod in libxml-perl

Extensible Markup Language (XML) <http://www.w3c.org/XML>

=cut
