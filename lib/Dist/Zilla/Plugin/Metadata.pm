#---------------------------------------------------------------------
package Dist::Zilla::Plugin::Metadata;
#
# Copyright 2017 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created:  2 Dec 2010
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Add arbitrary keys to distmeta
#---------------------------------------------------------------------

our $VERSION = '6.000';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

=head1 SYNOPSIS

In your F<dist.ini>:

  [Metadata]
  dynamic_config              = 1
  resources.homepage          = http://example.com
  resources.bugtracker.mailto = bugs@example.com

=head1 DEPENDENCIES

Metadata requires {{$t->dependency_link('Dist::Zilla')}}.

=cut

use Moose;

has metadata => (
  is       => 'ro',
  isa      => 'HashRef',
  required => 1,
);

with 'Dist::Zilla::Role::MetaProvider';

#---------------------------------------------------------------------
sub BUILDARGS
{
  my ($class, @arg) = @_;
  my %copy = ref $arg[0] ? %{$arg[0]} : @arg;

  my $zilla = delete $copy{zilla};
  my $name  = delete $copy{plugin_name};

  my %metadata;
  while (my ($key, $value) = each %copy) {
    my @keys = split (/\./, $key, -1);
    my $hash = \%metadata;
    while (@keys > 1) {
      $hash = $hash->{shift @keys} ||= {};
    }

    $hash->{$keys[0]} = $value;
  } # end while each %copy

  return {
    zilla       => $zilla,
    plugin_name => $name,
    metadata    => \%metadata,
  };
} # end BUILDARGS

#---------------------------------------------------------------------
sub mvp_multivalue_args
{
  return qw(author keywords license no_index.file no_index.directory
            no_index.package no_index.namespace resources.license
            x_contributors
  );
} # end mvp_multivalue_args

#=====================================================================
no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 DESCRIPTION

The Metadata plugin allows you to add arbitrary keys to your
distribution's metadata.

It splits each key on '.' and uses that as a multi-level hash key.  It
doesn't try to do any validation; the MetaJSON or MetaYAML plugin will
do that.  It does know which keys in the spec are List values; those
keys can be repeated.  In addition, the custom key C<x_contributors>
is treated as a List.

=for Pod::Coverage
mvp_multivalue_args
