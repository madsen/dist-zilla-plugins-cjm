#! /usr/bin/perl
#---------------------------------------------------------------------

use strict;
use warnings;
use Test::More tests => 1;

use Dist::Zilla::Tester;

sub make_ini
{
  my $ini = <<'END START';
name     = DZT-Sample
author   = E. Xavier Ample <example@example.org>
license  = Perl_5
copyright_holder = E. Xavier Ample
END START

  $ini . join('', map { "$_\n" } @_);
} # end make_ini

{
  my $tzil = Dist::Zilla::Tester->from_config(
    { dist_root => 'corpus/DZT' },
    {
      add_files => {
        'source/dist.ini' => make_ini(
          '[GatherDir]',
          '[VersionFromModule]',
        ),
      },
    },
  );

  $tzil->build;

  is($tzil->version, '0.04', "VersionFromModule found version",
  );
}

done_testing;
