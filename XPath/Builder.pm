# $Id: Builder.pm,v 1.8 2000/11/29 17:23:10 matt Exp $

package XML::XPath::Builder;

use strict;

# to get array index constants
use XML::XPath::Node;
use XML::XPath::Node::Element;
use XML::XPath::Node::Attribute;
use XML::XPath::Node::Namespace;
use XML::XPath::Node::Text;
use XML::XPath::Node::PI;
use XML::XPath::Node::Comment;

sub new {
	my $class = shift;
	my $self = ($#_ == 0) ? { %{ (shift) } } : { @_ };

        XML::XPath::Node->Pos;
        
	bless $self, $class;
}


sub mkelement {
	my ($self, $element) = @_;

	my $node = XML::XPath::Node::Element->new($element->{Data}{Name}, '#default');

        my $attribs = $element->{Data}{Attribs};
	for my $attr (keys %$attribs) {
		my $newattr = XML::XPath::Node::Attribute->new($attr, $attribs->{$attr});
		$node->appendAttribute($newattr, 1);
	}
	
	return $node;
}

sub start_document {
	my $self = shift;
	$self->{Current} = XML::XPath::Node::Element->new();
	$self->{Root} = $self->{Current};
}

sub end_document {
	my $self = shift;
	
	delete $self->{Current};
	return $self->{Root};
}

sub characters {
	my $self = shift;
	my $characters = shift;
	
	my @kids = $self->{Current}->getChildNodes;
	if (@kids && $kids[-1]->getNodeType == TEXT_NODE) {
		$kids[-1]->appendText($characters->{Data});
	}
	else {
		my $node = XML::XPath::Node::Text->new($characters->{Data});
		$self->{Current}->appendChild($node, 1);
	}
}

sub start_element {
	my $self = shift;
	my $element = shift;
	my $node = mkelement($self, $element);
	$self->{Current}->appendChild($node, 1);
	$self->{Current} = $node;
}

sub end_element {
	my $self = shift;
	$self->{Last} = $self->{Current};
	$self->{Current} = $self->{Current}->getParentNode;
}

sub processing_instruction {
	my $self = shift;
	my $pi = shift;
	my $node = XML::XPath::Node::PI->new($pi->{Target}, $pi->{Data});
	$self->{Current}->appendChild($node, 1);
}

sub comment {
	my $self = shift;
	my $comment = shift;
	my $node = XML::XPath::Node::Comment->new($comment->{Data});
	$self->{Current}->appendChild($node, 1);
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
