# $Id: Attribute.pm,v 1.2 2000/05/08 16:48:46 matt Exp $

package XML::XPath::Node::Attribute;

use strict;
use vars qw/@ISA/;

@ISA = ('XML::XPath::Node');

package XML::XPath::Node::AttributeImpl;

use vars qw/@ISA/;
@ISA = ('XML::XPath::NodeImpl', 'XML::XPath::Node::Attribute');
use XML::XPath::Node ':node_keys';

sub new {
	my $class = shift;
	my ($key, $val, $prefix) = @_;
	
	my $self = [undef, undef, $prefix, $key, $val];
	bless $self, $class;
}

sub getNodeType { ATTRIBUTE_NODE }

sub isAttributeNode { 1; }

sub getName {
	my $self = shift;
	$self->[node_key];
}

sub getValue {
	my $self = shift;
	$self->[node_value];
}

sub getData {
	my $self = shift;
	$self->[node_value];
}

sub getPrefix {
	my $self = shift;
	$self->[node_prefix];
}

sub string_value {
	my $self = shift;
	return $self->[node_value];
}

sub toString {
	my $self = shift;
	my $string = ' ';
	if ($self->[node_prefix]) {
		$string .= $self->[node_prefix] . ':';
	}
	$string .= join('',
					$self->[node_key],
					'="',
					XML::XPath::Node::XMLescape($self->[node_value], '"&><'),
					'"');
	return $string;
}

1;
__END__

=head1 NAME

Attribute - a single attribute

=head1 API

=head2 new ( key, value, prefix )

Create a new attribute node.

=head2 getName

Returns the key for the attribute

=head2 getValue / getData

Returns the value

=head2 getPrefix

Returns the prefix

=head2 toString

Generates key="value", encoded correctly.

=cut
