# $Id: NodeSet.pm,v 1.6 2000/04/17 11:14:25 matt Exp $

package XML::XPath::NodeSet;
use strict;

use XML::XPath::Boolean;

use overload 
		'""' => \&to_literal;

sub new {
	my $class = shift;
	bless [], $class;
}

sub pop {
	my $self = shift;
	pop @$self;
}

sub push {
	my $self = shift;
	my (@nodes) = @_;
	push @$self, @nodes;
}

sub append {
	my $self = shift;
	my ($nodeset) = @_;
	push @$self, $nodeset->get_nodelist;
}

sub shift {
	my $self = shift;
	shift @$self;
}

sub unshift {
	my $self = shift;
	my (@nodes) = @_;
	unshift @$self, @nodes;
}

sub prepend {
	my $self = shift;
	my ($nodeset) = @_;
	unshift @$self, $nodeset->get_nodelist;
}

sub size {
	my $self = shift;
	scalar @$self;
}

sub get_node { # uses array index starting at 1, not 0
	my $self = shift;
	my ($pos) = @_;
	$self->[$pos - 1];
}

sub get_nodelist {
	my $self = shift;
	@$self;
}

sub to_boolean {
	my $self = shift;
	return (@$self > 0) ? XML::XPath::Boolean->True : XML::XPath::Boolean->False;
}

sub to_literal {
	my $self = shift;
	return XML::XPath::Literal->new(
			join('', map { XML::XPath::XMLParser::string_value($_) } @$self)
			);
}

sub to_number {
	my $self = shift;
	return XML::XPath::Number->new(
			$self->to_literal
			);
}

1;
