#---------------------------------------------------------------------
package Dist::Zilla::Plugin::ModuleBuild::Custom;
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

our $VERSION = '0.04';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

=head1 DEPENDENCIES

ModuleBuild::Custom requires {{$t->dependency_link('Dist::Zilla')}} and
L<Text::Template>.  I also recommend applying F<Template_strict.patch>
to Text::Template.  This will add support for the STRICT option, which
will help catch errors in your templates.

=cut

use Moose;
use Moose::Autobox;
extends 'Dist::Zilla::Plugin::ModuleBuild';
with 'Dist::Zilla::Role::FilePruner';

use Data::Dumper ();
use Scalar::Util 'reftype';

# We're trying to make the template executable before it's filled in,
# so we want delimiters that look like comments:
has '+delim' => (
  default  => sub { [ '##{', '##}' ] },
);

# Get rid of any META.yml we may have picked up from Module::Build:
sub prune_files {
  my ($self) = @_;

  my $files = $self->zilla->files;
  @$files = grep { not($_->name eq 'META.yml' and
                       $_->isa('Dist::Zilla::File::OnDisk')) } @$files;

  return;
} # end prune_files

=method get_meta

  $plugin->get_meta(qw(key1 key2 ...))

A template can call this method to extract the specified key(s) from
C<distmeta> and have them formatted into a comma-separated list
suitable for a hash constructor or a method's parameter list.

If any key has no value (or its value is an empty hash or array ref)
it will be omitted from the list.  If all keys are omitted, the empty
string is returned.  Otherwise, the result always ends with a comma.

=cut

sub get_meta
{
  my $self = shift;

  # Extract the wanted keys from distmeta:
  my $distmeta = $self->zilla->distmeta;
  my %want;

  foreach my $key (@_) {
    $self->log_debug("Fetching distmeta key $key");
    next unless defined $distmeta->{$key};

    # Skip keys with empty value:
    my $reftype = reftype($distmeta->{$key});
    if (not $reftype) {}
    elsif ($reftype eq 'HASH')  { next unless %{ $distmeta->{$key} } }
    elsif ($reftype eq 'ARRAY') { next unless @{ $distmeta->{$key} } }

    $want{$key} = $distmeta->{$key};
  } # end foreach $key

  # Format them for inclusion:
  my $data = Data::Dumper->new([ \%want ])
      ->Indent(1)->Sortkeys(1)->Terse(1)->Dump;

  if ($data eq "{}\n") {
    $data = '';
  } else {
    $data =~ s/^\{\n//     or die "Dump prefix! $data";
    $data =~ s/\n\}\n\z/,/ or die "Dump postfix! $data";
  }

  return $data;
} # end get_meta
#---------------------------------------------------------------------

=method get_prereqs

  $plugin->get_prereqs

This is equivalent to

  $plugin->get_meta(qw(build_requires configure_requires requires
                       recommends conflicts))

In other words, it returns all the keys that describe the
distribution's prerequisites.

=cut

sub get_prereqs
{
  shift->get_meta(qw(build_requires configure_requires requires recommends
                     conflicts));
} # end get_prereqs

#---------------------------------------------------------------------
sub setup_installer
{
  my $self = shift;

  my $file = $self->zilla->files->grep(sub { $_->name eq 'Build.PL' })->head
      or $self->log_fatal("No Build.PL found in dist");

  # Process Build.PL through Text::Template:
  my %data = (
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

  $self->log_debug("Processing Build.PL as template");
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

=head1 SYNOPSIS

In F<dist.ini>:

  [ModuleBuild::Custom]
  mb_version = 0.34

In your F<Build.PL>:

  use Module::Build;

  my $builder = Module::Build->new(
    module_name => 'Foo::Bar',
  ##{ $plugin->get_prereqs ##}
  );
  $builder->create_build_script;

Of course, your F<Build.PL> should be more complex than that, or you
don't need this plugin.

=head1 DESCRIPTION

This plugin is for people who need something more complex than the
auto-generated F<Makefile.PL> or F<Build.PL> generated by the
L<MakeMaker|Dist::Zilla::Plugin::MakeMaker> or
L<ModuleBuild|Dist::Zilla::Plugin::ModuleBuild> plugins.

It is a subclass of the L<ModuleBuild plugin|Dist::Zilla::Plugin::ModuleBuild>,
but it does not write a F<Build.PL> for you.  Instead, you write your
own F<Build.PL>, which may do anything L<Module::Build> is capable of
(except generate a compatibility F<Makefile.PL>).

This plugin will process F<Build.PL> as a template (using
L<Text::Template>), which allows you to add data from Dist::Zilla to
the version you distribute (if you want).  The template delimiters are
C<##{> and C<##}>, because that makes them look like comments.
That makes it easier to have a F<Build.PL> that works both before and
after it is processed as a template.

The template may use the following variables:

=over

=item C<$dist>

The name of the distribution.

=item C<$meta>

The hash of metadata that will be stored in F<META.yml>.

=item C<$plugin>

The ModuleBuild::Custom object that is processing the template.

=item C<$version>

The distribution's version number.

=item C<$zilla>

The Dist::Zilla object that is creating the distribution.

=back

=head1 INCOMPATIBILITIES

You must not use this in conjunction with the
L<ModuleBuild|Dist::Zilla::Plugin::ModuleBuild> plugin.

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT

=for Pod::Coverage
prune_files
setup_installer
template_error
