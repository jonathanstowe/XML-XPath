# $Id: Parser.pm,v 1.10 2000/02/14 10:53:15 matt Exp $

package XML::XPath::Parser;

use strict;
use vars qw/$NCName $QName $NODE_TEST $AXIS_NAME %AXES/;

use XML::XPath::XMLParser;
use XML::XPath::Step;
use XML::XPath::Expr;
use XML::XPath::Function;
use XML::XPath::LocationPath;
use XML::XPath::Variable;
use XML::XPath::Literal;
use XML::XPath::Number;
use XML::XPath::NodeSet;

use Data::Dumper;
$Data::Dumper::Indent = 1;

# Axis name to principal node type mapping
%AXES = (
		'ancestor' => 'element',
		'ancestor-or-self' => 'element',
		'attribute' => 'attribute',
		'namespace' => 'namespace',
		'child' => 'element',
		'descendant' => 'element',
		'descendant-or-self' => 'element',
		'following' => 'element',
		'following-sibling' => 'element',
		'parent' => 'element',
		'preceding' => 'element',
		'preceding-sibling' => 'element',
		'self' => 'element',
		);

$NCName = '([A-Za-z_][\w\\.\\-]*)';
$QName = "($NCName:)?$NCName";
$NODE_TEST = '((text|comment|processing-instruction|node)\\(\\))';
$AXIS_NAME = '(' . join('|', keys %AXES) . ')::';

sub new {
	my $class = shift;
	my $self = bless {}, $class;
	$self->{blank_function} = XML::XPath::Function->new($self, []);
	$self->{context_set} = XML::XPath::NodeSet->new();
	$self->{context_pos} = undef; # 1 based position in array context
	$self->{context_size} = 0; # total size of context
	$self->{vars} = {};
	$self->{direction} = 'forward';
	return $self;
}

sub get_var {
	my $self = shift;
	my $var = shift;
	$self->{vars}->{$var};
}

sub set_var {
	my $self = shift;
	my $var = shift;
	my $val = shift;
	$self->{vars}->{$var} = $val;
}

sub get_direction {
	my $self = shift;
	$self->{direction};
}

sub set_direction {
	my $self = shift;
	my ($direction) = @_;
	die "Invalid direction" unless $direction =~ /^(forward|reverse)$/;
	$self->{direction} = $direction;
}

sub get_context_set { $_[0]->{context_set}; }
sub set_context_set { $_[0]->{context_set} = $_[1]; }
sub get_context_pos { $_[0]->{context_pos}; }
sub set_context_pos { $_[0]->{context_pos} = $_[1]; }
sub get_context_size { $_[0]->{context_set}->size; }
sub get_context_node { $_[0]->{context_set}->get_node($_[0]->{context_pos}); }

sub exec_function {
	my $self = shift;
	my $function = shift;
	my @params = @_;
	$self->{blank_function}->_execute($function, @params);
}

sub my_sub {
	return (caller(1))[3];
}

sub parse {
	my $self = shift;
	my $path = shift;
	my $tokens = $self->tokenize($path);
	my $tree = $self->analyze($tokens);
	
#	warn "PARSED Expr to\n", $tree->as_string, "\n";
	
	return $tree;
}

sub tokenize {
	my $self = shift;
	my $path = shift;
	study $path;
	
	my @tokens;

	while($path =~ m/\G
		\s* # ignore all whitespace
		(
			\"[^\"]*\"| # match quotes
			\'[^\']*\'|
			\d+(\.\d*)?|\.\d+| # Match digits
			\.\.| # match parent
			\.| # match current
			([\w\-]+::)?$NODE_TEST| # match tests
			processing-instruction|
			id|
			\@[A-Za-z_\*][\w:\-\.]*| # match attrib
			([\w\-]+::)?[A-Za-z_\-\*][\w:]*| # match NCName,NodeType,Axis::Test
			# match blank! (v.important)
		)
		\s* # ignore all whitespace
		( # seps
			<=|\ -|>=|\/\/|and|or|mod|div| # multi-char seps
			[\$,\+=\|<>\/\(\[\]\)\s]| # single char seps
			(?<!(\@|\(|\[))\*| # multiply operator rules (see xpath spec)
			(?<!::)\*|
			$ # match end of query
		)
		\s* # ignore all whitespace
		/gcxso) {

		my ($token, $sep) = ($1, $7);
#		warn "TOKEN: $token, SEP: $sep\n";
		push @tokens, [$token, $sep];
		
	}
	
	if (pos($path) < length($path)) {
		my $marker = ("." x (pos($path)-1));
		$path = substr($path, 0, pos($path) + 8) . "...";
		$path =~ s/\n/ /g;
		$path =~ s/\t/ /g;
		die "Query: $path\n",
			"      ",  $marker, "^^^\n",
			"Invalid query somewhere around here (I think)\n";
	}
	
	return \@tokens;

}

sub analyze {
	my $self = shift;
	my $tokens = shift;
	# lexical analysis
	
	# This bit of code should produce something that looks like:
	
	# (ISA XML::XPath::LocationPath)
	# list of location steps
	# 	each step is: (ISA XML::XPath::Step)
	#		axis
	#		test
	#		list of predicates
	#			each predicate is:
	#				expression (ISA XML::XPath::Expr)
	#					each expression is:
	#						(location path|function|variable|literal|number|'('expr')')
	#						 + (optional operator & expr)
	
	# XML::XPath::Function
	# XML::XPath::Variable
	# XML::XPath::Literal (string)
	# XML::XPath::Number
	
	return $self->extract_expr($tokens, '');
}

sub extract_loc_path {
	my $self = shift;
	my $tokens = shift;
	
#	warn "Extract Loc_Path\n";
	
	my $loc_path = XML::XPath::LocationPath->new();
	
	while(1) {
		last unless @{$tokens};
		my ($token, $sep) = @{ shift @$tokens };
#		warn "Token: $token, Sep: $sep\n";
		# Handle token
		if ($sep =~ /^(\/|\[|\/\/|\]|\(|\)|and|or|mod|div|<=|>=| -|\+|,|=|\||)$/) {
			# A Full Step
			if ($token eq '.') {
				push @$loc_path, XML::XPath::Step->new($self, 'self', 'node()');
			}
			elsif ($token eq '..') {
				push @$loc_path, XML::XPath::Step->new($self, 'parent', 'node()');
			}
			elsif ($token eq 'processing-instruction' && $sep eq '(') {
				my ($t, $s) = @{ shift @$tokens };
				die "processing-instruction token takes only 1 literal parameter"
						unless $s eq ')';
				$t =~ s/^(["'])(.*)\1$/$2/;
				push @$loc_path, 
						XML::XPath::Step->new($self, 
							'child', 'processing-instruction', 
							XML::XPath::Literal->new($t)
						);
			}
			elsif ($token eq 'id' && $sep eq '(') {
				# dunno what to do here. Bit in brackets could
				# be an expression... argh!
				push @$loc_path,
						XML::XPath::Step->new($self,
							'child', 'id',
							$self->extract_expr($tokens, ')')
						);
			}
			elsif ($token =~ /^\@($QName)$/o) {
				push @$loc_path, XML::XPath::Step->new($self, 'attribute', $1);
			}
			elsif ($token =~ /^$QName$/o) {
				push @$loc_path, XML::XPath::Step->new($self, 'child', $token);
			}
			elsif ($token =~ /^\*$/) {
				push @$loc_path, XML::XPath::Step->new($self, 'child', $token);
			}
			elsif ($token =~ /^$NODE_TEST$/o) {
				push @$loc_path, XML::XPath::Step->new($self, 'child', $1);
			}
			elsif ($token =~ /^$AXIS_NAME($QName|\*|$NODE_TEST)$/o) {
				push @$loc_path, XML::XPath::Step->new($self, $1, $2);
			}
			elsif ($token eq '' && $sep eq '/' && @$loc_path == 0) {
				# root node
				push @$loc_path, XML::XPath::Root->new();
			}
			elsif (length $token) {
				die "Invalid step at token '$token'\n";
			}
		}
		else {
			die "Not a location path near '$token$sep'\n";
		}
		
		# sep always there (because of regexp)
		
		if ($sep eq '//') {
			push @$loc_path, XML::XPath::Step->new($self, 'descendant-or-self', 'node()');
		}
		elsif ($sep eq '[') {
			push @{$loc_path->[-1]->{predicates}}, $self->extract_predicate($tokens);
		}
		elsif ($sep =~ /^(\]|\)|and|or|mod|div|<=|>=|<|>| -|\+|,|=|\||)$/) {
			unshift @$tokens, ['', $sep];
			return $loc_path;
		}
	}
	
	return $loc_path;
}

sub extract_predicate {
	my $self = shift;
	my $tokens = shift;

#	warn "Extract Predicate\n";
	return $self->extract_expr($tokens, ']');
}

sub extract_expr {
	my $self = shift;
	my $tokens = shift;
	my $terminator = shift;
	$terminator = ']' unless defined $terminator;
	
#	warn "Extract Expr '$terminator'\n";
	
	my $expr = XML::XPath::Expr->new($self);
	
	while(1) {
		last unless @$tokens;
		my ($token, $sep) = @{ shift @$tokens };
#		warn "EE.Token: $token, Sep: $sep\n";
		
		# Get lhs
		
		if ($token eq '' && $sep eq '(') {
			# grouping
			$expr->set_lhs($self->extract_expr($tokens, ')'));
#			warn "GOT Bracket LHS: ", $expr->get_lhs->as_string, "\n";
			if ($tokens->[0]->[1] eq $terminator) {
				(undef, $sep) = @{ shift @$tokens };
				last;
			}
			else {
				($token, $sep) = @{ shift @$tokens };
			}
		}
		
		if ($token =~ /^($AXIS_NAME|\@)?($QName|\*|$NODE_TEST|\.\.|\.|)$/o && $sep ne '(') {
			# location_path
			unshift @$tokens, [$token, $sep];
			$expr->set_lhs($self->extract_loc_path($tokens));
			# need to get end sep from above extract!
			(undef, $sep) = @{ shift @$tokens };
		}
		elsif ($token =~ /^(["'])(.*)\1$/ ) {
			$expr->set_lhs(XML::XPath::Literal->new($2));
		}
		elsif ($token =~ /^(\d+(\.\d*)?|\.\d+)$/) {
			$expr->set_lhs(XML::XPath::Number->new($token));
		}
		elsif ($sep eq '(' && $token =~ /^[A-Za-z_][\w\-]*$/ &&
				$token !~ /^(and|or|mod|div)$/) {
			# function?
#			warn "Extracting function $token\n";
			$expr->set_lhs(XML::XPath::Function->new(
					$self,
					$token,
					$self->extract_func_params($tokens)
					)
				);
#			warn "GOT Function: ", $expr->get_lhs->as_string, "\n";
			($token, $sep) = @{ shift @$tokens };
		}
		elsif ($token =~ /^\$([A-Za-z_][\w\-]*)$/) {
			$expr->set_lhs(XML::XPath::Variable->new($self, $1));
		}
		
#		warn "TOKEN: $token, SEP: $sep, TERM: $terminator,\n";
		last if $sep eq $terminator;
		
		# require rhs?
		if ($token =~ /^(and|or|mod|div)$/) {
			# accidentally caught this as token instead of sep
			unshift @$tokens, ['', $sep];
			$sep = $token;
		}
		
		# TODO - need to figure out how to figure out precedence here...
		if ($sep =~ /^(\||or|and|=|!=|<|>|<=|>=|mod|div|\+| -)$/) {
#			warn "Looking for rhs of $sep\n";
			$expr->set_op($sep);
			$expr->set_rhs($self->extract_expr($tokens, $terminator));
#			warn "GOT RHS: ", $expr->get_rhs->as_string, "\n";
			
			# check for predicates on this expr
			if ($terminator ne ')') {
				return $expr;
			}
			while ($tokens->[0]->[1] eq '[') {
#				warn "End bra - extract predicate\n";
				(undef, $sep) = @{ shift @$tokens };
				$expr->push_predicate($self->extract_predicate($tokens));
			}
			return $expr;
		}
#		elsif ($sep eq '[') {
#			# predicated expr
#			warn "HERE\n";
#			while ($tokens->[0]->[1] eq '[') {
#				(undef, $sep) = @{ shift @$tokens };
#				$expr->push_predicate($self->extract_predicate($tokens));
#			}
#			return $expr;
#		}
		else {
			die "No rhs required and no closing '$terminator' (just found '$sep')\n";
		}

	}

#	warn "EE returning\n";
	return $expr->get_lhs ? $expr : undef;
}

sub extract_func_params {
	my $self = shift;
	my $tokens = shift;
	
#	warn "Extract Func_Params\n";
	
	my @params;
	
	while(1) {
		last unless @$tokens;
		my ($token, $sep) = @{ shift @$tokens };
#		warn "FP: TOK $token, SEP $sep\n";
		if ($sep eq ')') {
			my $param = $self->extract_expr([[$token, ')']], ")");
			push @params, $param if ($param);
#			warn "Returning params\n";
			return \@params;
		}
		elsif ($sep eq ',') {
			my $param = $self->extract_expr([[$token, ']']]);
			push @params, $param if ($param);
		}
		else {
			unshift @$tokens, [$token, $sep];
			my $param = $self->extract_expr($tokens, ',');
			push @params, $param if ($param);
		}
	}
	
	die "Malformed function parameters";
}

1;
