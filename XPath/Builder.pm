# $Id: Builder.pm,v 1.1 2000/02/18 15:17:59 matt Exp $

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
	my $atnodes;
	while (@$attribs) {
		my ($key, $val) = (shift @$attribs, shift @$attribs);
		#my $namespace = $e->namespace($key) || "#default";
		my $namespace = "#default";
		$atnodes->{$key}->{$namespace} = $val;
	}
	
	my $node;
	$node->[node_type] = 'element';
	$node->[node_parent] = $current;
	$node->[node_name] = $tag;
	$node->[node_attribs] = $atnodes;
	$node->[node_namespace] = "#default";
	#$node->[node_namespace] = $e->namespace($tag);
	$node->[node_children] = [];
	
	return $node;
}

sub start_document {
	my $self = shift;
}

sub characters {
	my $self = shift;
	my $characters = shift;
	my $node;
	$node->[node_type] = 'text';
	$node->[node_parent] = $self->{Current};
	$node->[node_text] = $characters->{Data};
	push @{$self->{Current}->[node_children]}, $node;
	$node->[node_pos] = $#{$self->{Current}->[node_children]};
}

sub start_element {
	my $self = shift;
	my $element = shift;
	warn "Start $tag->{'Name'}\n";
	my $node = mkelement($self, $self->{Current}, $element->{Name}, $element->{Attributes});
	push @{$self->{Current}->[node_children]}, $node;
	$node->[node_pos] = $#{$self->{Current}->[node_children]};
	warn "Node name = ", $node->[node_name], "\n";
	$self->{Current} = $node;
}

sub end_element {
	my $self = shift;
	$self->{Current} = $self->{Current}->[node_parent] if $self->{Current}->[node_parent];
}

sub end_document {
	my $self = shift;
	warn "Root node = ", $self->{Current}->[node_name], "\n";
	return $self->{Current};
}

sub processing_instruction {
	my $self = shift;
	my $pi = shift;
	my $node;
	$node->[node_parent] = $self->{Current};
	$node->[node_type] = 'pi';
	$node->[node_target] = $pi->{Target};
	$node->[node_data] = $pi->{Data};
	push @{$self->{Current}->[node_children]}, $node;
	$node->[node_pos] = $#{$self->{Current}->[node_children]};
}

sub comment {
	my $self = shift;
	my $comment = shift;
	my $node;
	$node->[node_parent] = $self->{Current};
	$node->[node_type] = 'comment';
	$node->[node_comment] = $comment->{Data};
	push @{$self->{Current}->[node_children]}, $node;
	$node->[node_pos] = $#{$self->{Current}->[node_children]};
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
