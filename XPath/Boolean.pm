# $Id: Boolean.pm,v 1.4 2000/04/20 09:12:13 matt Exp $

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
__END__

=head1 NAME

XML::XPath::Boolean - Boolean true/false values

=head1 DESCRIPTION

XML::XPath::Boolean objects implement simple boolean true/false objects.

=head1 API

=head2 XML::XPath::Boolean->True

Creates a new Boolean object with a true value.

=head2 XML::XPath::Boolean->False

Creates a new Boolean object with a false value.

=head2 value()

Returns true or false.

=head2 to_literal()

Returns the string "true" or "false".

=cut
