# $Id: XMLParser.pm,v 1.44 2000/09/25 13:33:11 matt Exp $

package XML::XPath::XMLParser;

use strict;

use XML::Parser;
#use XML::XPath;
use XML::XPath::Node;
use XML::XPath::Node::Element;
use XML::XPath::Node::Text;
use XML::XPath::Node::Comment;
use XML::XPath::Node::PI;
use XML::XPath::Node::Attribute;
use XML::XPath::Node::Namespace;

my @options = qw(
        filename
        xml
        parser
        ioref
        );

my ($_current, $_namespaces_on);
my %IdNames;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = @_;
    my %hash = map(( "_$_" => $args{$_} ), @options);
    bless \%hash, $class;
}

sub parse {
    my $self = shift;
    
    %IdNames = ();
    $_current = $_namespaces_on = undef;
    
    $self->set_xml($_[0]) if $_[0];
    my $parser = $self->get_parser || XML::Parser->new(
            ErrorContext => 2,
            Namespaces => 1,
            ParseParamEnt => 1,
            );
    $parser->setHandlers(
            Init => \&parse_init,
            Char => \&parse_char,
            Start => \&parse_start,
            End => \&parse_end,
            Final => \&parse_final,
            Proc => \&parse_pi,
            Comment => \&parse_comment,
            Attlist => \&parse_attlist,
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

sub buildelement {
    my ($e, $current, $tag, $attribs) = @_;
    
#    local $^W; # ignore "Use of uninitialized value"... Oh for perl 5.6...
    
#    ($current, undef, undef, [], $tag);
#    $node[node_parent] = $current;
#    $node[node_name] = $tag;

    if (!$_namespaces_on && $XML::XPath::Namespaces && XML::Parser::Expat::current_ns_prefixes($e)) {
        $_namespaces_on = 1;
    }
    
    my $prefix;
    my (%exp_to_pre, %pre_to_exp);
    my @namespaces;

    if ($_namespaces_on) {

        my @prefixes = XML::Parser::Expat::current_ns_prefixes($e);
        push @prefixes, '#default' unless grep /^\#default$/, @prefixes;
        my @expanded = map {XML::Parser::Expat::expand_ns_prefix($e, $_)} @prefixes;
    #    warn "current namespaces: ", join(", ", @expanded), "\n";

        {
            local $^W;
            @exp_to_pre{@expanded} = @prefixes;
            %pre_to_exp = reverse %exp_to_pre;

            $prefix = $exp_to_pre{XML::Parser::Expat::namespace($e, $tag)}; # || '#default'};
            $prefix = '' if $prefix eq '#default';
        }

        while (my $pre = shift @prefixes) {
            my $newns = XML::XPath::Node::Namespace->new($pre, $pre_to_exp{$pre});
            push @namespaces, $newns;
        }
    }

    my $elname = $tag;    
    $tag = "$prefix:$tag" if $prefix;
    my $node = XML::XPath::Node::Element->new($tag, $prefix);
    
    while (@$attribs) {
        my ($key, $val) = (shift @$attribs, shift @$attribs);
        my $namespace = XML::Parser::Expat::namespace($e, $key);
#        warn "<$tag> $key 's namespace is '$namespace'\n";
        local $^W;
        my $prefix = $exp_to_pre{$namespace};
        my $name = $key; $name = "$prefix:$key" if $prefix;
        my $newattr = XML::XPath::Node::Attribute->new($name, $val, $prefix);
        $node->appendAttribute($newattr, 1);
        if (exists($IdNames{$elname}) && ($IdNames{$elname} eq $key)) {
#            warn "appending Id Element: $val for ", $node->getName, "\n";
            $e->{DOC_Node}->appendIdElement($val, $node);
        }
    }
    
    foreach my $ns (@namespaces) {
        $node->appendNamespace($ns);
    }

    return $node;
}

sub parse_init {
    my $e = shift;
    
    $_current = XML::XPath::Node::Element->new();
    $e->{DOC_Node} = $_current;
    $_namespaces_on = 0;
}

sub parse_final {
    my $e = shift;
    undef $_current;
    return $e->{DOC_Node};
}

sub parse_char {
    my $e = shift;
    my $text = shift;
    
    my $last = $_current->getLastChild;
    if ($last && $last->isTextNode) {
        # append to previous text node
        $last->appendText($text);
        return;
    }
    
    my $node = XML::XPath::Node::Text->new($text);
    $_current->appendChild($node, 1);
}

sub parse_start {
    my $e = shift;
    my $tag = shift;
    my $node = buildelement($e, $_current, $tag, \@_);
    $_current->appendChild($node, 1);
    $_current = $node;
}

sub parse_end {
    my $e = shift;
    $_current = $_current->getParentNode;
}

sub parse_pi {
    my $e = shift;
    my ($target, $data) = @_;
    my $node = XML::XPath::Node::PI->new($target, $data);
    $_current->appendChild($node, 1);
}

sub parse_comment {
    my $e = shift;
    my ($data) = @_;
    my $node = XML::XPath::Node::Comment->new($data);
    $_current->appendChild($node, 1);
}

sub parse_attlist {
    my $e = shift;
    my ($elname, $attname, $type, $default, $fixed) = @_;
    if ($type eq 'ID') {
        $IdNames{$elname} = $attname;
    }
}

sub as_string {
    my $node = shift;
    $node->toString;
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

=head1 NOTICES

This file is distributed as part of the XML::XPath module, and is copyright
2000 Fastnet Software Ltd. Please see the documentation for the module as a
whole for licencing information.
