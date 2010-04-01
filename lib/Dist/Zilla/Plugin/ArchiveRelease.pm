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
our $VERSION = '0.06';
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

=cut

use Moose;
use Moose::Autobox;
with 'Dist::Zilla::Role::BeforeRelease';
with 'Dist::Zilla::Role::Releaser';
with 'Dist::Zilla::Role::FilePruner';

use Path::Class ();
#---------------------------------------------------------------------

=attr directory

The directory to which the tarball will be moved.
Defaults to F<releases>.
If the directory doesn't exist, it will be created during the
BeforeRelease phase.

=cut

has _directory => (
  is       => 'ro',
  isa      => 'Str',
  default  => 'releases',
  init_arg => 'directory',
);

sub directory
{
  my $self = shift;

  Path::Class::dir($self->_directory)->absolute($self->zilla->root);
} # end get_directory

#---------------------------------------------------------------------
sub before_release
{
  my ($self, $tgz) = @_;

  my $dir = $self->directory;

  # If the directory doesn't exist, create it:
  unless (-d $dir) {
    my $dirR = $dir->relative($self->zilla->root);

    mkdir $dir or $self->log_fatal("Unable to create directory $dirR: $!");
    $self->log("Created directory $dirR");
  }

  # If the tarball has already been archived, abort:
  my $file = $dir->file($tgz->basename);

  $self->log_fatal(["%s already exists",
                    $file->relative($self->zilla->root)->stringify])
      if -e $file;
} # end before_release

#---------------------------------------------------------------------
# Main entry point:

sub release
{
  my ($self, $tgz) = @_;

  chmod(0444, $tgz);

  my $dest = $self->directory->file($tgz->basename);
  my $destR = $dest->relative($self->zilla->root);

  rename $tgz, $dest or $self->log_fatal("Failed to move to $destR: $!");

  $self->log("Moved to $destR");
} # end release

# prune archive files from the dist
sub prune_files {
    my ($self) = @_;

    my $dir   = $self->directory->stringify;
    my $root  = $self->zilla->root;
    my $files = $self->zilla->files;

    my @pruned_files;

    for my $file (@$files) {
        my $fdir = Path::Class::file($file->name)->dir->absolute($root)->stringify;
        unless ($fdir eq $dir) {
            push @pruned_files, $file;
        }
    }

    @$files = @pruned_files;

    return;
}

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
