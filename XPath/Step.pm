# $Id: Step.pm,v 1.21 2000/06/08 13:00:23 matt Exp $

package XML::XPath::Step;
use XML::XPath::Parser;
use XML::XPath::Node;
use strict;

sub new {
	my $class = shift;
	my ($pp, $axis, $test, $literal) = @_;
	my $axis_method = "axis_$axis";
	$axis_method =~ tr/-/_/;
	my $self = {
		pp => $pp, # the XML::XPath::Parser class
		axis => $axis,
		axis_method => $axis_method,
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
	
	$self->{pp}->set_context_set(undef);

	return $initial_nodeset;
}

# Evaluate the step against a particular node
sub evaluate_node {
	my $self = shift;
	my $context = shift;
	
	# default direction
	$self->{pp}->set_direction('forward');
	
#	warn "Evaluate node: $self->{axis}\n";
	
#	warn "Node: ", $context->[node_name], "\n";
	
	my $method = $self->{axis_method};
	
	my $results = XML::XPath::NodeSet->new();
	no strict 'refs';
	eval {
		$method->($self, $context, $results);
	};
	if ($@) {
		die "axis $method not implemented [$@]\n";
	}
	return $results;
}

sub axis_ancestor {
	my $self = shift;
	my ($context, $results) = @_;
	
	$self->{pp}->set_direction('reverse');
	my $parent = $context->getParentNode;
	return $results unless $parent;
	if (node_test($self, $parent)) {
		$results->push($parent);
	}
	axis_ancestor($self, $parent, $results);
}

sub axis_ancestor_or_self {
	my $self = shift;
	my ($context, $results) = @_;
	
	$self->{pp}->set_direction('reverse');
	if (node_test($self, $context)) {
		$results->push($context);
	}
	if (my $parent = $context->getParentNode) {
		axis_ancestor_or_self($self, $parent, $results);
	}
}

sub axis_attribute {
	my $self = shift;
	my ($context, $results) = @_;
	
	return $results unless $context->getNodeType == ELEMENT_NODE;
	foreach my $attrib (@{$context->getAttributes}) {
		if ($self->test_attribute($attrib)) {
			$results->push($attrib);
		}
	}
}

sub axis_child {
	my $self = shift;
	my ($context, $results) = @_;
	
	return $results unless $context->getNodeType == ELEMENT_NODE;
	foreach my $node (@{$context->getChildNodes}) {
		if (node_test($self, $node)) {
			$results->push($node);
		}
	}
}

sub axis_descendant {
	my $self = shift;
	my ($context, $results) = @_;
	
	return $results unless $context->getNodeType == ELEMENT_NODE;
	foreach my $node (@{$context->getChildNodes}) {
		if (node_test($self, $node)) {
			$results->push($node);
		}
		axis_descendant($self, $node, $results);
	}
}

sub axis_descendant_or_self {
	my $self = shift;
	my ($context, $results) = @_;
	
	if (node_test($self, $context)) {
		$results->push($context);
	}
	foreach my $node (@{$context->getChildNodes}) {
		axis_descendant_or_self($self, $node, $results);
	}
}

sub axis_following {
	my $self = shift;
	my ($context, $results) = @_;
	
	my $parent = $context->getParentNode;
	return $results unless $parent;
	my $i = $context->get_pos;
	for (my $ref = $i + 1; $ref < @{$parent->getChildNodes}; $ref++) {
		axis_descendant_or_self($self, $parent->getChildNodes->[$ref], $results);
	}
}

sub axis_following_sibling {
	my $self = shift;
	my ($context, $results) = @_;
	
	my $parent = $context->getParentNode;
	return $results unless $parent;
	my $i = $context->get_pos + 1;
	my $children = $parent->getChildNodes;
	while(1) {
		last unless $children->[$i];
		if (node_test($self, $children->[$i])) {
			$results->push($children->[$i]);
		}
		$i++;
	}
}

sub axis_namespace {
	my $self = shift;
	my ($context, $results) = @_;
	
	return $results unless $context->getNodeType == ELEMENT_NODE;
	foreach my $ns (@{$context->getNamespaces}) {
		if ($self->test_namespace($ns)) {
			$results->push($ns);
		}
	}
}

sub axis_parent {
	my $self = shift;
	my ($context, $results) = @_;
	
	my $parent = $context->getParentNode;
	return $results unless $parent;
	if (node_test($self, $parent)) {
		$results->push($parent);
	}
}

sub axis_preceding {
	my $self = shift;
	my ($context, $results) = @_;
	
	$self->{pp}->set_direction('reverse');
	# all preceding nodes in document order, except ancestors
	# (go through each sibling, and get decendant-or-self)
	my $i = $context->get_pos;
	my $ref = 0;
	my $kids = $context->getParentNode->getChildNodes;
	my $node;
	while(($node = $kids->[$ref]) && "$$node" ne "$context") {
		axis_descendant_or_self($self, $node, $results);
		$ref++;
	}
}

sub axis_preceding_sibling {
	my $self = shift;
	my ($context, $results) = @_;
	
	$self->{pp}->set_direction('reverse');
	my $parent = $context->getParentNode;
	return $results unless $parent;
	my $ref = 0;
	my $kids = $parent->getChildNodes;
	my $node;
	while(($node = $kids->[$ref]) && ("$$node" ne "$context")) {
		if (node_test($self, $node)) {
			$results->push($node);
		}
		$ref++;
	}
}

sub axis_self {
	my $self = shift;
	my ($context, $results) = @_;
	
	if (node_test($self, $context)) {
		$results->push($context);
	}
}
	
sub node_test {
	my $self = shift;
	my $node = shift;
	
	{
#		local $^W;
#		warn "node_test: $self->{test} = " . $node->[node_name] . "\n";
		1;
	}
	
	# if node passes test, return true
	
	my $test = $self->{test};
	
	if ($test eq '*' || $test eq 'node()') {
		return 1 if $node->isElementNode;
	}
	
	if ($test =~ /^(text\(\)|comment\(\)|processing-instruction\(\)|processing-instruction)$/) {
		if ($test eq 'text()') {
			return 1 if $node->getNodeType == TEXT_NODE;
		}
		elsif ($test eq 'comment()') {
			return 1 if $node->getNodeType == COMMENT_NODE;
		}
		elsif ($test eq 'processing-instruction()') {
			warn "Unreachable code???";
			return 1 if $node->getNodeType == PROCESSING_INSTRUCTION_NODE;
		}
		elsif ($test eq 'processing-instruction') {
			return unless $node->getNodeType == PROCESSING_INSTRUCTION_NODE;
			if (my $val = $self->{literal}->value) {
				return 1 if $node->getTarget eq $val;
			}
			else {
				return 1;
			}
		}
	}

	return unless $node->isElementNode;
	
	if ($test =~ /^$XML::XPath::Parser::NCName$/) {
		return 1 if $node->getLocalName eq $test;
	}
	elsif ($test =~ /^($XML::XPath::Parser::NCName):\*$/) {
		my $nsprefix = $1;
		return 1 if $node->getPrefix eq $nsprefix;
	}
	elsif ($test =~ /^($XML::XPath::Parser::NCName)\:($XML::XPath::Parser::NCName)$/) {
		return 1 if $node->getName eq $self->{test};
	}
	
	return; # fallthrough returns false
}

sub test_attribute {
	my $self = shift;
	my $node = shift;
	
#	warn "test_attrib: $self->{test}\n";
#	warn "node type: $node->[node_type]\n";
	
	my $test = $self->{test};
	
	return 1 if $test eq '*';

	if ($test eq 'node()') {
		return 1;
	}
	elsif ($test =~ /^$XML::XPath::Parser::NCName$/) {
		# check attrib exists
		if ($node->getName eq $test) {
			return 1;
		}
	}
	elsif ($test =~ /^$XML::XPath::Parser::NCName:\*$/) {
		my ($prefix) = $1;
		if ($node->getPrefix eq $prefix) {
			return 1;
		}
	}
	elsif ($test =~ /^$XML::XPath::Parser::NCName\:$XML::XPath::Parser::NCName$/) {
		# Expand namespace, then match if node in that ns and name = NCName
		my ($prefix, $key) = ($1, $2);
		if ($node->getPrefix eq $prefix && $node->getName eq $key) {
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
	
	my $test = $self->{test};
	
	return 1 if $test eq '*'; # True for all nodes of principal type
	
	if ($test eq 'node()') {
		return 1;
	}
	elsif ($test eq $node->getExpanded) {
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
