#! /usr/bin/perl
#---------------------------------------------------------------------

use strict;
use warnings;
use Test::More tests => 3;

use Test::DZil 'Builder';

#---------------------------------------------------------------------
sub make_re
{
  my $text = quotemeta shift;

  $text =~ s/\\\n/ *\n/g;

  qr/^$text/m;
} # end make_re

#---------------------------------------------------------------------
{
  my $tzil = Builder->from_config(
    { dist_root => 'corpus/DZT' },
    {
      add_files => {
        'source/dist.ini' => <<'END INI',
name     = DZT-Sample
author   = E. Xavier Ample <example@example.org>
license  = Perl_5
copyright_holder = E. Xavier Ample
version          = 0.04

[Prereqs]
Foo::Bar = 1.00
Bloofle  = 0

[GatherDir]
[ModuleBuild::Custom]
mb_version = 0.3601
END INI

        'source/Build.PL' => <<'END BUILD',
use Module::Build;

my $builder = My_Build->new(
  module_name        => 'DZT::Sample',
  license            => 'perl',
  dist_author        => 'E. Xavier Ample <example@example.org>',
  dist_version_from  => 'lib/DZT/Sample.pm',
  dynamic_config     => 0,
  # Prerequisites inserted by DistZilla:
##{ $plugin->get_prereqs ##}
);

$builder->create_build_script();
END BUILD
      },
    },
  );

  $tzil->build;

  my $buildPL = $tzil->slurp_file('build/Build.PL');
  #print STDERR $buildPL;

  my $build_requires = <<'END BUILD_REQUIRES';
  'build_requires' => {
    'Module::Build' => '0.3601'
  },
END BUILD_REQUIRES

  my $configure_requires = <<'END CONFIGURE_REQUIRES';
  'configure_requires' => {
    'Module::Build' => '0.3601'
  },
END CONFIGURE_REQUIRES

  my $requires = <<'END REQUIRES';
  'requires' => {
    'Bloofle' => '0',
    'Foo::Bar' => '1.00'
  },
END REQUIRES

  like($buildPL, make_re($build_requires),     "build_requires");
  like($buildPL, make_re($configure_requires), "configure_requires");
  like($buildPL, make_re($requires),           "requires");
}

done_testing;
