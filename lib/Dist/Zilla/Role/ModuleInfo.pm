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
# ABSTRACT: Create Module::Build::ModuleInfo object from Dist::Zilla::File
#---------------------------------------------------------------------

our $VERSION = '3.04';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

use Moose::Role;

use autodie ':io';
use File::Temp ();
use Module::Build::ModuleInfo ();
use Path::Class qw(dir file);

=head1 DESCRIPTION

Plugins implementing ModuleInfo may call their own C<get_module_info>
method to construct a L<Module::Build::ModuleInfo> object.

=method get_module_info

  my $info = $plugin->get_module_info($file);

This constructs a Module::Build::ModuleInfo object from the contents
of a C<$file> object that does Dist::Zilla::Role::File.  Any additional
arguments are passed along to C<< Module::Build::ModuleInfo->new_from_file >>.

=cut

sub get_module_info
{
  my $self = shift;
  my $file = shift;
  # Any additional parameters get passed to M::B::ModuleInfo->new_from_file

  # To be safe, reset the global variables controlling IO to their defaults:
  local ($/, $,, $\) = "\n";

  # Module::Build::ModuleInfo doesn't have a new_from_string method,
  # so we'll write the current contents to a temporary file:

  my $tempdirObject = File::Temp->newdir();
  my $dir     = dir("$tempdirObject");
  my $modPath = file($file->name);

  # Module::Build::ModuleInfo only cares about the basename of the file:
  my $tempname = $dir->file($modPath->basename);

  open(my $temp, '>', $tempname);
  print $temp $file->content;
  close $temp;

  return Module::Build::ModuleInfo->new_from_file("$tempname", @_)
      or die "Unable to get module info from " . $file->name . "\n";
} # end get_module_info

no Moose::Role;
1;
