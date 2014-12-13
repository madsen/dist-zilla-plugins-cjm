#---------------------------------------------------------------------
package Dist::Zilla::Plugin::GitVersionCheckCJM;
#
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 15 Nov 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Ensure version numbers are up-to-date
#---------------------------------------------------------------------

our $VERSION = '4.26';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

=head1 SYNOPSIS

In your F<dist.ini>:

  [GitVersionCheckCJM]

=head1 DEPENDENCIES

GitVersionCheckCJM requires {{$t->dependency_link('Dist::Zilla')}}.
It also requires {{$t->dependency_link('Git::Wrapper')}}, although it
is only listed as a recommended dependency for the distribution (to
allow people who don't use Git to use the other plugins.)

=cut

use version 0.77 ();
use Moose;
with(
  'Dist::Zilla::Role::FileMunger',
  'Dist::Zilla::Role::ModuleInfo',
  'Dist::Zilla::Role::FileFinderUser' => {
    default_finders => [ qw(:InstallModules :IncModules :ExecFiles) ],
  },
);

=attr finder

This FileFinder provides the list of modules that will be checked.
The default is C<:InstallModules>.  The C<finder> attribute may be
listed any number of times.

=cut

# RECOMMEND PREREQ: Git::Wrapper
use Git::Wrapper ();            # AutoPrereqs skips this

#---------------------------------------------------------------------
# Helper sub to run a git command and split on NULs:

sub _git0
{
  my ($git, $command, @args) = @_;

  my ($result) = do { local $/; $git->$command(@args) };

  return unless defined $result;

  split(/\0/, $result);
} # end _git0

#---------------------------------------------------------------------
# Main entry point:

sub munge_files {
  my ($self) = @_;

  # Get the released versions:
  my $git = Git::Wrapper->new( $self->zilla->root->stringify );

  my %released = map { /^v?([\d._]+)$/ ? ($1, 1) : () } $git->tag;

  # Get the list of modified but not-checked-in files:
  my %modified = map { $self->log_debug("mod: $_"); $_ => 1 } (
    # Files that need to be committed:
    _git0($git, qw( diff_index -z HEAD --name-only )),
    # Files that are not tracked by git yet:
    _git0($git, qw( ls_files -oz --exclude-standard )),
  );

  # Get the list of modules:
  my $files = $self->found_files;

  # Check each module:
  my $errors = 0;
  foreach my $file (@{ $files }) {
    ++$errors if $self->munge_file($file, $git, \%modified, \%released);
  } # end foreach $file

  die "Stopped because of errors\n" if $errors;
} # end munge_files

#---------------------------------------------------------------------
# Check the version of a module:

sub munge_file
{
  my ($self, $file, $git, $modifiedRef, $releasedRef) = @_;

  # Extract information from the module:
  my $pmFile  = $file->name;
  $self->log_debug("checking $pmFile");
  my $pm_info = $self->get_module_info($file);

  my $version = $pm_info->version
      or $self->log_fatal("ERROR: Can't find version in $pmFile");

  my $distver = version->parse($self->zilla->version);

  # If module version matches dist version, it's current:
  #   (unless that dist has already been released)
  if ($version == $distver) {
    return unless $releasedRef->{$version};
  }

  # If the module version is greater than the dist version, that's a problem:
  if ($version > $distver) {
    $self->log("ERROR: $pmFile: $version exceeds dist version $distver");
    return 1;
  }

  # If the module hasn't been committed yet, it needs updating:
  #   (since it doesn't match the dist version)
  if ($modifiedRef->{$pmFile}) {
    if ($version == $distver) {
      $self->log("ERROR: $pmFile: dist version $version needs to be updated");
    } else {
      $self->log("ERROR: $pmFile: $version needs to be updated");
    }
    return 1;
  }

  # If the module's version doesn't match the dist, and that version
  # hasn't been released, that's a problem:
  unless ($releasedRef->{$version}) {
    $self->log("ERROR: $pmFile: $version does not seem to have been released, but is not current");
    return 1;
  }

  # See if we checked in the module without updating the version:
  my ($lastChangedRev) = $git->rev_list(qw(-n1 HEAD --) => $pmFile);

  my ($inRelease) = $git->name_rev(
    qw(--refs), "refs/tags/$version",
    $lastChangedRev
  );

  # We're ok if the last change was part of the indicated release:
  return if $inRelease =~ m! tags/\Q$version\E!;

  if ($version == $distver) {
    $self->log("ERROR: $pmFile: dist version $version needs to be updated");
  } else {
    $self->log("ERROR: $pmFile: $version needs to be updated");
  }
  return 1;
} # end munge_file

#---------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 DESCRIPTION

This plugin makes sure that module version numbers are updated as
necessary.  In a distribution with multiple module, I like to update a
module's version only when a change is made to that module.  In other
words, a module's version is the version of the last distribution
release in which it was modified.

This plugin checks each module in the distribution, and makes sure
that it matches one of two conditions:

=over

=item 1.

There is a tag matching the version, and the last commit on that
module is included in that tag.

=item 2.

The version matches the distribution's version, and that version has
not been tagged yet (i.e., the distribution has not been released).

=back

If neither condition holds, it prints an error message.  After
checking all modules, it aborts the build if any module had an error.

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT

=for Pod::Coverage
munge_file
munge_files

=cut
