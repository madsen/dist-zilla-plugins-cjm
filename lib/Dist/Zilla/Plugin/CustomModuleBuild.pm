#---------------------------------------------------------------------
package Dist::Zilla::Plugin::CustomModuleBuild;
#
# Copyright 2010 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 11 Mar 2010
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Allow a dist to have a custom Build.PL
#---------------------------------------------------------------------

our $VERSION = '0.03';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

use Moose;
use Moose::Autobox;
extends 'Dist::Zilla::Plugin::ModuleBuild';
with 'Dist::Zilla::Role::FilePruner';

use Data::Dumper ();

# We're trying to make the template executable before it's filled in,
# so we want delimiters that look like comments:
has '+delim' => (
  default  => sub { [ '#{{', '#}}' ] },
);

sub prune_files {
  my ($self) = @_;

  my $files = $self->zilla->files;
  @$files = grep { not($_->name eq 'META.yml' and
                       $_->isa('Dist::Zilla::File::OnDisk')) } @$files;

  return;
} # end prune_files

sub setup_installer
{
  my $self = shift;

  my $file = $self->zilla->files->grep(sub { $_->name eq 'Build.PL' })->head
      or $self->log_fatal("No Build.PL found in dist");

  # Extract the prerequisites from distmeta:
  my $distmeta = $self->zilla->distmeta;
  my $meta = {};

  foreach my $type (qw(build_requires configure_requires requires recommends )) {
    $meta->{$type} = $distmeta->{$type} if %{ $distmeta->{$type} || {} };
  } # end foreach $type

  # Format prerequisites for inclusion:
  my $prereqs = Data::Dumper->new([ $meta ])->Indent(1)->Terse(1)->Dump;

  if ($prereqs eq "{}\n") {
    $prereqs = '';
  } else {
    $prereqs =~ s/^\{\n//     or die "Dump prefix! $prereqs";
    $prereqs =~ s/\n\}\n\z/,/ or die "Dump postfix! $prereqs";
  }

  # Process Build.PL through Text::Template:
  my %data = (
     prereqs => $prereqs,
     dist    => $self->zilla->name,
     meta    => $self->zilla->distmeta,
     plugin  => \$self,
     version => $self->zilla->version,
     zilla   => \$self->zilla,
  );

  # The STRICT option hasn't been implemented in a released version of
  # Text::Template, but you can apply Template_strict.patch.  Since
  # Text::Template ignores unknown options, this code will still work
  # even if you don't apply the patch; you just won't get strict checking.
  my %parms = (
    STRICT => 1,
    BROKEN => sub { $self->template_error(@_) },
  );

  $file->content($self->fill_in_string($file->content, \%data, \%parms));

  return;
} # end setup_installer

sub template_error
{
  my ($self, %e) = @_;

  # Put the filename into the error message:
  my $err = $e{error};
  $err =~ s/ at template line (?=\d)/ at Build.PL line /g;

  $self->log_fatal($err);
} # end template_error

#---------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;

