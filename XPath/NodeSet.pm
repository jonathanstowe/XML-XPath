# $Id: NodeSet.pm,v 1.13 2000/08/24 16:22:58 matt Exp $

package XML::XPath::NodeSet;
use strict;

use XML::XPath::Boolean;

use overload 
		'""' => \&to_literal;

sub new {
	my $class = shift;
	bless [], $class;
}

sub sort {
    my $self = shift;
    @$self = sort { $a->get_global_pos <=> $b->get_global_pos } @$self;
    return $self;
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

sub string_value {
	my $self = shift;
	return '' unless @$self;
	return $self->[0]->string_value;
}

sub to_literal {
	my $self = shift;
	return XML::XPath::Literal->new(
			join('', map { $_->string_value } @$self)
			);
}

sub to_number {
	my $self = shift;
	return XML::XPath::Number->new(
			$self->to_literal
			);
}

1;
__END__

=head1 NAME

XML::XPath::NodeSet - a list of XML document nodes

=head1 DESCRIPTION

An XML::XPath::NodeSet object contains an ordered list of nodes. The nodes
each take the same format as described in L<XML::XPath::XMLParser>.

=head1 SYNOPSIS

	my $results = $xp->find('//someelement');
	if (!$results->isa('XML::XPath::NodeSet')) {
		print "Found $results\n";
		exit;
	}
	foreach my $context ($results->get_nodelist) {
		my $newresults = $xp->find('./other/element', $context);
		...
	}

=head1 API

=head2 new()

You will almost never have to create a new NodeSet object, as it is all
done for you by XPath.

=head2 get_nodelist()

Returns a list of nodes. See L<XML::XPath::XMLParser> for the format of
the nodes.

=head2 string_value()

Returns the string-value of the first node in the list.
See the XPath specification for what "string-value" means.

=head2 to_literal()

Returns the concatenation of all the string-values of all
the nodes in the list.

=head2 get_node($pos)

Returns the node at $pos. The node position in XPath is based at 1, not 0.

=head2 size()

Returns the number of nodes in the NodeSet.

=head2 pop()

Equivalent to perl's pop function.

=head2 push(@nodes)

Equivalent to perl's push function.

=head2 append($nodeset)

Given a nodeset, appends the list of nodes in $nodeset to the end of the
current list.

=head2 shift()

Equivalent to perl's shift function.

=head2 unshift(@nodes)

Equivalent to perl's unshift function.

=head2 prepend($nodeset)

Given a nodeset, prepends the list of nodes in $nodeset to the front of
the current list.

=cut
