# $Id: Step.pm,v 1.11 2000/02/14 10:53:15 matt Exp $

package XML::XPath::Step;
use XML::XPath::XMLParser;
use XML::XPath::Parser;
use strict;

sub new {
	my $class = shift;
	my ($pp, $axis, $test, $literal) = @_;
	
	my $self = {
		pp => $pp, # the XML::XPath::Parser class
		axis => $axis,
		test => $test,
		literal => $literal,
		predicates => [],
		};
	bless $self, $class;
}

sub as_string {
	my $self = shift;
	my $string = $self->{axis} . "::";

	if ($self->{test} eq 'processing-instruction') {
		$string .= $self->{test} . "(";
		if ($self->{literal}->value) {
			$string .= $self->{literal}->as_string;
		}
		$string .= ")";
	}
	elsif ($self->{test} eq 'id') {
		$string .= "id(" . $self->{literal}->as_string . ")";
	}
	else {
		$string .= $self->{test};
	}
	
	if (@{$self->{predicates}}) {
		foreach (@{$self->{predicates}}) {
			next unless defined $_;
			$string .= "[" . $_->as_string . "]";
		}
	}
	return $string;
}

sub evaluate {
	my $self = shift;
	my $from = shift; # context nodeset
	
#	warn "Step::evaluate called with ", $from->size, " length nodeset\n";
	
	$self->{pp}->set_context_set($from);
	
	my $initial_nodeset = XML::XPath::NodeSet->new();
	
	# See spec section 2.1, paragraphs 3,4,5:
	# The node-set selected by the location step is the node-set
	# that results from generating an initial node set from the
	# axis and node-test, and then filtering that node-set by
	# each of the predicates in turn.
	
	# Make each node in the nodeset be the context node, one by one
	for(my $i = 1; $i <= $from->size; $i++) {
		$self->{pp}->set_context_pos($i);
		$initial_nodeset->append($self->evaluate_node($from->get_node($i)));
	}
	
#	warn "Step::evaluate initial nodeset size: ", $initial_nodeset->size, "\n";
	
	# filter initial nodeset by each predicate
	foreach my $predicate (@{$self->{predicates}}) {
		$initial_nodeset = $self->filter_by_predicate($initial_nodeset, $predicate);
	}
	
	return $initial_nodeset;
}

# Evaluate the step against a particular node
sub evaluate_node {
	my $self = shift;
	my $context = shift;
	
	# default direction
	$self->{pp}->set_direction('forward');
	
#	warn "Evaluate node: $self->{axis}\n";
	
	my $results = XML::XPath::NodeSet->new();
	
	if ($self->{axis} eq 'ancestor') {
		$self->{pp}->set_direction('reverse');
		return $results unless $context->[node_parent];
		if ($self->node_test($context->[node_parent])) {
			$results->push($context->[node_parent]);
		}
		$results->append($self->evaluate_node($context->[node_parent]));
	}
	elsif ($self->{axis} eq 'ancestor-or-self') {
		$self->{pp}->set_direction('reverse');
		if ($self->node_test($context)) {
			$results->push($context);
		}
		$results->append($self->evaluate_node($context->[node_parent])) if $context->[node_parent];
	}
	elsif ($self->{axis} eq 'attribute') {
		return $results unless $context->[node_type] eq 'element';
		foreach my $attrib (@{$context->[node_attribs]}) {
			if ($self->test_attribute($attrib)) {
				$results->push($attrib);
			}
		}
	}
	elsif ($self->{axis} eq 'child') {
		return $results unless $context->[node_type] eq 'element';
		foreach my $node (@{$context->[node_children]}) {
			if ($self->node_test($node)) {
				$results->push($node);
			}
		}
	}
	elsif ($self->{axis} eq 'descendant') {
		return $results unless $context->[node_type] eq 'element';
		foreach my $node (@{$context->[node_children]}) {
			if ($self->node_test($node)) {
				$results->push($node);
			}
			$results->append($self->evaluate_node($node));
		}
	}
	elsif ($self->{axis} eq 'descendant-or-self') {
		if ($self->node_test($context)) {
			$results->push($context);
		}
		foreach my $node (@{$context->[node_children]}) {
			$results->append($self->evaluate_node($node));
		}
	}
	elsif ($self->{axis} eq 'following') {
		return $results unless $context->[node_parent];
		my $i = $context->[node_pos];
		local $self->{axis} = 'descendant-or-self';
		for (my $ref = $i + 1; $ref < @{$context->[node_parent]}; $ref++) {
			$results->push($self->evaluate_node($context->[node_parent]->[node_children]->[$ref]));
		}
	}
	elsif ($self->{axis} eq 'following-sibling') {
		return $results unless $context->[node_parent];
		my $i = $context->[node_pos] + 1;
		while(1) {
			last unless $context->[node_parent]->[node_children]->[$i];
			if ($self->node_test($context->[node_parent]->[node_children]->[$i])) {
				$results->push($context->[node_parent]->[node_children]->[$i]);
			}
			$i++;
		}
	}
	elsif ($self->{axis} eq 'namespace') {
		return $results unless $context->[node_type] eq 'element';
		foreach my $ns (@{$context->[node_namespaces]}) {
			if ($self->test_namespace($ns)) {
				$results->push($ns);
			}
		}
	}
	elsif ($self->{axis} eq 'parent') {
		return $results unless $context->[node_parent];
		if ($self->node_test($context->[node_parent])) {
			$results->push($context->[node_parent]);
		}
	}
	elsif ($self->{axis} eq 'preceding') {
		$self->{pp}->set_direction('reverse');
		# all preceding nodes in document order, except ancestors
		# (go through each sibling, and get decendant-or-self)
		local $self->{axis} = 'descendant-or-self';
		my $i = $context->[node_pos];
		my $ref = 0;
		while($context->[node_parent][node_children][$ref] ne $context) {
			$results->append($self->evaluate_node($context->[node_parent][node_children][$ref]));
			$ref++;
		}
	}
	elsif ($self->{axis} eq 'preceding-sibling') {
		$self->{pp}->set_direction('reverse');
		return $results unless $context->[node_parent];
		my $i = $context->[node_pos];
		my $ref = 0;
		while($context->[node_parent]->[node_children]->[$ref] ne $context) {
			if ($self->test_node($context->[node_parent]->[node_children]->[$ref])) {
				$results->push($context->[node_parent]->[node_children]->[$ref]);
			}
			$ref++;
		}
	}
	elsif ($self->{axis} eq 'self') {
		if ($self->node_test($context)) {
			$results->push($context);
		}
	}
	
	return $results;
}

sub node_test {
	my $self = shift;
	my $node = shift;
	
#	warn "node_test: $self->{test}\n";
	
	# if node passes test, return true

	return 1 if $self->{test} eq '*'; # True for all nodes of principal type (element)
	
	if ($self->{test} eq 'node()') {
		return 1;
	}
	elsif ($self->{test} eq 'text()') {
		return 1 if $node->[node_type] eq 'text';
	}
	elsif ($self->{test} eq 'comment()') {
		return 1 if $node->[node_type] eq 'comment';
	}
	elsif ($self->{test} eq 'processing-instruction()') {
		warn "Unreachable code???";
		return 1 if $node->[node_type] eq 'pi';
	}
	elsif ($self->{test} eq 'processing-instruction') {
		return unless $node->[node_type] eq 'pi';
		if ($self->{literal}->value) {
			return 1 if $node->[node_target] eq $self->{literal}->value;
		}
		else {
			return 1;
		}
	}

	return unless $node->[node_type] eq 'element';
	
	if ($self->{test} =~ /^$XML::XPath::Parser::NCName$/) {
		return 1 if $node->[node_name] eq $self->{test};
	}
	elsif ($self->{test} =~ /^$XML::XPath::Parser::NCName:\*$/) {
		# Expand namespace, then match if current node in that ns.
	}
	elsif ($self->{test} =~ /^$XML::XPath::Parser::NCName\:$XML::XPath::Parser::NCName$/) {
		# Expand namespace, then match if node in that ns and name = NCName
	}
	
	return; # fallthrough returns false
}

sub test_attribute {
	my $self = shift;
	my $node = shift;
	
#	warn "test_attrib: $self->{test}\n";
#	warn "node type: $node->[node_type]\n";
	
	return 1 if $self->{test} eq '*';

	if ($self->{test} eq 'node()') {
		return 1;
	}
	elsif ($self->{test} =~ /^$XML::XPath::Parser::NCName$/) {
		# check attrib exists
		if ($node->[node_key] eq $self->{test}) {
			return 1;
		}
	}
	elsif ($self->{test} =~ /^$XML::XPath::Parser::NCName:\*$/) {
		my ($prefix) = $1;
		if ($node->[node_prefix] eq $prefix) {
			return 1;
		}
	}
	elsif ($self->{test} =~ /^$XML::XPath::Parser::NCName\:$XML::XPath::Parser::NCName$/) {
		# Expand namespace, then match if node in that ns and name = NCName
		my ($prefix, $key) = ($1, $2);
		if ($node->[node_prefix] eq $prefix && $node->[node_key] eq $key) {
			return 1;
		}
	}
	
	return; # fallthrough returns false
}

sub test_namespace {
	my $self = shift;
	my $node = shift;
	
	# Not sure if this is correct. The spec seems very unclear on what
	# constitutes a namespace test... bah!
	
	return 1 if $self->{test} eq '*'; # True for all nodes of principal type
	
	if ($self->{test} eq 'node()') {
		return 1;
	}
	elsif ($self->{test} eq $node->[node_expanded]) {
		return 1;
	}
	
	return;
}

sub filter_by_predicate {
	my $self = shift;
	my ($nodeset, $predicate) = @_;
	
	# See spec section 2.4, paragraphs 2 & 3:
	# For each node in the node-set to be filtered, the predicate Expr
	# is evaluated with that node as the context node, with the number
	# of nodes in the node set as the context size, and with the
	# proximity position of the node in the node set with respect to
	# the axis as the context position.
	
	if (!$nodeset) {
		die "No nodeset!!!";
	}
	
#	warn "Filter by predicate: $predicate\n";
	
	my $newset = XML::XPath::NodeSet->new();
	
	for(my $i = 1; $i <= $nodeset->size; $i++) {
		# set context set each time 'cos a loc-path in the expr could change it
		$self->{pp}->set_context_set($nodeset);
		$self->{pp}->set_context_pos($i);
		my $result = $predicate->evaluate($nodeset->get_node($i));
		if ($result->isa('XML::XPath::Boolean')) {
			if ($result->value) {
				$newset->push($nodeset->get_node($i));
			}
		}
		elsif ($result->isa('XML::XPath::Number')) {
			if ($result->value == $self->{pp}->exec_function('position')->value) {
				$newset->push($nodeset->get_node($i));
			}
		}
		else {
			if ($result->to_boolean->value) {
				$newset->push($nodeset->get_node($i));
			}
		}
	}
	
	return $newset;
}

1;
