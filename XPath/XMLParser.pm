# $Id: XMLParser.pm,v 1.16 2000/01/26 20:14:28 matt Exp $

package XML::XPath::XMLParser;

use vars qw/$AUTOLOAD $VERSION @ISA @EXPORT/;
use strict;

use XML::Parser;

require Exporter;

@ISA = ('Exporter');

# All
sub node_type () { 0; }
sub node_parent () { 1; }
sub node_pos () { 2; }

# Element
sub node_prefix () { 3; }
sub node_children () { 4; }
sub node_name () { 5; }
sub node_attribs () { 6; }
sub node_namespaces () { 7; }

# Char
sub node_text () { 3; }

# PI
sub node_target () { 3; }
sub node_data () { 4; }

# Comment
sub node_comment () { 3; }

# Attribute
# sub node_prefix () { 3; }
sub node_key () { 4; }
sub node_value () { 5; }

# Namespaces
# sub node_prefix () { 3; }
sub node_expanded () { 4; }

@EXPORT = qw(
		node_type
		node_parent
		node_pos
		node_global_pos
		node_name
		node_attribs
		node_namespaces
		node_children
		node_text
		node_target
		node_data
		node_comment
		node_prefix
		node_key
		node_value
		node_expanded
		);

my @options = qw(
		filename
		xml
		parser
		ioref
		);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my %args = @_;
	my %hash = map(( "_$_" => $args{$_} ), @options);
	bless \%hash, $class;
}

sub parse {
	my $self = shift;
	$self->set_xml($_[0]) if $_[0];
	my $parser = $self->get_parser || XML::Parser->new(
			ErrorContext=>2,
			Namespaces=>1
			);
	$parser->setHandlers(
			Init => \&parse_init,
			Char => \&parse_char,
			Start => \&parse_start,
			End => \&parse_end,
			Final => \&parse_final,
			Proc => \&parse_pi,
			Comment => \&parse_comment,
			);
	my $toparse;
	if ($toparse = $self->get_filename) {
		return $parser->parsefile($toparse);
	}
	else {
		return $parser->parsefile($self->get_xml || $self->get_ioref);
	}
}

sub parsefile {
	my $self = shift;
	$self->set_filename($_[0]);
	$self->parse;
}

sub mkelement {
	my ($e, $current, $tag, $attribs) = @_;
	
	my @prefixes = $e->current_ns_prefixes();
	push @prefixes, '#default' unless grep /^\#default$/, @prefixes;
	my @expanded = map {$e->expand_ns_prefix($_)} @prefixes;
	
	my (%exp_to_pre, %pre_to_exp);
	
	@exp_to_pre{@expanded} = @prefixes;
	@pre_to_exp{@prefixes} = @expanded;
	
	my $node;
	$node->[node_type] = 'element';
	$node->[node_parent] = $current;
	my $prefix = $exp_to_pre{$e->namespace($tag) || '#default'};
	undef $prefix if $prefix eq '#default';
	$node->[node_name] = $prefix ? "$prefix:$tag" : $tag;
	$node->[node_attribs] = [];

	while (@$attribs) {
		my ($key, $val) = (shift @$attribs, shift @$attribs);
		my $namespace = $e->namespace($key) || "#default";
		my $newattr;
		$newattr->[node_type] = 'attribute';
		$newattr->[node_parent] = $node;
		$newattr->[node_pos] = $#{$node->[node_attribs]};
		$newattr->[node_key] = $key;
		$newattr->[node_value] = $val;
		$newattr->[node_prefix] = $exp_to_pre{$namespace};
		push @{$node->[node_attribs]}, $newattr;
	}

	$node->[node_namespaces] = [];
	
	while (@prefixes) {
		my $pre = shift @prefixes;
		my $newns;
		$newns->[node_type] = 'namespace';
		$newns->[node_parent] = $node;
		$newns->[node_pos] = $#{$node->[node_namespaces]};
		$newns->[node_prefix] = $pre;
		$newns->[node_expanded] = $pre_to_exp{$pre};
		push @{$node->[node_namespaces]}, $newns;
	}
	
	$node->[node_children] = [];
	
	return $node;
}

sub parse_init {
	my $e = shift;
}

sub parse_char {
	my $e = shift;
	my $text = shift;
	my $node;
	$node->[node_type] = 'text';
	$node->[node_parent] = $e->{Current};
	$node->[node_text] = $text;
	push @{$e->{Current}->[node_children]}, $node;
	$node->[node_pos] = $#{$e->{Current}->[node_children]};
}

sub parse_start {
	my $e = shift;
	my $tag = shift;
	my $node = mkelement($e, $e->{Current}, $tag, \@_);
	push @{$e->{Current}->[node_children]}, $node;
	$node->[node_pos] = $#{$e->{Current}->[node_children]};
	$e->{Current} = $node;
}

sub parse_end {
	my $e = shift;
	$e->{Current} = $e->{Current}->[node_parent] if $e->{Current}->[node_parent];
}

sub parse_final {
	my $e = shift;
	my $root;
	$root->[node_type] = 'element';
	$root->[node_children] = [$e->{Current}];
	$e->{Current}->[node_parent] = $root;
	return $root;
}

sub parse_pi {
	my $e = shift;
	my ($target, $data) = @_;
	my $node;
	$node->[node_parent] = $e->{Current};
	$node->[node_type] = 'pi';
	$node->[node_target] = $target;
	$node->[node_data] = $data;
	push @{$e->{Current}->[node_children]}, $node;
	$node->[node_pos] = $#{$e->{Current}->[node_children]};
}

sub parse_comment {
	my $e = shift;
	my ($data) = @_;
	my $node;
	$node->[node_parent] = $e->{Current};
	$node->[node_type] = 'comment';
	$node->[node_comment] = $data;
	push @{$e->{Current}->[node_children]}, $node;
	$node->[node_pos] = $#{$e->{Current}->[node_children]};
}

sub as_string {
	my $node = shift;
	my $string;
	if ($node->[node_type] eq 'element' && $node->[node_parent]) {
		$string .= "<" . $node->[node_name];
		
		foreach my $ns (@{$node->[node_namespaces]}) {
			$string .= as_string($ns);
		}
		
		foreach my $attr (@{$node->[node_attribs]}) {
			$string .= as_string($attr);
		}

		$string .= ">";

		# do kids
		foreach my $kid (@{$node->[node_children]}) {
			$string .= as_string($kid);
		}
		$string .= "</" . $node->[node_name] . ">";
	}
	elsif ($node->[node_type] eq 'text') {
		$string .= XML::Parser::Expat->xml_escape($node->[node_text]);
	}
	elsif ($node->[node_type] eq 'comment') {
		$string .= '<!--' . $node->[node_comment] . '-->';
	}
	elsif ($node->[node_type] eq 'pi') {
		$string .= "<?" . $node->[node_target] . " " . XML::Parser::Expat->xml_escape($node->[node_data]) . "?>";
	}
	elsif ($node->[node_type] eq 'namespace') {
		if ($node->[node_prefix] eq '#default') {
			$string .= ' xmlns="';
		}
		else {
			$string .= ' xmlns:' . $node->[node_prefix] . '="';
		}
		$string .= XML::Parser::Expat->xml_escape($node->[node_expanded]);
		$string .= '"';
	}
	elsif ($node->[node_type] eq 'attribute') {
		if ($node->[node_prefix]) {
			$string .= ' ' . $node->[node_prefix] . ':';
		}
		$string .= join('', 
					$node->[node_key], '="',
					XML::Parser::Expat->xml_escape($node->[node_value], '"'),
					'"');
	}
	elsif ($node->[node_type] eq 'element') {
		# just do kids for root node
		foreach my $kid (@{$node->[node_children]}) {
			$string .= as_string($kid);
		}
	}
	else {
		die "Unknown node type";
	}
	return $string;
}

sub string_value {
	my $node = shift;
	if ($node->[node_type] eq 'element') {
		return _element_string_value($node);
	}
	elsif ($node->[node_type] eq 'text') {
		# This is a guess - the spec leave it undefined.
		return $node->[node_text];
	}
	elsif ($node->[node_type] eq 'comment') {
		return $node->[node_comment];
	}
	elsif ($node->[node_type] eq 'attribute') {
		return $node->[node_value];
	}
	elsif ($node->[node_type] eq 'namespace') {
		return $node->[node_expanded];
	}
	elsif ($node->[node_type] eq 'pi') {
		# This is a guess - the spec leaves it undefined.
		return $node->[node_data];
	}
}

sub _element_string_value {
	my $node = shift;
	my $string;
	foreach my $kid (@{$node->[node_children]}) {
		if ($kid->[node_type] eq 'element') {
			$string .= _element_string_value($kid);
		}
		elsif ($kid->[node_type] eq 'text') {
			$string .= $kid->[node_text];
		}
	}
	return $string;
}

sub AUTOLOAD {
	my $self = shift;
	no strict 'refs';
	if ($AUTOLOAD =~ /.*::get(_\w+)/) {
		my $attrib = $1;
		if (exists $self->{$attrib}) {
			*{$AUTOLOAD} = sub { return $_[0]->{$attrib}; };
			return $self->{$attrib};
		}
		else {
			die "No such method $AUTOLOAD";
		}
	}
	if ($AUTOLOAD =~ /.*::set(_\w+)/) {
		my $attrib = $1;
		if (exists $self->{$attrib}) {
			*{$AUTOLOAD} = sub { return $_[0]->{$attrib} = $_[1]; };
			return $self->{$attrib} = $_[0];
		}
		else {
			die "No such method $AUTOLOAD";
		}
	}
	die "No such method $AUTOLOAD";
}

1;

__END__

=head1 NAME

XML::XPath::XMLParser - The default XML parsing class that produces a node tree

=head1 SYNOPSIS

	my $parser = XML::XPath::XMLParser->new(
				filename => $self->get_filename,
				xml => $self->get_xml,
				ioref => $self->get_ioref,
				parser => $self->get_parser,
			);
	my $root_node = $parser->parse;

=head1 DESCRIPTION

This module generates a node tree for use as the context node for XPath processing.
It aims to be a quick parser, nothing fancy, and yet has to store more information
than most parsers. To achieve this I've used array refs everywhere - no hashes.
I don't have any performance figures for the speedups achieved, so I make no
appologies for anyone not used to using arrays instead of hashes. I think they
make good sense here where we know the attributes of each type of node.

=head1 Node Structure

All nodes have the same first 3 entries in the array: node_type, node_parent
and node_pos. The node_type entry contains a string saying what type the current
node is. The node_parent always contains an entry for the parent of the current
node - except for the root node which has undef in there. And node_pos is the
position of this node in the array that it is in (think: 
$node == $node->[node_parent]->[node_children]->[$node->[node_pos]] )

Nodes are structured as follows:

=head2 Root Node

The root node is just an element node with no parent.

	[ 'element', # node_type
	  undef, # node_parent - check for undef to identify root node
	  undef, # node_pos
	  undef, # node_prefix
	  [ ... ], # node_children (see below)
	]

=head2 Element Node

	[ 'element', # node_type
	  $parent, # node_parent
	  <position in current array>, # node_pos
	  'xxx', # node_prefix - namespace prefix on this element
	  [ ... ], # node_children
	  'yyy', # node_name - element name
	  [ ... ], # node_attribs - attributes on this element
	  [ ... ], # node_namespaces - namespaces currently in scope
	]

=head2 Attribute Node

	[ 'attribute', # node_type
	  $parent, # node_parent - the element node
	  <position in current array>, # node_pos
	  'xxx', # node_prefix - namespace prefix on this element
	  'href', # node_key - attribute name
	  'ftp://ftp.com/', # node_value - value in the node
	]

=head2 Namespace Nodes

Each element has an associated set of namespace nodes that are currently
in scope. Each namespace node stores a prefix and the expanded name (retrieved
from the xmlns:prefix="..." attribute).

	[ 'namespace',
	  $parent,
	  <pos>,
	  'a', # node_prefix - the namespace as it was written as a prefix
	  'http://my.namespace.com', # node_expanded - the expanded name.
	]

=head2 Text Nodes

	[ 'text',
	  $parent,
	  <pos>,
	  'This is some text' # node_text - the text in the node
	]

=head2 Comment Nodes

	[ 'comment',
	  $parent,
	  <pos>,
	  'This is a comment' # node_comment
	]

=head2 Processing Instruction Nodes

	[ 'pi',
	  $parent,
	  <pos>,
	  'target', # node_target
	  'data', # node_data
	]

=head1 Functions

There are a couple of utility function in here, located here because this is
where specific knowledge of the node structure is.

=head2 as_string($node)

When passed a node this will correctly dump out XML that corresponds to that
node. (actually that's not strictly true - if you pass it anything other than
an element node then it won't be proper XML at all). It should do all the
appropriate escaping, etc.

=head2 string_value($node)

This returns the "string-value" of a node, as per the spec. It probably doesn't
need to be used by anyone except people developing XPath routines.

=head1 NOTICES

This file is distributed as part of the XML::XPath module, and is copyright
2000 Fastnet Software Ltd. Please see the documentation for the module as a
whole for licencing information.
