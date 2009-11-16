#---------------------------------------------------------------------
package Dist::Zilla::Plugin::VersionFromModule;
#
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 23 Sep 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Get distribution version from its main_module
#---------------------------------------------------------------------

our $VERSION = '0.02';

use Moose;
with 'Dist::Zilla::Role::VersionProvider';
with 'Dist::Zilla::Role::ModuleInfo';

=head1 DESCRIPTION

If included, this plugin will set the distribution's version from the
C<main_module>'s version.  (You should not specify a version in your
F<dist.ini>.)

=cut

sub provide_version {
  my ($self) = @_;

  my $main_module = $self->zilla->main_module;
  my $module = $main_module->name;

  my $pm_info = $self->get_module_info($main_module);
  my $ver     = $pm_info->version;

  die "Unable to get version from $module" unless defined $ver;

  $self->zilla->log("dist version $ver (from $module)");

  "$ver";                       # Need to stringify version object
} # end provide_version

#=====================================================================
# Package Return Value:

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 INCOMPATIBILITIES

Since it will always return a version, VersionFromModule should not be
used with any other VersionProvider plugins.

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT

=for Pod::Coverage
provide_version
