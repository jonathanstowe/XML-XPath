# $Id: XMLParser.pm,v 1.30 2000/04/20 09:12:13 matt Exp $

package XML::XPath::XMLParser;

use vars qw/$VERSION @ISA @EXPORT/;
use strict;

use XML::Parser;

require Exporter;

@ISA = ('Exporter');

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
		node_parent
		node_pos
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

my ($_current, $_namespaces_on);

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
		return $parser->parse($self->get_xml || $self->get_ioref);
	}
}

sub parsefile {
	my $self = shift;
	my ($filename) = @_;
	$self->set_filename($filename);
	$self->parse;
}

sub mkattrib {
	my ($parent, $key, $val, $prefix) = @_;
	return bless([$parent, undef, $prefix, $key, $val], 'attribute');
}

sub mkelement {
	my ($parent, $tag) = @_;
	return bless([$parent, undef, undef, [], $tag], 'element');
}

sub mknamespace {
	my ($parent, $prefix, $expanded) = @_;
	return bless([$parent, undef, $prefix, $expanded], 'namespace');
}

sub buildelement {
	my ($e, $current, $tag, $attribs) = @_;
	
#	local $^W; # ignore "Use of uninitialized value"... Oh for perl 5.6...
	
	my $node = mkelement($current, $tag);
	
#	($current, undef, undef, [], $tag);
#	$node[node_parent] = $current;
#	$node[node_name] = $tag;

	if ($XML::XPath::Namespaces && !$_namespaces_on && XML::Parser::Expat::namespace($e, $tag)) {
		$_namespaces_on = 1;
	}
	
	goto SKIP_NS unless $_namespaces_on;
	
	my @prefixes = XML::Parser::Expat::current_ns_prefixes($e);
	push @prefixes, '#default' unless grep /^\#default$/, @prefixes;
	my @expanded = map {XML::Parser::Expat::expand_ns_prefix($e, $_)} @prefixes;
	
	my (%exp_to_pre, %pre_to_exp);
	
	@exp_to_pre{@expanded} = @prefixes;
	@pre_to_exp{@prefixes} = @expanded;
	
	my $prefix = $exp_to_pre{XML::Parser::Expat::namespace($e, $tag) || '#default'};
	undef $prefix if $prefix eq '#default';
	$node->[node_name] = $prefix ? "$prefix:$tag" : $tag;
	$node->[node_prefix] = $prefix;
	
	while (@prefixes) {
		my $pre = shift @prefixes;
		my $newns = mknamespace($node, $pre, $pre_to_exp{$pre});
		push @{$node->[node_namespaces]}, $newns;
		$newns->[node_pos] = $#{$node->[node_namespaces]};
	}
	
SKIP_NS:
	
	while (@$attribs) {
		my ($key, $val) = (shift @$attribs, shift @$attribs);
		my $namespace = XML::Parser::Expat::namespace($e, $key) || "#default";
		my $newattr = mkattrib($node, $key, $val, $exp_to_pre{$namespace});
		push @{$node->[node_attribs]}, $newattr;
		$newattr->[node_pos] = $#{$node->[node_attribs]};
	}

	return $node;
}

sub parse_init {
	my $e = shift;
	
	$_current = bless [], 'element';
	$_namespaces_on = 0;
}

sub parse_final {
	my $e = shift;
	my $result = $_current;
	undef $_current;
	return $result;
}

sub mktext {
	my ($parent, $text) = @_;
	return bless ([$parent, undef, $text], 'text');
}

sub parse_char {
	my $e = shift;
	my $text = shift;
	
	if (@{$_current->[node_children]} > 0 && ref $_current->[node_children][-1] eq 'text') {
		# append to previous text node
		$_current->[node_children][-1][node_text] .= $text;
		return;
	}
	
	my $node = mktext($_current, $text);
	push @{$_current->[node_children]}, $node;
	$node->[node_pos] = $#{$_current->[node_children]};
}

sub parse_start {
	my $e = shift;
	my $tag = shift;
	my $node = buildelement($e, $_current, $tag, \@_);
	push @{$_current->[node_children]}, $node;
	$node->[node_pos] = $#{$_current->[node_children]};
	$_current = $node;
}

sub parse_end {
	my $e = shift;
	$_current = $_current->[node_parent];
}

sub mkpi {
	my ($parent, $target, $data) = @_;
	return bless([$parent, undef, $target, $data], 'pi');
}

sub parse_pi {
	my $e = shift;
	my ($target, $data) = @_;
	my $node = mkpi($_current, $target, $data);
	push @{$_current->[node_children]}, $node;
	$node->[node_pos] = $#{$_current->[node_children]};
}

sub mkcomment {
	my ($parent, $data) = @_;
	return bless([$parent, undef, $data], 'comment');
}

sub parse_comment {
	my $e = shift;
	my ($data) = @_;
	my $node = mkcomment($_current, $data);
	push @{$_current->[node_children]}, $node;
	$node->[node_pos] = $#{$_current->[node_children]};
}

sub as_string {
	my $node = shift;
	my $string;
	if (ref $node eq 'element' && $node->[node_parent]) {
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

		if (!$node->[node_parent]->[node_parent]) {
			$string .= "\n";
		}
	}
	elsif (ref $node eq 'text') {
		$string .= XML::Parser::Expat->xml_escape($node->[node_text]);
	}
	elsif (ref $node eq 'comment') {
		$string .= '<!--' . $node->[node_comment] . '-->';
		if (!$node->[node_parent]->[node_parent]) {
			$string .= "\n";
		}
	}
	elsif (ref $node eq 'pi') {
		$string .= "<?" . $node->[node_target] . " " . XML::Parser::Expat->xml_escape($node->[node_data]) . "?>";
		if (!$node->[node_parent]->[node_parent]) {
			$string .= "\n";
		}
	}
	elsif (ref $node eq 'namespace') {
		return '' unless defined $node->[node_expanded];
		if ($node->[node_prefix] eq '#default') {
			$string .= ' xmlns="';
		}
		else {
			$string .= ' xmlns:' . $node->[node_prefix] . '="';
		}
		$string .= XML::Parser::Expat->xml_escape($node->[node_expanded]);
		$string .= '"';
	}
	elsif (ref $node eq 'attribute') {
		$string .= ' ';
		if ($node->[node_prefix]) {
			$string .= ' ' . $node->[node_prefix] . ':';
		}
		$string .= join('', 
					$node->[node_key], '="',
					XML::Parser::Expat->xml_escape($node->[node_value], '"'),
					'"');
	}
	elsif (ref $node eq 'element') {
		# just do kids for root node
		foreach my $kid (@{$node->[node_children]}) {
			$string .= as_string($kid);
		}
	}
	else {
		die "Unknown node type : ", ref($node);
	}
	return $string;
}

sub expanded_name {
	my $node = shift;
	# I got this from 4XPath (python, ugh!), but I think it's wrong :)
	if (ref($node) eq 'element') {
		return $node->[node_name];
	}
	elsif (ref($node) eq 'text') {
		# This is a guess - the spec leave it undefined.
		return '';
	}
	elsif (ref($node) eq 'comment') {
		return '';
	}
	elsif (ref($node) eq 'attribute') {
		return $node->[node_key];
	}
	elsif (ref($node) eq 'namespace') {
		return '';
	}
	elsif (ref($node) eq 'pi') {
		# This is a guess - the spec leaves it undefined.
		return $node->[node_target];
	}
}

sub string_value {
	my $node = shift;
	if (ref($node) eq 'element') {
		return _element_string_value($node);
	}
	elsif (ref($node) eq 'text') {
		# This is a guess - the spec leave it undefined.
		return $node->[node_text];
	}
	elsif (ref($node) eq 'comment') {
		return $node->[node_comment];
	}
	elsif (ref($node) eq 'attribute') {
		return $node->[node_value];
	}
	elsif (ref($node) eq 'namespace') {
		return $node->[node_expanded];
	}
	elsif (ref($node) eq 'pi') {
		# This is a guess - the spec leaves it undefined.
		return $node->[node_data];
	}
}

sub _element_string_value {
	my $node = shift;
	my $string;
	foreach my $kid (@{$node->[node_children]}) {
		if (ref $kid eq 'element') {
			$string .= _element_string_value($kid);
		}
		elsif (ref $kid eq 'text') {
			$string .= $kid->[node_text];
		}
	}
	return $string;
}

sub dispose {
	my $node = shift;
	if (ref($node) eq 'element' && $node->[node_parent]) {
		foreach my $attr (@{$node->[node_attribs]}) {
			undef $attr->[node_parent];
		}
		undef $node->[node_attribs];
		foreach my $ns (@{$node->[node_namespaces]}) {
			undef $ns->[node_parent];
		}
		undef $node->[node_attribs];
		foreach my $kid (@{$node->[node_children]}) {
			dispose($kid);
		}
		undef $node->[node_children];
	}
	elsif (ref($node) eq 'element') {
		# root node
		foreach my $kid (@{$node->[node_children]}) {
			dispose($kid);
		}
	}
	undef $node->[node_parent];
}

sub get_parser { shift->{_parser}; }
sub get_filename { shift->{_filename}; }
sub get_xml { shift->{_xml}; }
sub get_ioref { shift->{_ioref}; }

sub set_parser { $_[0]->{_parser} = $_[1]; }
sub set_filename { $_[0]->{_filename} = $_[1]; }
sub set_xml { $_[0]->{_xml} = $_[1]; }
sub set_ioref { $_[0]->{_ioref} = $_[1]; }

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

All nodes have the same first 2 entries in the array: node_parent
and node_pos. The type of the node is determined using the ref() function.
The node_parent always contains an entry for the parent of the current
node - except for the root node which has undef in there. And node_pos is the
position of this node in the array that it is in (think: 
$node == $node->[node_parent]->[node_children]->[$node->[node_pos]] )

Nodes are structured as follows:

=head2 Root Node

The root node is just an element node with no parent.

	[
	  undef, # node_parent - check for undef to identify root node
	  undef, # node_pos
	  undef, # node_prefix
	  [ ... ], # node_children (see below)
	]

=head2 Element Node

	[
	  $parent, # node_parent
	  <position in current array>, # node_pos
	  'xxx', # node_prefix - namespace prefix on this element
	  [ ... ], # node_children
	  'yyy', # node_name - element tag name
	  [ ... ], # node_attribs - attributes on this element
	  [ ... ], # node_namespaces - namespaces currently in scope
	]

=head2 Attribute Node

	[
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

	[
	  $parent,
	  <pos>,
	  'a', # node_prefix - the namespace as it was written as a prefix
	  'http://my.namespace.com', # node_expanded - the expanded name.
	]

=head2 Text Nodes

	[
	  $parent,
	  <pos>,
	  'This is some text' # node_text - the text in the node
	]

=head2 Comment Nodes

	[
	  $parent,
	  <pos>,
	  'This is a comment' # node_comment
	]

=head2 Processing Instruction Nodes

	[
	  $parent,
	  <pos>,
	  'target', # node_target
	  'data', # node_data
	]

=head1 Usage

If you feel the need to use this module outside of XML::XPath (for example
you might use this module directly so that you can cache parsed trees), you
can follow the following API:

=head2 new

The new method takes either no parameters, or any of the following parameters:

		filename
		xml
		parser
		ioref

This uses the familiar hash syntax, so an example might be:

	use XML::XPath::XMLParser;
	
	my $parser = XML::XPath::XMLParser->new(filename => 'example.xml');

The parameters represent a filename, a string containing XML, an XML::Parser
instance and an open filehandle ref respectively. You can also set or get all
of these properties using the get_ and set_ functions that have the same
name as the property: e.g. get_filename, set_ioref, etc.

=head2 parse

The parse method generally takes no parameters, however you are free to
pass either an open filehandle reference or an XML string if you so require.
The return value is a tree that XML::XPath can use. The parse method will
die if there is an error in your XML, so be sure to use perl's exception
handling mechanism (eval{};) if you want to avoid this.

=head2 parsefile

The parsefile method is identical to parse() except it expects a single
parameter that is a string naming a file to open and parse. Again it
returns a tree and also dies if there are XML errors.

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

=head2 dispose($node)

This is a B<vitally> important function. If you're building an application
that uses XML::XPath::XMLParser more than once (i.e. you're retrieving more
than one tree) then you must dispose of your nodes using this method if
you don't want them to continue to use memory in your system. This is because
of Perl's crappy garbage collection system (refcounting) and the circular
references in the node structure:

	XML::XPath::XMLParser::dispose($node);

This method isn't exported and I don't intend it to ever be that way - I hate
exporting methods (I make exceptions for the node_ constants in this file).

=head2 mk*

The mk* functions construct nodes for you, should you need to do that outside
of XML::XPath. The do not add nodes to the right place in the parent, you
have to do that manually after constructing the node (this is subject to change).
Neither do they set the node_pos value.

=over 4

=item mkelement($parent, $tag) - Constructs an element node.

=item mkattrib($parent, $key, $value, $prefix) - Constructs an attribute node. $prefix
is the namespace prefix. $parent must be the element node. Does not add the
attribute to the element's list of attributes.

=item mknamespace($parent, $prefix, $expanded) - Constructs a namespace node.

=item mkcomment($parent, $text) - Constructs a comment node

=item mktext($parent, $text) - Constructs a text node

=item mkpi($parent, $target, $data) - Constructs a processing instruction node.

=back

=head1 NOTICES

This file is distributed as part of the XML::XPath module, and is copyright
2000 Fastnet Software Ltd. Please see the documentation for the module as a
whole for licencing information.
