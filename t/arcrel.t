#! /usr/bin/perl
#---------------------------------------------------------------------

use strict;
use warnings;
use Test::More tests => 5;

use Dist::Zilla::Tester;

sub make_ini
{
  my $ini = <<'END START';
name     = DZT-Sample
abstract = Sample DZ Dist
version  = 0.001
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
          '[ArchiveRelease]',
        ),
      },
      also_copy => { 'corpus/archives' => 'source/releases' },
    },
  );

  $tzil->build;

  my @files = map {; $_->name } @{ $tzil->files };

  is_deeply(
    [ sort @files ],
    [ sort(qw(dist.ini README lib/DZT/Sample.pm t/basic.t)),
    ],
    "ArchiveRelease prunes default releases directory",
  );
}


{
  my $tzil = Dist::Zilla::Tester->from_config(
    { dist_root => 'corpus/DZT' },
    {
      add_files => {
        'source/dist.ini' => make_ini(
          '[GatherDir]',
          '[ArchiveRelease]',
          'directory = cjm_releases',
        ),
      },
      also_copy => { 'corpus/archives' => 'source/cjm_releases' },
    },
  );

  $tzil->build;

  my @files = map {; $_->name } @{ $tzil->files };

  is_deeply(
    [ sort @files ],
    [ sort(qw(dist.ini README lib/DZT/Sample.pm t/basic.t)),
    ],
    "ArchiveRelease prunes non-standard releases directory",
  );
}


{
  my $tzil = Dist::Zilla::Tester->from_config(
    { dist_root => 'corpus/DZT' },
    {
      add_files => {
        'source/dist.ini' => make_ini(
          '[GatherDir]',
          '[ArchiveRelease]',
        ),
      },
      also_copy => { 'corpus/archives' => 'source/releases' },
    },
  );

  $tzil->release;

  my $tarball = $tzil->root->file('releases/DZT-Sample-0.001.tar.gz');
  ok(-e $tarball, 'archived tarball');
  is($tarball->stat->mode & 0777, 0444, 'tarball is read-only');
  ok((not -e $tzil->root->file('DZT-Sample-0.001.tar.gz')),
     'tarball was moved');
}

done_testing;
