# $Id: Function.pm,v 1.12 2000/03/07 20:44:18 matt Exp $

package XML::XPath::Function;
use XML::XPath::XMLParser;
use XML::XPath::Number;
use XML::XPath::Literal;
use XML::XPath::Boolean;
use XML::XPath::NodeSet;
use strict;

sub new {
	my $class = shift;
	my ($pp, $name, $params) = @_;
	bless { 
		pp => $pp, 
		name => $name, 
		params => $params 
		}, $class;
}

sub as_string {
	my $self = shift;
	my $string = $self->{name} . "(";
	my $second;
	foreach (@{$self->{params}}) {
		$string .= "," if $second++;
		$string .= $_->as_string;
	}
	$string .= ")";
	return $string;
}

sub evaluate {
	my $self = shift;
	my $node = shift;
	my @params;
	foreach my $param (@{$self->{params}}) {
		my $results = $param->evaluate($node);
		push @params, $results;
	}
	$self->_execute($self->{name}, $node, @params);
}

sub _execute {
	my $self = shift;
	my ($name, $node, @params) = @_;
	$name =~ s/-/_/g;
	no strict 'refs';
	$self->$name($node, @params);
}

# All functions should return one of:
# XML::XPath::Number
# XML::XPath::Literal (string)
# XML::XPath::NodeSet
# XML::XPath::Boolean

### NODESET FUNCTIONS ###

sub last {
	my $self = shift;
	my ($node, @params) = @_;
	die "last: function doesn't take parameters\n" if (@params);
	return XML::XPath::Number->new($self->{pp}->get_context_size);
}

sub position {
	my $self = shift;
	my ($node, @params) = @_;
	if (@params) {
		die "position: function doesn't take parameters [ ", @params, " ]\n";
	}
	# return pos relative to axis direction
	# dunno if this is the right implementation :)
	if ($self->{pp}->get_direction eq 'reverse') {
		return XML::XPath::Number->new(
				$self->{pp}->get_context_size - $self->{pp}->get_context_pos
				);
	}
	else {
		return XML::XPath::Number->new($self->{pp}->get_context_pos);
	}
}

sub count {
	my $self = shift;
	my ($node, @params) = @_;
	die "count: Parameter must be a NodeSet\n" unless $params[0]->isa('XML::XPath::NodeSet');
	return XML::XPath::Number->new($params[0]->size);
}

sub id {
	my $self = shift;
	my ($node, @params) = @_;
	die "id: Function takes 1 parameter\n" unless @params == 1;
	my $results = XML::XPath::NodeSet->new();
	if ($params[0]->isa('XML::XPath::NodeSet')) {
		# result is the union of applying id() to the
		# string value of each node in the nodeset.
		foreach my $node ($params[0]->get_nodelist) {
			my $string = XML::XPath::XMLParser::string_value($node);
			$results->append($self->id($node, XML::XPath::Literal->new($string)));
		}
	}
	else {
		my $string = $self->string($node, $params[0]);
		$_ = $string->value; # get perl scalar
		my @ids = split; # splits $_
		# get root node
		my $root = $node;
		$root = $root->[node_parent] while($root->[node_parent]);
		foreach my $id (@ids) {
			$results->append($self->_find_id($root, $id));
		}
	}
	return $results;
}

# for id() function
sub _find_id {
	my $self = shift;
	my ($node, $id) = @_;
	my $results = XML::XPath::NodeSet->new();
	foreach my $kid (@{$node->[node_children]}) {
		# check attribs for id
		foreach my $attr (@{$kid->[node_attribs]}) {
			if ($attr->[node_key] eq 'id' && $attr->[node_value] eq $id) {
				$results->push($kid);
			}
		}
		# do this child
		$results->append($self->_find_id($kid, $id));
	}
	return $results;
}

sub local_name {
	my $self = shift;
	my ($node, @params) = @_;
	if (@params > 1) {
		die "name() function takes one or no parameters\n";
	}
	elsif (@params) {
		my $nodeset = shift(@params);
		$node ||= $nodeset->unshift;
	}
	
	my $exp = XML::XPath::XMLParser::expanded_name($node);
	if ($exp =~ /:(.*)/) {
		$exp = $1;
	}
	return XML::XPath::Literal->new($exp);
}

sub namespace_uri {
	my $self = shift;
	my ($node, @params) = @_;
	die "namespace-uri: Function not supported\n";
}

sub name {
	my $self = shift;
	my ($node, @params) = @_;
	if (@params > 1) {
		die "name() function takes one or no parameters\n";
	}
	elsif (@params) {
		my $nodeset = shift(@params);
		$node ||= $nodeset->unshift;
	}
	
	return XML::XPath::Literal->new(
			XML::XPath::XMLParser::expanded_name($node));
}

### STRING FUNCTIONS ###

sub string {
	my $self = shift;
	my ($node, @params) = @_;
	die "string: Too many parameters\n" if @params > 1;
	if ($params[0]) {
		if (ref($params[0]) =~ /^(element|text|comment|pi|namespace|attribute)$/) {
			# assume its a node
			return XML::XPath::Literal->new(
					XML::XPath::XMLParser::string_value($params[0])
					);
		}
		return $params[0]->to_literal;
	}
	
	# default to nodeset with just $node in.
}

sub concat {
	my $self = shift;
	my ($node, @params) = @_;
	die "concat: Too few parameters\n" if @params < 2;
	my $string = join('', map {$_->value} @params);
	return XML::XPath::Literal->new($string);
}

sub starts_with {
	my $self = shift;
	my ($node, @params) = @_;
	die "starts-with: incorrect number of params\n" unless @params == 2;
	if (substr($params[0]->value, 0, length($params[1]->value)) eq $params[1]->value) {
		return XML::XPath::Boolean->True;
	}
	return XML::XPath::Boolean->False;
}

sub contains {
	my $self = shift;
	my ($node, @params) = @_;
	die "starts-with: incorrect number of params\n" unless @params == 2;
	my $value = $params[1]->value;
	if ($params[0]->value =~ /(.*?)\Q$value\E(.*)/) {
		# $1 and $2 stored for substring funcs below
		return XML::XPath::Boolean->True;
	}
	return XML::XPath::Boolean->False;
}

sub substring_before {
	my $self = shift;
	my ($node, @params) = @_;
	die "starts-with: incorrect number of params\n" unless @params == 2;
	if ($self->contains($node, @params)->value) {
		return XML::XPath::Literal->new($1); # hope that works!
	}
	else {
		return XML::XPath::Literal->new('');
	}
}

sub substring_after {
	my $self = shift;
	my ($node, @params) = @_;
	die "starts-with: incorrect number of params\n" unless @params == 2;
	if ($self->contains($node, @params)->value) {
		return XML::XPath::Literal->new($2);
	}
	else {
		return XML::XPath::Literal->new('');
	}
}

sub substring {
	my $self = shift;
	my ($node, @params) = @_;
	die "substring: Wrong number of parameters\n" if (@params < 2 || @params > 3);
	my ($str, $offset, $len);
	$str = $params[0]->value;
	$offset = $params[1]->value;
	$offset--; # uses 1 based offsets
	if (@params == 3) {
		$len = $params[2]->value;
	}
	return XML::XPath::Literal->new(substr($str, $offset, $len));
}

sub string_length {
	my $self = shift;
	my ($node, @params) = @_;
	die "string-length: Wrong number of params\n" if @params > 1;
	if ($params[0]) {
		return XML::XPath::Number->new(length($params[0]->value));
	}
	else {
		return XML::XPath::Number->new(
				length(XML::XPath::XMLParser::string_value($node))
				);
	}
}

sub normalize_space {
	my $self = shift;
	my ($node, @params) = @_;
	die "normalize-space: Wrong number of params\n" if @params > 1;
	my $str;
	if ($params[0]) {
		$str = $params[0]->value;
	}
	else {
		$str = XML::XPath::XMLParser::string_value($node);
	}
	$str =~ s/^\s*//;
	$str =~ s/\s*$//;
	$str =~ s/\s+/ /g;
	return XML::XPath::Literal->new($str);
}

sub translate {
	my $self = shift;
	my ($node, @params) = @_;
	die "translate: Wrong number of params\n" if @params != 3;
	local $_ = $params[0]->value;
	my $find = $params[1]->value;
	my $repl = $params[2]->value;
	eval "tr/\\Q$find\\E/\\Q$repl\\E/d, 1" or die $@;
	return XML::XPath::Literal->new($_);
}

### BOOLEAN FUNCTIONS ###

sub boolean {
	my $self = shift;
	my ($node, @params) = @_;
	die "boolean: Incorrect number of parameters\n" if @params != 1;
	return $params[0]->to_boolean;
}

sub not {
	my $self = shift;
	my ($node, @params) = @_;
	die "not: Parameter must be boolean\n" unless $params[0]->isa('XML::XPath::Boolean');
	$params[0]->value ? XML::XPath::Boolean->False : XML::XPath::Boolean->True;
}

sub true {
	my $self = shift;
	my ($node, @params) = @_;
	die "true: function takes no parameters\n" if @params > 0;
	XML::XPath::Boolean->True;
}

sub false {
	my $self = shift;
	my ($node, @params) = @_;
	die "true: function takes no parameters\n" if @params > 0;
	XML::XPath::Boolean->False;
}

sub lang {
	die "lang: Function not supported\n";
}

### NUMBER FUNCTIONS ###

sub number {
	my $self = shift;
	my ($node, @params) = @_;
	die "number: Too many parameters\n" if @params > 1;
	if ($params[0]) {
		if (ref($params[0]) =~ /^(element|text|comment|pi|namespace|attribute)$/) {
			# assume its a node
			return XML::XPath::Number->new(
					XML::XPath::XMLParser::string_value($params[0])
					);
		}
		return $params[0]->to_number;
	}
	
	# default to nodeset with just $node in. ??? wierd.
}

sub sum {
	my $self = shift;
	my ($node, @params) = @_;
	die "sum: Parameter must be a NodeSet\n" unless $params[0]->isa('XML::XPath::NodeSet');
	die "sum: Function not supported\n";
}

sub floor {
	my $self = shift;
	my ($node, @params) = @_;
	require POSIX;
	my $num = $self->number($node, @params);
	return XML::XPath::Number->new(
			POSIX::floor($num->value));
}

sub ceiling {
	my $self = shift;
	my ($node, @params) = @_;
	require POSIX;
	my $num = $self->number($node, @params);
	return XML::XPath::Number->new(
			POSIX::ceil($num->value));
}

sub round {
	my $self = shift;
	my ($node, @params) = @_;
	my $num = $self->number($node, @params);
	require POSIX;
	return XML::XPath::Number->new(
			POSIX::floor($num->value + 0.5)); # Yes, I know the spec says don't do this...
}

1;
