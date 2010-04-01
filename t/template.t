#! /usr/bin/perl
#---------------------------------------------------------------------

use strict;
use warnings;
use Test::More tests => 5;

use Dist::Zilla::Tester;

#---------------------------------------------------------------------
sub make_ini
{
  my $version = shift;

  my $ini = "version = $version\n" . <<'END START';
name     = DZT-Sample
author   = E. Xavier Ample <example@example.org>
license  = Perl_5
copyright_holder = E. Xavier Ample

[Prereq]
Foo::Bar = 1.00
Bloofle  = 0
END START

  $ini . join('', map { "$_\n" } @_);
} # end make_ini

#---------------------------------------------------------------------
sub make_changes
{
  my $changes = "Revision history for DZT-Sample\n\n";

  my $num = @_;

  while ($num > 0) {
    $changes .= sprintf("0.%02d   %s\n\t- What happened in release %d\n\n",
                        $num, shift, $num);
    --$num;
  }

  $changes =~ s/\n*\z/\n/;

  $changes;
} # end make_changes

#---------------------------------------------------------------------
sub make_re
{
  my $text = quotemeta shift;

  $text =~ s/\\\n/ *\n/g;

  qr/^$text/m;
} # end make_re

#---------------------------------------------------------------------
my @dates = (
  'April 1, 2010',
  'March 30, 2010',
  'March 29, 2010',
  'March 15, 2010',
  'March 7, 2010',
  'October 11, 2009',
);

{
  my $tzil = Dist::Zilla::Tester->from_config(
    { dist_root => 'corpus/DZT' },
    {
      add_files => {
        'source/dist.ini' => make_ini(
          '0.04',
          '[GatherDir]',
          '[TemplateCJM]',
        ),
        'source/Changes' => make_changes(@dates[-4..-1]),
      },
    },
  );

  $tzil->build;

  my $readme = $tzil->slurp_file('build/README');
  like(
    $readme,
    qr{\A\QDZT-Sample version 0.04, released March 29, 2010\E\n},
    "first line of README",
  );

  my $expected_depends = <<'END DEPEND';
DEPENDENCIES

  Package   Minimum Version
  --------- ---------------
  Bloofle
  Foo::Bar   1.00
END DEPEND

  like($readme, make_re($expected_depends), "DEPENDENCIES in README");

  my $expected_changes = <<'END CHANGES';
CHANGES
    Here's what's new in version 0.04 of DZT-Sample:
    (See the file "Changes" for the full revision history.)

	- What happened in release 4



END CHANGES

  like($readme, make_re($expected_changes), "CHANGES in README");

  undef $readme;

  my $module = $tzil->slurp_file('build/lib/DZT/Sample.pm');

  like(
    $module,
    qr{^\Q# This file is part of DZT-Sample 0.04 (March 29, 2010)\E\n}m,
    'comment in module',
  );

  like(
    $module,
    make_re("DZT::Sample requires L<Bloofle> and\n".
            "L<Foo::Bar> (1.00 or later).\n"),
    'POD in module',
  );
}

done_testing;
