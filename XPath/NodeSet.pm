# $Id: NodeSet.pm,v 1.3 2000/01/23 17:41:58 matt Exp $

package XML::XPath::NodeSet;
use strict;

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
	return (@$self > 0);
}

1;
