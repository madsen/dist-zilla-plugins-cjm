#! /usr/bin/perl
#---------------------------------------------------------------------

use strict;
use warnings;
use version;
use Test::More 0.88;

use Test::DZil qw(Builder simple_ini);
use Parse::CPAN::Meta;

my $tzil = Builder->from_config(
  { dist_root => 'corpus/DZT' },
  {
    add_files => {
      'source/dist.ini' => simple_ini(qw(GatherDir RecommendedPrereqs),
                                      [ MetaYAML => { version => 2 }]),
    },
  },
);

$tzil->build;

my $meta = Parse::CPAN::Meta->load_file($tzil->tempdir->file('build/META.yml'));

my $ver = version->new($meta->{'meta-spec'}{version});
diag "CPAN::Meta::Spec = $ver";

if ($ver >= version->new('2')) { # See CPAN::Meta::Spec
  is_deeply(
    $meta->{prereqs}{runtime}{recommends},
    { 'Foo::Bar' => '1.00',
      'Foo::Baz' => 0 },
    'runtime recommends'
  );
  
  is($meta->{prereqs}{runtime}{suggests}, undef, 'runtime suggests');
  
  is($meta->{prereqs}{test}{recommends}, undef, 'test recommends');
  
  is_deeply(
    $meta->{prereqs}{test}{suggests},
    { 'Test::Other' => 0 },
    'test suggests'
  );
} elsif ($ver >= version->new('1.4')) { 
  is_deeply(
    $meta->{recommends},
    {
      'Foo::Bar' => '1.00',
      'Foo::Baz' => 0,
    },
    'runtime recommends'
  );
} else {
  plan skip_all => "Unexpected CPAN::Meta::Spec version '$ver'";
}

done_testing;
