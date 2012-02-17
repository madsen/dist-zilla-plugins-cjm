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

our $VERSION = '4.07';
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
with qw(Dist::Zilla::Role::FilePruner
        Dist::Zilla::Role::HashDumper);

# We're trying to make the template executable before it's filled in,
# so we want delimiters that look like comments:
has '+delim' => (
  default  => sub { [ '##{', '##}' ] },
);

has distmeta1 => (
  is   => 'ro',
  isa  => 'HashRef',
  init_arg  => undef,
  lazy      => 1,
  builder   => '_build_distmeta1',
);

sub _build_distmeta1
{
  my $self = shift;

  require CPAN::Meta::Converter;
  CPAN::Meta::Converter->VERSION(2.101550); # improved downconversion

  my $converter = CPAN::Meta::Converter->new($self->zilla->distmeta);
  return $converter->convert(version => '1.4');
} # end _build_distmeta1

# Get rid of any META.yml we may have picked up from Module::Build:
sub prune_files {
  my ($self) = @_;

  my $files = $self->zilla->files;
  @$files = grep { not($_->name =~ /^META\.(?:yml|json)$/ and
                       $_->isa('Dist::Zilla::File::OnDisk')) } @$files;

  return;
} # end prune_files

=method get_meta

  $plugin->get_meta(qw(key1 key2 ...))

A template can call this method to extract the specified key(s) from
C<distmeta> and have them formatted into a comma-separated list
suitable for a hash constructor or a method's parameter list.  The
keys (and the returned values) are from the META 1.4 spec, because
that's what Module::Build uses in its API.

If any key has no value (or its value is an empty hash or array ref)
it will be omitted from the list.  If all keys are omitted, the empty
string is returned.  Otherwise, the result always ends with a comma.

=cut

sub get_meta
{
  my $self = shift;

  # Extract the wanted keys from distmeta:
  return $self->extract_keys(distmeta1 => $self->distmeta1, @_);
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

=method get_default

  $plugin->get_default(qw(key1 key2 ...))

A template can call this method to extract the specified key(s) from
the default Module::Build arguments created by the normal ModuleBuild
plugin and have them formatted into a comma-separated list suitable
for a hash constructor or a method's parameter list.

If any key has no value (or its value is an empty hash or array ref)
it will be omitted from the list.  If all keys are omitted, the empty
string is returned.  Otherwise, the result always ends with a comma.

The most common usage would be

    ##{ $plugin->get_default('share_dir') ##}

=cut

has _default_mb_args => (
  is        => 'ro',
  isa       => 'HashRef',
  init_arg  => undef,
  lazy      => 1,
  builder   => 'module_build_args',
);

sub get_default
{
  my $self = shift;

  return $self->extract_keys(module_build => $self->_default_mb_args, @_);
} # end get_default

#---------------------------------------------------------------------
sub setup_installer
{
  my $self = shift;

  my $file = $self->zilla->files->grep(sub { $_->name eq 'Build.PL' })->head
      or $self->log_fatal("No Build.PL found in dist");

  # Process Build.PL through Text::Template:
  my %data = (
     dist    => $self->zilla->name,
     meta    => $self->distmeta1,
     meta2   => $self->zilla->distmeta,
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
  mb_version = 0.34  ; the default comes from the ModuleBuild plugin

In your F<Build.PL>:

  use Module::Build;

  my $builder = Module::Build->new(
    module_name => 'Foo::Bar',
  ##{ $plugin->get_prereqs ##}
  ##{ $plugin->get_default('share_dir') ##}
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

This is particularly useful for XS-based modules, because it can allow
you to build and test the module without the overhead of S<C<dzil build>>
after every small change.

The template may use the following variables:

=over

=item C<$dist>

The name of the distribution.

=item C<$meta>

The hash of metadata (in META 1.4 format) that will be stored in F<META.yml>.

=item C<$meta2>

The hash of metadata (in META 2 format) that will be stored in F<META.yml>.

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

=head1 SEE ALSO

The L<MakeMaker::Custom|Dist::Zilla::Plugin::MakeMaker::Custom>
plugin does basically the same thing as this plugin, but for
F<Makefile.PL> (if you prefer L<ExtUtils::MakeMaker>).

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT

=for Pod::Coverage
prune_files
setup_installer
template_error
