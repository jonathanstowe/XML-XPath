# $Id: Number.pm,v 1.7 2000/03/20 14:55:28 matt Exp $

package XML::XPath::Number;
use XML::XPath::Boolean;
use XML::XPath::Literal;
use strict;

use overload
		'""' => \&value;

sub new {
	my $class = shift;
	my $number = shift;
	if ($number !~ /^\s*(\d+(\.\d*)?|\.\d+)\s*$/) {
		$number = undef;
	}
	else {
		$number =~ s/^\s*(.*)\s*$/$1/;
	}
	bless \$number, $class;
}

sub as_string {
	my $self = shift;
	defined $$self ? $$self : 'NaN';
}

sub value {
	my $self = shift;
	$$self;
}

sub evaluate {
	my $self = shift;
	$self;
}

sub to_boolean {
	my $self = shift;
	return $$self ? XML::XPath::Boolean->True : XML::XPath::Boolean->False;
}

sub to_literal { XML::XPath::Literal->new($_[0]->as_string); }
sub to_number { $_[0]; }

1;
