# $Id: Element.pm,v 1.2 2000/05/08 16:48:46 matt Exp $

package XML::XPath::Node::Element;

use strict;
use vars qw/@ISA/;

@ISA = ('XML::XPath::Node');

package XML::XPath::Node::ElementImpl;

use vars qw/@ISA/;
@ISA = ('XML::XPath::NodeImpl', 'XML::XPath::Node::Element');
use XML::XPath::Node ':node_keys';

sub new {
	my $class = shift;
	my ($tag, $prefix) = @_;
	
	my $self = [undef, undef, $prefix, [], $tag];
	bless $self, $class;
}

sub getNodeType { ELEMENT_NODE }

sub isElementNode { 1; }

sub appendChild {
	my $self = shift;
	my $newnode = shift;
#	warn "AppendChild $newnode to $self\n";
	push @{$self->[node_children]}, $newnode;
	$newnode->setParentNode($self);
	$newnode->set_pos($#{$self->[node_children]});
}

sub DESTROY {
	my $self = shift;
#	warn "DESTROY ELEMENT: ", $self->[node_name], "\n";
#	$self->[node_parent] = undef;
	foreach my $kid ($self->getChildNodes) {
		$kid->del_parent_link;
	}
	foreach my $attr ($self->getAttributeNodes) {
		$attr->del_parent_link;
	}
	foreach my $ns ($self->getNamespaceNodes) {
		$ns->del_parent_link;
	}
 	$self->[node_children] = undef;
 	$self->[node_attribs] = undef;
 	$self->[node_namespaces] = undef;
}

sub getName {
	my $self = shift;
	$self->[node_name];
}

sub getLocalName {
	my $self = shift;
	my $local = $self->[node_name];
	$local =~ s/.*://;
	return $local;
}

sub getChildNodes {
	my $self = shift;
	if ($self->[node_children]) {
		return wantarray ? @{$self->[node_children]} : $self->[node_children];
	}
	return wantarray ? () : [];
}

sub getChildNode {
	my $self = shift;
	my ($pos) = @_;
	if ($pos < 1 || $pos > @{$self->[node_children]}) {
		return;
	}
	return $self->[node_children][$pos - 1];
}

sub getAttribute {
	my $self = shift;
	my ($name) = @_;
	my $attribs = $self->[node_attribs];
	foreach my $attr (@$attribs) {
		return $attr if $attr->getName eq $name;
	}
}

sub getAttributes {
	my $self = shift;
	if ($self->[node_attribs]) {
		return wantarray ? @{$self->[node_attribs]} : $self->[node_attribs];
	}
	return wantarray ? () : [];
}

sub getAttributeNodes { goto &getAttributes; }

sub appendAttribute {
	my $self = shift;
	my ($attribute) = @_;
	push @{$self->[node_attribs]}, $attribute;
	$attribute->setParentNode($self);
	$attribute->set_pos($#{$self->[node_attribs]});
}	

sub getNamespace {
	my $self = shift;
	my ($prefix) = @_;
	my $namespaces = $self->[node_namespaces];
	return unless $namespaces;
	foreach my $ns (@$namespaces) {
		return $ns if $ns->getPrefix eq $prefix;
	}
}

sub getNamespaces {
	my $self = shift;
	if ($self->[node_namespaces]) {
		return wantarray ? @{$self->[node_namespaces]} : $self->[node_namespaces];
	}
	return wantarray ? () : [];
}

sub getNamespaceNodes { goto &getNamespaces }

sub appendNamespace {
	my $self = shift;
	my ($ns) = @_;
	push @{$self->[node_namespaces]}, $ns;
	$ns->setParentNode($self);
	$ns->set_pos($#{$self->[node_namespaces]});
}

sub getPrefix {
	my $self = shift;
	$self->[node_prefix];
}

sub getExpandedName {
	my $self = shift;
	warn "Expanded name not implemented for ", ref($self), "\n";
	return;
}

sub _to_sax {
	my $self = shift;
	my ($doch, $dtdh, $enth) = @_;
	
	my $tag = $self->getName;
	my @attr;
	
	for my $attr ($self->getAttributes) {
		push @attr, $attr->getName, $attr->getValue;
	}
	
	my $ns = $self->getNamespace($self->[node_prefix]);
	if ($ns) {
		$doch->start_element( 
				{ 
				Name => $tag,
				Attributes => { @attr },
				NamespaceURI => $ns->getExpanded,
				Prefix => $ns->getPrefix,
				LocalName => $self->getLocalName,
				}
			);
	}
	else {
		$doch->start_element(
				{
				Name => $tag,
				Attributes => { @attr },
				}
			);
	}
	
	for my $kid ($self->getChildNodes) {
		$kid->_to_sax($doch, $dtdh, $enth);
	}
	
	if ($ns) {
		$doch->end_element( 
				{
				Name => $tag,
				NamespaceURI => $ns->getExpanded,
				Prefix => $ns->getPrefix,
				LocalName => $self->getLocalName
				}
			);
	}
	else {
		$doch->end_element( { Name => $tag } );
	}
}

sub string_value {
	my $self = shift;
	my $string = '';
	foreach my $kid (@{$self->[node_children]}) {
		if ($kid->getNodeType == ELEMENT_NODE
				|| $kid->getNodeType == TEXT_NODE) {
			$string .= $kid->string_value;
		}
	}
	return $string;
}

sub toString {
	my $self = shift;
	my $norecurse = shift;
	my $string = '';
	if (! $self->[node_name] ) {
		# root node
		foreach my $kid (@{$self->[node_children]}) {
			$string .= $kid->toString;
		}
		return $string;
	}
	$string .= "<" . $self->[node_name];
	
	foreach my $ns (@{$self->[node_namespaces]}) {
		$string .= $ns->toString;
	}
	
	foreach my $attr (@{$self->[node_attribs]}) {
		$string .= $attr->toString;
	}
	
	if (@{$self->[node_children]}) {
		$string .= ">";

		if (!$norecurse) {
			foreach my $kid (@{$self->[node_children]}) {
				$string .= $kid->toString($norecurse);
			}
		}
		
		$string .= "</" . $self->[node_name] . ">";
	}
	else {
		$string .= " />";
	}
	
	return $string;
}

1;
__END__

=head1 NAME

Element - an <element>

=head1 API

=head2 new ( name, prefix )

Create a new Element node with name "name" and prefix "prefix". The name
be "prefix:local" if prefix is defined. I know that sounds wierd, but it
works ;-)

=head2 getName

Returns the name (including "prefix:" if defined) of this element.

=head2 getLocalName

Returns just the local part of the name (the bit after "prefix:").

=head2 getChildNodes

Returns the children of this element. In list context returns a list. In
scalar context returns an array ref.

=head2 getChildNode ( pos )

Returns the child at position pos.

=head2 appendChild ( childnode )

Appends the child node to the list of current child nodes.

=head2 getAttribute ( name )

Returns the attribute node with key name.

=head2 getAttributes / getAttributeNodes

Returns the attribute nodes. In list context returns a list. In scalar
context returns an array ref.

=head2 appendAttribute ( attrib_node)

Appends the attribute node to the list of attributes (XML::XPath stores
attributes in order).

=head2 getNamespace ( prefix )

Returns the namespace node by the given prefix

=head2 getNamespaces / getNamespaceNodes

Returns the namespace nodes. In list context returns a list. In scalar
context returns an array ref.

=head2 appendNamespace ( ns_node )

Appends the namespace node to the list of namespaces.

=head2 getPrefix

Returns the prefix of this element

=head2 getExpandedName

Returns the expanded name of this element (not yet implemented right).

=head2 string_value

For elements, the string_value is the concatenation of all string_values
of all text-descendants of the element node in document order.

=head2 toString ( [ norecurse ] )

Output (and all children) the node to a string. Doesn't process children
if the norecurse option is a true value.

=cut
