# $Id: XPath.pm,v 1.29 2000/04/22 19:34:18 matt Exp $

package XML::XPath;

use strict;
use vars qw($VERSION $AUTOLOAD $revision);

$VERSION = '0.24';

$XML::XPath::Namespaces = 1;
$XML::XPath::Debug = 0;

use XML::XPath::XMLParser;
use XML::XPath::Parser;

# For testing
#use Data::Dumper;
#$Data::Dumper::Indent = 1;

# Parameters for new()
my @options = qw(
		filename
		parser
		xml
		ioref
		context
		);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my %args = @_;
	my %hash = map(( "_$_" => $args{$_} ), @options);
	my $self = bless \%hash, $class;
}

sub find {
	my $self = shift;
	my $path = shift;
	my $context = shift;
	die "No path to find" unless $path;
	
	if (!defined $context) {
		$context = $self->get_context;
	}
	if (!defined $context) {
		# Still no context? Need to parse...
		my $parser = XML::XPath::XMLParser->new(
				filename => $self->get_filename,
				xml => $self->get_xml,
				ioref => $self->get_ioref,
				parser => $self->get_parser,
				);
		$context = $parser->parse;
		$self->set_context($context);
#		warn "CONTEXT:\n", Data::Dumper->Dumpxs([$context], ['context']);
	}
	
	$self->{path_parser} ||= XML::XPath::Parser->new();
	my $parsed_path = $self->{path_parser}->parse($path);
	
#	warn "\n\nPATH: ", $parsed_path->as_string, "\n\n";
	
#	warn "evaluating path\n";
	return $parsed_path->evaluate($context);
}

sub findnodes {
	my $self = shift;
	my ($path, $context) = @_;
	
	my $results = $self->find($path, $context);
	
	if ($results->isa('XML::XPath::NodeSet')) {
		return $results->get_nodelist;
	}
	
	warn("findnodes returned a ", ref($results), " object\n") if $XML::XPath::Debug;
	return XML::XPath::NodeSet->new();
}

sub findnodes_as_string {
	my $self = shift;
	my ($path, $context) = @_;
	
	my $results = $self->find($path, $context);
	
	if ($results->isa('XML::XPath::NodeSet')) {
		return join('', map { XML::XPath::XMLParser::as_string($_) } $results->get_nodelist);
	}
	
	return $results->value;
}

sub findvalue {
	my $self = shift;
	my ($path, $context) = @_;
	
	my $results = $self->find($path, $context);
	
	if ($results->isa('XML::XPath::NodeSet')) {
		return $results->to_literal;
	}
	
	return $results;
}

sub cleanup {
	my $self = shift;
	my $context = $self->get_context;
	return unless $context;
	XML::XPath::XMLParser::dispose($context);
}

sub get_filename {
	my $self = shift;
	$self->{_filename};
}

sub set_filename {
	my $self = shift;
	$self->{_filename} = shift;
}

sub get_parser {
	my $self = shift;
	$self->{_parser};
}

sub set_parser {
	my $self = shift;
	$self->{_parser} = shift;
}

sub get_xml {
	my $self = shift;
	$self->{_xml};
}

sub set_xml {
	my $self = shift;
	$self->{_xml} = shift;
}

sub get_ioref {
	my $self = shift;
	$self->{_ioref};
}

sub set_ioref {
	my $self = shift;
	$self->{_ioref} = shift;
}

sub get_context {
	my $self = shift;
	$self->{_context};
}

sub set_context {
	my $self = shift;
	$self->{_context} = shift;
}

1;
__END__

=head1 NAME

XML::XPath - a set of modules for parsing and evaluating XPath statements

=head1 DESCRIPTION

This module aims to comply exactly to the XPath specification at
http://www.w3.org/TR/xpath and yet allow extensions to be added in the
form of functions. Modules such as XSLT and XPointer may need to do
this as they support functionality beyond XPath.

=head1 SYNOPSIS

	use XML::XPath;
	use XML::XPath::XMLParser;
	
	my $xp = XML::XPath->new(filename => 'test.xhtml');
	
	my $nodeset = $xp->find('/html/body/p'); # find all paragraphs
	
	foreach my $node ($nodeset->get_nodelist) {
		print "FOUND\n\n", 
			XML::XPath::XMLParser::as_string($node),
			"\n\n";
	}

=head1 DETAILS

There's an awful lot to all of this, so bear with it - if you stick it
out it should be worth it. Please get a good understanding of XPath
by reading the spec before asking me questions. All of the classes
and parts herein are named to be synonimous with the names in the
specification, so consult that if you don't understand why I'm doing
something in the code.

=head1 API

The API of XML::XPath itself is extremely simple to allow you to get
going almost immediately. The deeper API's are more complex, but you
shouldn't have to touch most of that.

=head2 new()

This constructor follows the often seen named parameter method call.
Parameters you can use are: filename, parser, xml, ioref and context.
The filename parameter specifies an XML file to parse. The xml
parameter specifies a string to parse, and the ioref parameter
specifies an ioref to parse. The context option allows you to 
specify a context node. The context node has to be in the format 
of a node as specified in L<XML::XPath::XMLParser>. The 4 parameters
filename, xml, ioref and context are mutually exclusive - you should
only specify one (if you specify anything other than context, the
context node is the root of your document).
The parser option allows you to pass in an already prepared 
XML::Parser object, to save you having to create more than one
in your application (if, for example, you're doing more than just XPath).

	my $xp = XML::XPath->new( context => $node );

It is very much recommended that you use only 1 XPath object throughout 
the life of your application. This is because the object (and it's sub-objects)
maintain certain bits of state information that will be useful (such
as XPath variables) to later calls to find(). It's also a good idea because
you'll use less memory this way.

=head2 I<nodeset> = find($path, [$context])

The find function takes an XPath expression (a string) and returns either an
XML::XPath::NodeSet object containing the nodes it found (or empty if
no nodes matched the path), or one of XML::XPath::Literal (a string),
XML::XPath::Number, or XML::XPath::Boolean. It should always return 
something - and you can use ->isa() to find out what it returned. If you
need to check how many nodes it found you should check $nodeset->size.
See L<XML::XPath::NodeSet>. An optional second parameter of a context
node allows you to use this method repeatedly, for example XSLT needs
to do this.

=head2 findnodes($path, [$context])

Returns a list of nodes found by $path, optionally in context $context.

=head2 findnodes_as_string($path, [$context])

Returns the nodes found reproduced as XML. The result is not guaranteed
to be valid XML though.

=head2 findvalue($path, [$context])

Returns either a C<XML::XPath::Literal>, a C<XML::XPath::Boolean> or a
C<XML::XPath::Number> object. If the path returns a NodeSet,
$nodeset->to_literal is called automatically for you (and thus a
C<XML::XPath::Literal is returned). Note that
for each of the objects stringification is overloaded, so you can just
print the value found, or manipulate it in the ways you would a normal
perl value (e.g. using regular expressions).

=head2 $XML::XPath::Namespaces

Set this to 0 if you I<don't> want namespace processing to occur. This
will make everything a little (tiny) bit faster, but you'll suffer for it,
probably.

=head1 IMPORTANT

The node format used by XML::XPath contains circular references. This
means that you have to manually delete those references once you're
done with the entire document tree (don't delete the circular
references on just part of a tree or you'll get yourself into all sorts
of trouble!). An example would be if you have a long-running process
(e.g. mod_perl) that uses this module. If you just did the following
(this is mod_perl specific, but you should get the idea):

  sub handler {
    my $r = shift;
    my $xp = XML::XPath->new( filename => $r->filename );
  
    my $nodes = $xp->find("//h1");
  
    foreach my $node ($nodes->get_nodelist) {
      print XML::XPath::XMLParser::as_string($node), "\n\n";
    }
  }

You would find your process size growing and growing. You have to
manually delete those circular references. It's not all bad though -
I've provided you with a cleanup method that you can use:

  sub handler {
    my $r = shift;
    my $xp = XML::XPath->new( filename => $r->filename );
  
    my $nodes = $xp->find("//h1");
  
    foreach my $node ($nodes->get_nodelist) {
      print XML::XPath::XMLParser::as_string($node), "\n\n";
    }
    $xp->cleanup();
  }

Beware that nodes are completely useless after they've been disposed
of.

=head1 Example

There are some complete XPath examples on http://xml.sergeant.org/xpath.xml

=head1 Support/Author

This module is copyright 2000 Fastnet Software Ltd. This is free
software, and as such comes with NO WARRANTY. No dates are used in this
module. You may distribute this module under the terms of either the
Gnu GPL,  or under specific licencing from Fastnet Software Ltd.
Special free licencing consideration will be given to similarly free
software. Please don't flame me for this licence - I've put a lot of
hours into this code, and if someone uses my software in their product
I expect them to have the courtesy to contact me first.

Full support for this module is available from Fastnet Software Ltd on
a pay per incident basis. Alternatively subscribe to the Perl-XML
mailing list by mailing lyris@activestate.com with the text: 

	SUBSCRIBE Perl-XML

in the body of the message. There are lots of friendly people on the
list, including myself, and we'll be glad to get you started.

Matt Sergeant, matt@sergeant.org
