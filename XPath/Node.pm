# $Id: Node.pm,v 1.2 2000/05/08 16:48:23 matt Exp $

package XML::XPath::Node;

use strict;
use vars qw(@ISA @EXPORT $AUTOLOAD %EXPORT_TAGS @EXPORT_OK);
use Exporter;
use Carp;
@ISA = ('Exporter');

sub UNKNOWN_NODE () {0;}
sub ELEMENT_NODE () {1;}
sub ATTRIBUTE_NODE () {2;}
sub TEXT_NODE () {3;}
sub CDATA_SECTION_NODE () {4;}
sub ENTITY_REFERENCE_NODE () {5;}
sub ENTITY_NODE () {6;}
sub PROCESSING_INSTRUCTION_NODE () {7;}
sub COMMENT_NODE () {8;}
sub DOCUMENT_NODE () {9;}
sub DOCUMENT_TYPE_NODE () {10;}
sub DOCUMENT_FRAGMENT_NODE () {11;}
sub NOTATION_NODE () {12;}

# Non core DOM stuff
sub ELEMENT_DECL_NODE () {13;}
sub ATT_DEF_NODE () {14;}
sub XML_DECL_NODE () {15;}
sub ATTLIST_DECL_NODE () {16;}
sub NAMESPACE_NODE () {17;}

# per-node constants

# All
sub node_parent () { 0; }
sub node_pos () { 1; }

# Element
sub node_prefix () { 2; }
sub node_children () { 3; }
sub node_name () { 4; }
sub node_attribs () { 5; }
sub node_namespaces () { 6; }

# Char
sub node_text () { 2; }

# PI
sub node_target () { 2; }
sub node_data () { 3; }

# Comment
sub node_comment () { 2; }

# Attribute
# sub node_prefix () { 2; }
sub node_key () { 3; }
sub node_value () { 4; }

# Namespaces
# sub node_prefix () { 2; }
sub node_expanded () { 3; }

@EXPORT = qw(
	UNKNOWN_NODE
	ELEMENT_NODE
	ATTRIBUTE_NODE
	TEXT_NODE
	CDATA_SECTION_NODE
	ENTITY_REFERENCE_NODE
	ENTITY_NODE
	PROCESSING_INSTRUCTION_NODE
	COMMENT_NODE
	DOCUMENT_NODE
	DOCUMENT_TYPE_NODE
	DOCUMENT_FRAGMENT_NODE
	NOTATION_NODE
	ELEMENT_DECL_NODE
	ATT_DEF_NODE
	XML_DECL_NODE
	ATTLIST_DECL_NODE
	NAMESPACE_NODE
	);

@EXPORT_OK = qw(
			node_parent
			node_pos
			node_prefix
			node_children
			node_name
			node_attribs
			node_namespaces
			node_text
			node_target
			node_data
			node_comment
			node_key
			node_value
			node_expanded
		);

%EXPORT_TAGS = (
	'node_keys' => [
		qw(
			node_parent
			node_pos
			node_prefix
			node_children
			node_name
			node_attribs
			node_namespaces
			node_text
			node_target
			node_data
			node_comment
			node_key
			node_value
			node_expanded
		), @EXPORT,
	],
);

my %DecodeDefaultEntity =
(
 '"' => "&quot;",
 ">" => "&gt;",
 "<" => "&lt;",
 "'" => "&apos;",
 "&" => "&amp;"
);

sub XMLescape {
    my ($str, $default) = @_;
    return undef unless defined $str;
	$default ||= '';
    
    $str =~ s/([\xC0-\xDF].|[\xE0-\xEF]..|[\xF0-\xFF]...)|([$default])|(]]>)/
	defined($1) ? XmlUtf8Decode ($1) : 
	defined ($2) ? $DecodeDefaultEntity{$2} : "]]&gt;" /egsx;

#?? could there be references that should not be expanded?
# e.g. should not replace &#nn; &#xAF; and &abc;
#    $str =~ s/&(?!($ReName|#[0-9]+|#x[0-9a-fA-F]+);)/&amp;/go;

    $str;
}

#
# Opposite of XmlUtf8Decode plus it adds prefix "&#" or "&#x" and suffix ";"
# The 2nd parameter ($hex) indicates whether the result is hex encoded or not.
#
sub XmlUtf8Decode
{
    my ($str, $hex) = @_;
    my $len = length ($str);
    my $n;

    if ($len == 2) {
		my @n = unpack "C2", $str;
		$n = (($n[0] & 0x3f) << 6) + ($n[1] & 0x3f);
    }
    elsif ($len == 3) {
		my @n = unpack "C3", $str;
		$n = (($n[0] & 0x1f) << 12) + (($n[1] & 0x3f) << 6) + 
			($n[2] & 0x3f);
    }
    elsif ($len == 4) {
		my @n = unpack "C4", $str;
		$n = (($n[0] & 0x0f) << 18) + (($n[1] & 0x3f) << 12) + 
			(($n[2] & 0x3f) << 6) + ($n[3] & 0x3f);
    }
    elsif ($len == 1) {	# just to be complete...
		$n = ord ($str);
    }
    else {
		die "bad value [$str] for XmlUtf8Decode";
    }
    $hex ? sprintf ("&#x%x;", $n) : "&#$n;";
}

sub new {
	my $class = shift;
	no strict 'refs';
	my $impl = $class . "Impl";
	my $this = $impl->new(@_);
	if ($XML::XPath::SafeMode) {
		return $this;
	}
	my $self = \$this;
	return bless $self, $class;
}

sub AUTOLOAD {
	my $method = $AUTOLOAD;
	$method =~ s/.*:://;
#	warn "AUTOLOAD $method!\n";
	no strict 'refs';
	*{$AUTOLOAD} = sub { 
		my $self = shift;
		my $obj = eval { $$self };
		if ($@) {
			if ($@ =~ /Not a SCALAR reference/) {
				croak("No such method $method in " . ref($self));
			}
			croak $@;
		}
		$obj->$method(@_);
	};
	goto &$AUTOLOAD;
}

package XML::XPath::NodeImpl;

use vars qw/@ISA $AUTOLOAD/;
@ISA = ('XML::XPath::Node');

sub getNodeType {
	my $self = shift;
	return XML::XPath::Node::UNKNOWN_NODE;
}

sub getNodeValue {
	my $self = shift;
	return;
}

sub getParentNode {
	my $self = shift;
	return $self->[XML::XPath::Node::node_parent];
}

sub getName { }
sub getValue { }
sub getData { }

sub getChildNodes {
	return wantarray ? () : [];
}

sub getChildNode {
	return;
}

sub getAttributeNodes {
	return wantarray ? () : [];
}

sub getNamespaceNodes {
	return wantarray ? () : [];
}

sub getLocalName {
	return;
}

sub string_value { return; }

sub get_pos {
	my $self = shift;
	return $self->[XML::XPath::Node::node_pos];
}

sub set_pos {
	my $self = shift;
	$self->[XML::XPath::Node::node_pos] = shift;
}

sub getPreviousSibling {
	my $self = shift;
	my $pos = $self->[XML::XPath::Node::node_pos];
	return unless $self->[XML::XPath::Node::node_parent];
	$self->[XML::XPath::Node::node_parent]->getChildNode($pos - 1);
}

sub getNextSibling {
	my $self = shift;
	my $pos = $self->[XML::XPath::Node::node_pos];
	return unless $self->[XML::XPath::Node::node_parent];
	$self->[XML::XPath::Node::node_parent]->getChildNode($pos + 1);
}

sub setParentNode {
	my $self = shift;
	my $parent = shift;
#	warn "SetParent of ", ref($self), " to ", $parent->[XML::XPath::Node::node_name], "\n";
	$self->[XML::XPath::Node::node_parent] = $parent;
}

sub del_parent_link {
	my $self = shift;
	$self->[XML::XPath::Node::node_parent] = undef;
}

sub dispose {
	my $self = shift;
	foreach my $kid ($self->getChildNodes) {
		$kid->dispose;
	}
	foreach my $kid ($self->getAttributeNodes) {
		$kid->dispose;
	}
	foreach my $kid ($self->getNamespaceNodes) {
		$kid->dispose;
	}
	$self->[XML::XPath::Node::node_parent] = undef;
}

sub to_sax {
	my $self = shift;
	unshift @_, 'Handler' if @_ == 1;
	my %handlers = @_;
	
    my $doch = $handlers{DocumentHandler} || $handlers{Handler};
    my $dtdh = $handlers{DTDHandler} || $handlers{Handler};
    my $enth = $handlers{EntityResolver} || $handlers{Handler};

    $self->_to_sax ($doch, $dtdh, $enth);
}

use Carp;

sub _to_sax {
	carp "_to_sax not implemented in ", ref($_[0]);
}

1;
__END__

=head1 NAME

XML::XPath::Node - internal representation of a node

=head1 API

The Node API aims to emulate DOM to some extent, however the API
isn't quite compatible with DOM. This is to ease transition from
XML::DOM programming to XML::XPath. Compatibility with DOM may
arise once XML::DOM gets namespace support.

=head2 new

Creates a new node. See the sub-classes for parameters to pass to new().

=head2 getNodeType

Returns one of ELEMENT_NODE, TEXT_NODE, COMMENT_NODE, ATTRIBUTE_NODE,
PROCESSING_INSTRUCTION_NODE or NAMESPACE_NODE. UNKNOWN_NODE is returned
if the sub-class doesn't implement getNodeType - but that means
something is broken! The constants are exported by default from
XML::XPath::Node. The constants have the same numeric value as the
XML::DOM versions.

=head2 getParentNode

Returns the parent of this node, or undef if this is the root node. Note
that the root node is the root node in terms of XPath - not the root
element node.

=head2 to_sax ( $handler | %handlers )

Generates sax calls to the handler or handlers. See the PerlSAX docs for
details (not yet implemented correctly).

=head1 MORE INFO

See the sub-classes for the meaning of the rest of the API:

=over 4

=item *

L<XML::XPath::Node::Element>

=item *

L<XML::XPath::Node::Attribute>

=item *

L<XML::XPath::Node::Namespace>

=item *

L<XML::XPath::Node::Text>

=item *

L<XML::XPath::Node::Comment>

=item *

L<XML::XPath::Node::PI>

=back

=cut
