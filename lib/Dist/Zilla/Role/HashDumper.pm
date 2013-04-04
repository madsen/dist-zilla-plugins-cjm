#---------------------------------------------------------------------
package Dist::Zilla::Role::HashDumper;
#
# Copyright 2011 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 4 Nov 2011
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Dump selected hash keys as a string
#---------------------------------------------------------------------

our $VERSION = '4.13';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

use Moose::Role;

use namespace::autoclean;

use Scalar::Util 'reftype';

=head1 DEPENDENCIES

{{$t->dependency_link('Data::Dumper')}}.

=head1 DESCRIPTION

Plugins implementing HashDumper may call their own C<extract_keys>
method to extract selected keys from a hash and return a string
suitable for injecting into Perl code.  They may also call the
C<hash_as_string> method to do the same for an entire hash.


=method hash_as_string

  my $string = $plugin->hash_as_string(\%hash);
  eval "%new_hash = ($string);";

This constructs a string of properly quoted keys and values from a
hash.  If the hash is empty, the empty string will be returned.
Otherwise, the result always ends with a comma.

=cut

sub hash_as_string
{
  my ($self, $hash) = @_;

  # Format the hash as a string:
  require Data::Dumper;

  my $data = Data::Dumper->new([ $hash ])
      ->Indent(1)->Sortkeys(1)->Terse(1)->Dump;

  if ($data eq "{}\n") {
    $data = '';
  } else {
    $data =~ s/^\{\n//     or die "Dump prefix! $data";
    $data =~ s/\n\}\n\z/,/ or die "Dump postfix! $data";
  }

  return $data;
} # end hash_as_string

=method extract_keys

  my $string = $plugin->extract_keys($name, \%hash, @keys);
  eval "%new_hash = ($string);";

This combines C<extract_keys_as_hash> and C<hash_as_string>.
It constructs a string of properly quoted keys and values from
selected keys in a hash.  (Note that C<\%hash> is a reference, but
C<@keys> is not.)  The C<$name> is used only in a log_debug message.

If any key has no value (or its value is an empty hash or array ref)
it will be omitted from the list.  If all keys are omitted, the empty
string is returned.  Otherwise, the result always ends with a comma.

=cut

sub extract_keys
{
  my $self = shift;

  return $self->hash_as_string( $self->extract_keys_as_hash(@_) );
} # end extract_keys

=method extract_keys_as_hash

  my $hashref = $plugin->extract_keys_as_hash($name, \%hash, @keys);

This constructs a hashref from from selected keys in a hash.  (Note
that C<\%hash> is a reference, but C<@keys> is not.)  The C<$name> is
used only in a log_debug message.

If any key has no value (or its value is an empty hash or array ref)
it will be omitted from the new hashref.  If all keys are omitted,
an empty hashref is returned.

=cut

sub extract_keys_as_hash
{
  my $self = shift;
  my $type = shift;
  my $hash = shift;

  # Extract the wanted keys from the hash:
  my %want;

  foreach my $key (@_) {
    $self->log_debug("Fetching $type key $key");
    next unless defined $hash->{$key};

    # Skip keys with empty value:
    my $reftype = reftype($hash->{$key});
    if (not $reftype) {}
    elsif ($reftype eq 'HASH')  { next unless %{ $hash->{$key} } }
    elsif ($reftype eq 'ARRAY') { next unless @{ $hash->{$key} } }

    $want{$key} = $hash->{$key};
  } # end foreach $key

  return \%want;
} # end extract_keys_as_hash

no Moose::Role;
1;
