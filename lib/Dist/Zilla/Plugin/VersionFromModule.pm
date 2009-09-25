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
# Get distribution version from its main_module
#---------------------------------------------------------------------

our $VERSION = '0.01';

use Moose;
with 'Dist::Zilla::Role::VersionProvider';
with 'Dist::Zilla::Role::ModuleInfo';

sub provide_version {
  my ($self) = @_;

  my $main_module = $self->zilla->main_module;
  my $module = $main_module->name;

  my $pm_info = $self->get_module_info($main_module)
      or die "Unable to get version from $module";

  my $ver = $pm_info->version;

  $self->zilla->log("dist version $ver (from $module)");

  "$ver";                       # Need to stringify version object
} # end provide_version

#=====================================================================
# Package Return Value:

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
