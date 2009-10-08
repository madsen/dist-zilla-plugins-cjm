#---------------------------------------------------------------------
package Dist::Zilla::Plugin::PodLoom;
#
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 7 Oct 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Process module documentation through Pod::Loom
#---------------------------------------------------------------------

our $VERSION = '0.01';

=head1 DESCRIPTION

If included, this plugin will process each F<.pm> and F<.pod> file
under F<lib> or in the root directory through Pod::Loom.

=cut

use Moose;
#use Moose::Autobox;
with qw(Dist::Zilla::Role::FileMunger
        Dist::Zilla::Role::ModuleInfo);

use Hash::Merge::Simple ();
use Pod::Loom ();

=attr template

This will be passed to Pod::Loom as its C<template>.
Defaults to C<Default>.

=cut

has template => (
  is      => 'ro',
  isa     => 'Str',
  default => 'Default',
);

=attr data

Since Pod::Loom templates may want configuration that doesn't fit in
an INI file, you can specify a file containing Perl code to evaluate.
The result should be a hash reference, which will be passed to
Pod::Loom's C<weave> method.

PodLoom automatically includes the following keys, which will be
merged with the hashref from your code.  (Your code can override these
values.)

=over

=item abstract

The abstract for the file being processed

=item authors

C<< $zilla->authors >>

=item dist

C<< $zilla->name >>

=item license_notice

C<< $zilla->license->notice >>

=item module

The primary package of the file being processed

=item version

The version number of the file being processed

=item zilla

The Dist::Zilla object itself

=back

=cut

has data_file => (
  is       => 'ro',
  isa      => 'Str',
  init_arg => 'data',
);

has data => (
  is       => 'ro',
  isa      => 'HashRef',
  init_arg => undef,
  lazy     => 1,
  builder  => '_initialize_data',
);

has loom => (
  is       => 'ro',
  isa      => 'Pod::Loom',
  init_arg => undef,
  lazy     => 1,
  default  => sub { Pod::Loom->new(template => shift->template) },
);

#---------------------------------------------------------------------
sub _initialize_data
{
  my $plugin = shift;

  my $fname = $plugin->data_file;

  return {} unless $fname;

  open my $fh, '<', $fname or die "can't open $fname for reading: $!";
  my $code = do { local $/; <$fh> };
  close $fh;

  local $@;
  my $result = eval "package Dist::Zilla::Plugin::PodLoom::_eval; $code";

  die $@ if $@;

  return $result;
} # end _initialize_data

#---------------------------------------------------------------------
sub munge_file
{
  my ($self, $file) = @_;

  return unless $file->name =~ /\.(?:pm|pod)$/i
            and ($file->name !~ m{/} or $file->name =~ m{^lib/});

  my $info = $self->get_module_info($file);

  my $dataHash = Hash::Merge::Simple::merge(
    {
      abstract       => Dist::Zilla::Util->abstract_from_file($file->name),
      authors        => $self->zilla->authors,
      dist           => $self->zilla->name,
      license_notice => $self->zilla->license->notice,
      module         => $info->name,
      version        => q{} . $info->version, # stringify version
      zilla          => $self->zilla,
    }, $self->data,
  );

  my $content = $file->content;

  $file->content( $self->loom->weave(\$content, $file->name, $dataHash) );

  return;
} # end munge_file

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT
