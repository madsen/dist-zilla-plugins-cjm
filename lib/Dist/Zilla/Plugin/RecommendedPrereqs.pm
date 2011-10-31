#---------------------------------------------------------------------
package Dist::Zilla::Plugin::RecommendedPrereqs;
#
# Copyright 2011 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 31 Oct 2011
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Look for comments recommending prerequisites
#---------------------------------------------------------------------

our $VERSION = '4.00';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

=head1 SYNOPSIS

In your F<dist.ini>:

  [RecommendedPrereqs]

In your code:

  # RECOMMEND PREREQ: Foo::Bar 1.0
  # SUGGEST PREREQ:   Foo::Suggested

=head1 DESCRIPTION

If included, this plugin will look for special comments that specify
suggested or recommended prerequisites.  It's intended as a companion
to L<AutoPrereqs|Dist::Zilla::Plugin::AutoPrereqs>, which can only
determine required prerequisites.

Each comment must be on a line by itself, and begin with either
S<C<RECOMMEND PREREQ:>> or S<C<SUGGEST PREREQ:>> followed by the
module name.  The name may be followed by the minimum version, which
may in turn be followed by a note explaining the prereq (which will be
ignored).  If the note is present, the version I<must> be present,
even if it's 0.

=head1 BUGS AND LIMITATIONS

The parser currently just looks for lines beginning with a C<#> (which
may be preceded by whitespace).  This means it looks in strings and
here docs, as well as after C<__END__>.  This behavior may be fixed in
the future and should not be depended on.

=cut

use 5.008;
use Moose;
with(
  'Dist::Zilla::Role::PrereqSource',
  'Dist::Zilla::Role::FileFinderUser' => {
    default_finders => [ ':InstallModules', ':ExecFiles' ],
  },
  'Dist::Zilla::Role::FileFinderUser' => {
    method           => 'found_test_files',
    finder_arg_names => [ 'test_finder' ],
    default_finders  => [ ':TestFiles' ],
  },
);

use namespace::autoclean;

#=====================================================================

use Version::Requirements 0.100630 ();  # merge with 0-min bug
use version ();

sub register_prereqs
{
  my $self  = shift;

  my @sets = (
    [ runtime => 'found_files'      ],
    [ test    => 'found_test_files' ],
  );

  for my $fileset (@sets) {
    my ($phase, $method) = @$fileset;

    my %req = map { $_ => Version::Requirements->new } qw(RECOMMEND SUGGEST);

    my $files = $self->$method;

    foreach my $file (@$files) {
      my $content = $file->content;

      while ($content =~ /^ [ \t]* \# [ \t]* (RECOMMEND|SUGGEST) [ \t]+ PREREQ:
                          [ \t]* (\S+) (?: [ \t]+ (\S+) )?/mgx) {
        $req{$1}->add_minimum($2, $3 || 0);
      }
    } # end foreach $file

    # we're done, add what we've found
    while (my ($type, $req) = each %req) {
      $req = $req->as_string_hash;
      $self->zilla->register_prereqs({ phase => $phase, type => "\L${type}s" },
                                     %$req) if %$req;
    }
  } # end foreach $fileset
} # end register_prereqs

#=====================================================================
# Package Return Value:

__PACKAGE__->meta->make_immutable;
1;

__END__

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT

=for Pod::Coverage
register_prereqs
