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

has template => (
  is      => 'ro',
  isa     => 'Str',
  default => 'Default',
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

sub _initialize_data
{
  return {};                    # FIXME read from file
} # end _initialize_data

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
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT
