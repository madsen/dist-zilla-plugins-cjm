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
our $VERSION = '0.03';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

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
with 'Dist::Zilla::Role::Releaser';

use autodie ':io';
use Path::Class qw(file);
#---------------------------------------------------------------------

=attr directory

The directory to which the tarball will be moved.
Defaults to F<releases>.

=cut

has directory => (
  is       => 'ro',
  isa      => 'Str',
  default  => 'releases',
);

#---------------------------------------------------------------------
# Main entry point:

sub release
{
  my ($self, $tgz) = @_;

  chmod(0444, $tgz);

  my $dest = file($self->directory, $tgz->basename);

  rename $tgz, $dest;

  $self->log("Moved to $dest");
} # end release

#---------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT

=for Pod::Coverage
release
