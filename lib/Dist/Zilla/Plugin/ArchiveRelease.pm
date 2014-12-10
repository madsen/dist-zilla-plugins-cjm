#---------------------------------------------------------------------
package Dist::Zilla::Plugin::ArchiveRelease;
#
# Copyright 2010 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created:  6 Mar 2010
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Move the release tarball to an archive directory
#---------------------------------------------------------------------

use 5.008;
our $VERSION = '4.00';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

=head1 SYNOPSIS

In your F<dist.ini>:

  [ArchiveRelease]
  directory = releases      ; this is the default

=head1 DESCRIPTION

If included, this plugin will cause the F<release> command to mark the
tarball read-only and move it to an archive directory.  You can
combine this with another Releaser plugin (like
L<UploadToCPAN|Dist::Zilla::Plugin::UploadToCPAN>), but it must be the
last Releaser in your config (or the other Releasers won't be able to
find the file being released).

It also acts as a FilePruner in order to prevent Dist::Zilla from
including the archived releases in future builds.

=cut

use Moose;
with 'Dist::Zilla::Role::BeforeRelease';
with 'Dist::Zilla::Role::Releaser';
with 'Dist::Zilla::Role::FilePruner';

use Path::Class ();
#---------------------------------------------------------------------

=attr directory

The directory to which the tarball will be moved.  It may begin with
C<~> (or C<~user>) to mean your (or some other user's) home directory.
Defaults to F<releases>.
If the directory doesn't exist, it will be created during the
BeforeRelease phase.

All files inside this directory will be pruned from the distribution.

=cut

has _directory => (
  is       => 'ro',
  isa      => 'Str',
  default  => 'releases',
  init_arg => 'directory',
  writer   => '_set_directory',
);

sub directory
{
  my $self = shift;

  my $dir = $self->_directory;

  # Convert ~ to home directory:
  if ($dir =~ /^~/) {
    require File::HomeDir;
    File::HomeDir->VERSION(0.81);

    $dir =~ s/^~(\w+)/ File::HomeDir->users_home("$1") /e;
    $dir =~ s/^~/      File::HomeDir->my_home /e;

    $self->_set_directory($dir);
  } # end if $dir begins with ~

  Path::Class::dir($dir)->absolute($self->zilla->root);
} # end get_directory

#---------------------------------------------------------------------
# Format a path for display:

sub pretty_path
{
  my ($self, $path) = @_;

  my $root = $self->zilla->root;

  $path = $path->relative($root) if $root->subsumes($path);

  "$path";
} # end pretty_path

#---------------------------------------------------------------------
# Don't distribute previously archived releases:

sub prune_files
{
  my $self = shift;

  my $root = $self->zilla->root;
  my $dir  = $self->directory;

  if ($root->subsumes($dir)) {
    $dir      = $dir->relative($root);
    my $files = $self->zilla->files;

    @$files = grep { not $dir->subsumes($_->name) } @$files;
  } # end if archive directory is inside root

  return;
} # end prune_files

#---------------------------------------------------------------------
sub before_release
{
  my ($self, $tgz) = @_;

  my $dir = $self->directory;

  # If the directory doesn't exist, create it:
  unless (-d $dir) {
    my $dirR = $self->pretty_path($dir);

    mkdir $dir or $self->log_fatal("Unable to create directory $dirR: $!");
    $self->log("Created directory $dirR");
  }

  # If the tarball has already been archived, abort:
  my $file = $dir->file($tgz->basename);

  $self->log_fatal($self->pretty_path($file) . " already exists")
      if -e $file;
} # end before_release

#---------------------------------------------------------------------
# Main entry point:

sub release
{
  my ($self, $tgz) = @_;

  chmod(0444, $tgz);

  my $dest = $self->directory->file($tgz->basename);
  my $destR = $self->pretty_path($dest);

  require File::Copy;
  File::Copy::move($tgz, $dest)
        or $self->log_fatal("Failed to move to $destR: $!");

  $self->log("Moved to $destR");
} # end release

#---------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT

=for Pod::Coverage
before_release
release
pretty_path
prune_files
