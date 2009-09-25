#---------------------------------------------------------------------
package Dist::Zilla::Role::ModuleInfo;
#
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 25 Sep 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Create Module::Build::ModuleInfo object from Dist::Zilla::Role::File
#---------------------------------------------------------------------

our $VERSION = '0.01';

use Moose::Role;
use Moose::Autobox;

use File::Temp ();
use Module::Build::ModuleInfo ();

#---------------------------------------------------------------------
sub get_module_info
{
  my $self = shift;
  my $file = shift;
  # Any additional parameters get passed to M::B::ModuleInfo->new_from_file

  # Module::Build::ModuleInfo doesn't have a new_from_string method,
  # so we'll write the current contents to a temporary file:

  my $temp = File::Temp->new();

  print $temp $file->content;

  return Module::Build::ModuleInfo->new_from_file("$temp", @_)
      or die "Unable to get module info from " . $file->name . "\n";
} # end get_module_info

no Moose::Role;
1;
