# $Id: Variable.pm,v 1.3 2000/01/23 16:26:40 matt Exp $

package XML::XPath::Variable;
use strict;

# This class does NOT contain 1 instance of a variable
# see the XML::XPath::Parser class for the instances
# This class simply holds the name of the var

sub new {
	my $class = shift;
	my ($pp, $name) = @_;
	bless { name => $name, path_parser => $pp }, $class;
}

sub as_string {
	my $self = shift;
	"\$" . $self->{name};
}

sub get_value {
	my $self = shift;
	$self->{path_parser}->get_var($self->{name});
}

sub set_value {
	my $self = shift;
	my ($val) = @_;
	$self->{path_parser}->set_var($self->{name}, $val);
}

sub evaluate {
	my $self = shift;
	$self->get_value;
}

1;
