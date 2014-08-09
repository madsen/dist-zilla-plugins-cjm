#---------------------------------------------------------------------
package Dist::Zilla::Plugin::Test::PrereqsFromMeta;
#
# Copyright 2011 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created:  22 Nov 2011
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Check the prereqs from our META.json
#---------------------------------------------------------------------

use 5.008;
our $VERSION = '4.23';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

=head1 SYNOPSIS

In your F<dist.ini>:

  [Test::PrereqsFromMeta]

=head1 DESCRIPTION

This plugin will inject F<t/00-all_prereqs.t> into your dist.  This
test reads your F<META.json> file and attempts to load all runtime
prerequisites.  It fails if any required runtime prerequisites fail to
load.  (If the loaded version is less than the required version, it
prints a warning message but the test does not fail.)

In addition, if C<AUTOMATED_TESTING> is set, it dumps out every module
in C<%INC> along with its version.  This can help you determine the
cause of failures reported by CPAN Testers.

=cut

use Moose;
extends 'Dist::Zilla::Plugin::InlineFiles';
with 'Dist::Zilla::Role::FilePruner';

#---------------------------------------------------------------------
# Make sure we've included a META.json:

sub prune_files
{
  my $self = shift;

  my $files = $self->zilla->files;

  unless (grep { $_->name eq 'META.json' } @$files) {
    $self->log("WARNING: META.json not found, removing t/00-all_prereqs.t");
    @$files = grep { $_->name ne 't/00-all_prereqs.t' } @$files;
  } # end unless META.json

  return;
} # end prune_files

#---------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT

=for Pod::Coverage
prune_files

=cut

__DATA__
___[ t/00-all_prereqs.t ]___
#!perl

use strict;
use warnings;

# This doesn't use Test::More because I don't want to clutter %INC
# with modules that aren't prerequisites.

my $test = 0;
my $tests_completed;

sub ok ($$)
{
  my ($ok, $name) = @_;

  printf "%sok %d - %s\n", ($ok ? '' : 'not '), ++$test, $name;

  return $ok;
} # end ok

END {
  ok(0, 'unknown failure') unless defined $tests_completed;
  print "1..$tests_completed\n";
}

sub get_version
{
  my ($package) = @_;

  local $@;
  my $version = eval { $package->VERSION };

  defined $version ? $version : 'undef';
} # end get_version

TEST: {
  ok(open(META, '<META.json'), 'opened META.json') or last TEST;

  while (<META>) {
     last if /^\s*"prereqs" : \{\s*\z/;
  } # end while <META>

  ok(defined $_, 'found prereqs') or last TEST;

  while (<META>) {
    last if /^\s*\},?\s*\z/;
    ok(/^\s*"(.+)" : \{\s*\z/, "found phase $1") or last TEST;
    my $phase = $1;

    while (<META>) {
      last if /^\s*\},?\s*\z/;
      next if /^\s*"[^"]+"\s*:\s*\{\s*\},?\s*\z/;
      ok(/^\s*"(.+)" : \{\s*\z/, "found relationship $phase $1") or last TEST;
      my $rel = $1;

      while (<META>) {
        last if /^\s*\},?\s*\z/;
        ok(/^\s*"([^"]+)"\s*:\s*(\S+?),?\s*\z/, "found prereq $1")
            or last TEST;
        my ($prereq, $version) = ($1, $2);

        next if $phase ne 'runtime' or $prereq eq 'perl';

        # Need a special case for if.pm, because "require if;" is a syntax error.
        my $loaded = ($prereq eq 'if')
            ? eval "require '$prereq.pm'; 1"
            : eval "require $prereq; 1";
        if ($rel eq 'requires') {
          ok($loaded, "loaded $prereq") or
              print STDERR "\n# ERROR: Wanted: $prereq $version\n";
        } else {
          ok(1, ($loaded ? 'loaded' : 'failed to load') . " $prereq");
        }
        if ($loaded and not ($version eq '"0"' or
                             eval "'$prereq'->VERSION($version); 1")) {
          printf STDERR "\n# WARNING: Got: %s %s\n#       Wanted: %s %s\n",
                        $prereq, get_version($prereq), $prereq, $version;
        }
      } # end while <META> in prerequisites
    } # end while <META> in relationship
  } # end while <META> in phase

  close META;

  # Print version of all loaded modules:
  if ($ENV{AUTOMATED_TESTING}) {
    print STDERR "# Listing %INC\n";

    my @packages = grep { s/\.pm\Z// and do { s![\\/]!::!g; 1 } } sort keys %INC;

    my $len = 0;
    for (@packages) { $len = length if length > $len }
    $len = 68 if $len > 68;

    for my $package (@packages) {
      printf STDERR "# %${len}s %s\n", $package, get_version($package);
    }
  } # end if AUTOMATED_TESTING
} # end TEST

$tests_completed = $test;

__END__
