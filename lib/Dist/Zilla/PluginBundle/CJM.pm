#---------------------------------------------------------------------
package Dist::Zilla::PluginBundle::CJM;
#
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created:  4 Oct 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Build a distribution like CJM
#---------------------------------------------------------------------

our $VERSION = '0.01';

use Moose;
#use Moose::Autobox;
with 'Dist::Zilla::Role::PluginBundle';

=head1 DESCRIPTION

This is a placeholder while I figure out how to best use Dist::Zilla.

=cut

sub bundle_config {
  die "Sorry, Dist::Zilla::PluginBundle::CJM is not implemented yet\n";
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
