#---------------------------------------------------------------------
package Dist::Zilla::Plugin::TestRelease;
#
# Copyright 2010 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 29 Mar 2010
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Ensure the tarball passes tests before releasing
#---------------------------------------------------------------------

use 5.008;
our $VERSION = '0.05';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

=head1 DESCRIPTION

If included, this plugin will cause the F<release> command to extract
the about-to-be-released tarball and ensure that it passes its tests.
If any tests fail, the release is aborted.

It sets C<RELEASE_TESTING> to 1 while running the tests.

=cut

use Moose;
use Moose::Autobox;
with 'Dist::Zilla::Role::BeforeRelease';

use Path::Class ();
#---------------------------------------------------------------------

sub before_release
{
  my ($self, $tgz) = @_;

  require Archive::Tar;
  require File::chdir;

  my $tgzPath = $tgz->absolute->stringify;

  # Extract the tarball to a temporary directory:
  my $build_root = $self->zilla->root->subdir('.build');
  $build_root->mkpath unless -d $build_root;

  my $tmpdir = Path::Class::dir( File::Temp::tempdir(DIR => $build_root) );

  $self->log("Extracting $tgz to $tmpdir");

  my @files = do {
    local $File::chdir::CWD = $tmpdir;
    Archive::Tar->extract_archive($tgzPath);
  };

  $self->log_fatal(["Failed to extract archive: %s", Archive::Tar->error])
      unless @files;

  # Run tests on the extracted tarball:
  my $target = $tmpdir->subdir($files[0]); # Should be the root of the tarball

  local $ENV{RELEASE_TESTING} = 1;

  my $error = $self->zilla->run_tests_in($target);

  if ($error) {
    $self->log($error);
    $self->log_fatal("left failed dist in place at $target");
  } else {
    $self->log("all's well; removing $tmpdir");
    $tmpdir->rmtree;
  }
} # end before_release

#---------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT

=for Pod::Coverage
before_release
