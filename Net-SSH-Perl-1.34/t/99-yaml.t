#!perl

## Test META.yml for YAMLiciousness, requires Test::YAML::Meta
## Requires TEST_AUTHOR env

use 5.006;
use strict;
use warnings;
use Test::More;
select(($|=1,select(STDERR),$|=1)[1]);

if (!$ENV{TEST_AUTHOR}) {
	plan skip_all => 'Set the environment variable TEST_AUTHOR to enable this test';
}

plan tests => 2;

my $V = 0.03;
eval {
	require Test::YAML::Meta;
	Test::YAML::Meta->import;
};
if ($@) {
	SKIP: {
		skip ('Skipping Test::YAML::Meta tests: module not found', 2);
	}
}
elsif ($Test::YAML::Meta::VERSION < $V) {
	SKIP: {
		skip ("Skipping Test::YAML::Meta tests: need version $V, but only have $Test::YAML::Meta::VERSION", 2);
	}
}
else {
	meta_spec_ok ('META.yml', 1.4);
}
