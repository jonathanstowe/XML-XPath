# $Id: Literal.pm,v 1.6 2000/03/20 14:46:29 matt Exp $

package XML::XPath::Literal;
use XML::XPath::Boolean;
use XML::XPath::Number;
use strict;

use overload 
		'""' => \&value,
		'cmp' => \&cmp;

sub new {
	my $class = shift;
	my ($string) = @_;
	
	$string =~ s/&quot;/"/g;
	$string =~ s/&apos;/'/g;
	
	bless \$string, $class;
}

sub as_string {
	my $self = shift;
	my $string = $$self;
	$string =~ s/'/&apos;/g;
	return "'$string'";
}

sub value {
	my $self = shift;
	$$self;
}

sub cmp {
	my $self = shift;
	my ($cmp) = @_;
	$$self cmp $cmp;
}

sub evaluate {
	my $self = shift;
	$self;
}

sub to_boolean {
	my $self = shift;
	return (length($$self) > 0) ? XML::XPath::Boolean->True : XML::XPath::Boolean->False;
}

sub to_number { XML::XPath::Number->new($_[0]->value); }
sub to_literal { $_[0]; }

1;
