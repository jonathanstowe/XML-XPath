# $Id: Boolean.pm,v 1.3 2000/03/20 14:47:06 matt Exp $

package XML::XPath::Boolean;
use XML::XPath::Number;
use XML::XPath::Literal;
use strict;

use overload
		'""' => \&value;

sub True {
	my $class = shift;
	my $val = 1;
	bless \$val, $class;
}

sub False {
	my $class = shift;
	my $val = 0;
	bless \$val, $class;
}

sub value {
	my $self = shift;
	$$self;
}

sub to_number { XML::XPath::Number->new($_[0]->value); }
sub to_boolean { $_[0]; }
sub to_literal { XML::XPath::Literal->new($_[0]->value ? "true" : "false"); }

1;
