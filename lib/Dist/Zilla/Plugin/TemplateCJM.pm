#---------------------------------------------------------------------
package Dist::Zilla::Plugin::TemplateCJM;
#
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 24 Sep 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Process templates, including version numbers & changes
#---------------------------------------------------------------------

our $VERSION = '0.02';

=head1 DEPENDENCIES

TemplateCJM requires L<Dist::Zilla> 1.092680 or later and
L<Text::Template>.  I also recommend applying F<Template_strict.patch>
to Text::Template.  This will add support for the STRICT option, which
will help catch errors in your templates.

=cut

use Moose;
use Moose::Autobox;
with 'Dist::Zilla::Role::FileMunger';
with 'Dist::Zilla::Role::ModuleInfo';
with 'Dist::Zilla::Role::TextTemplate';

sub mvp_multivalue_args { qw(file) }

=attr changelog

This is the name of the F<Changes> file.  It defaults to F<Changes>.

=cut

has changelog => (
  is   => 'ro',
  isa  => 'Str',
  default  => 'Changes',
);

=attr changes

This is the number of releases to include in the C<$changes> variable
passed to templates.  It defaults to 1 (meaning only changes in the
current release).  This is useful when you make a major release
immediately followed by a bugfix release.

=cut

has changes => (
  is   => 'ro',
  isa  => 'Int',
  default  => 1,
);

=attr file

This is the name of a file to process with Text::Template in step 2.
The C<file> attribute may be listed any number of times.  If you don't
list any C<file>s, it defaults to F<README>.  If you do specify any
C<file>s, then F<README> is not processed unless explicitly specified.

=cut

has template_files => (
  is   => 'ro',
  isa  => 'ArrayRef',
  lazy => 1,
  init_arg => 'file',
  default  => sub { [ 'README' ] },
);

#---------------------------------------------------------------------
# Main entry point:

sub munge_files {
  my ($self) = @_;

  my $files = $self->zilla->files;

  # Get release date & changes from Changes file:
  my $changelog = $self->changelog;
  my $changesFile = $files->grep(sub{ $_->name eq $changelog })->head
      or die "No $changelog file\n";

  my ($release_date, $changes) = $self->check_Changes($changesFile);

  # Process template_files:
  my %data = (
     changes => $changes,
     date    => $release_date,
     dist    => $self->zilla->name,
     meta    => $self->zilla->distmeta,
     version => $self->zilla->version,
     zilla   => $self->zilla,
  );

  $data{dist_version} = $data{version};

  # The STRICT option hasn't been implemented in a released version of
  # Text::Template, but you can apply Template_strict.patch.  Since
  # Text::Template ignores unknown options, this code will still work
  # even if you don't apply the patch; you just won't get strict checking.
  my %parms = (
    STRICT => 1,
    BROKEN => sub { $self->template_error(@_) },
  );

  my $any = $self->template_files->any;

  foreach my $file ($files->grep(sub { $_->name eq $any })->flatten) {
    printf "Processing %s\n", $file->name;
    $self->_cur_filename($file->name);
    $self->_cur_offset(0);
    $file->content($self->fill_in_string($file->content, \%data, \%parms));
  } # end foreach $file

  # Munge POD sections in modules:
  $files = $files->grep(sub { $_->name =~ /\.pm$/ and $_->name !~ m{^t/};});

  foreach my $file ($files->flatten) {
    $self->munge_file($file, \%data, \%parms);
  } # end foreach $file
} # end munge_files

#---------------------------------------------------------------------
# Make sure that we've listed this release in Changes:
#
# Returns:
#   A list (release_date, change_text)

sub check_Changes
{
  my ($self, $changesFile) = @_;

  my $file = $changesFile->name;

  my $version = $self->zilla->version;

  # Get the number of releases to include from Changes:
  my $list_releases = $self->changes;

  # Read the Changes file and find the line for dist_version:
  open(my $Changes, '<', \$changesFile->content) or die;

  my ($release_date, $text);

  while (<$Changes>) {
    if (/^(\d[\d._]*)\s+(.+)/) {
      die "ERROR: $file begins with version $1, expected version $version"
          unless $1 eq $version;
      $release_date = $2;
      $text = '';
      while (<$Changes>) {
        last if /^\S/ and --$list_releases <= 0;
        $text .= $_;
      }
      $text =~ s/\s*\z/\n/;     # Normalize trailing whitespace
      die "ERROR: $file contains no history for version $version"
          unless length($text) > 1;
      last;
    } # end if found the first version in Changes
  } # end while more lines in Changes

  close $Changes;

  # Report the results:
  die "ERROR: Can't find any versions in $file" unless $release_date;

  $self->zilla->log("Version $version released $release_date\n$text");

  return ($release_date, $text);
} # end check_Changes

#---------------------------------------------------------------------
# Process all POD sections of a module as templates:

sub munge_file
{
  my ($self, $file, $dataRef, $parmsRef) = @_;

  # Extract information from the module:
  my $pmFile  = $file->name;
  my $pm_info = $self->get_module_info($file);

  my $version = $pm_info->version
      or die "ERROR: Can't find version in $pmFile";

  $self->zilla->log("Updating $pmFile: VERSION $version");

  $dataRef->{version} = "$version";
  $dataRef->{module}  = $pm_info->name;
  $dataRef->{pm_info} = $pm_info;

  $parmsRef->{FILENAME} = $pmFile;

  # Process all POD sections:
  my $content = $file->content;

  $self->_cur_filename($pmFile);
  $self->_cur_content(\$content);

  $content =~ s{( ^=(?!cut\b)\w .*? (?: \z | ^=cut\b ) )}
               {
                 $self->_cur_offset($-[0]);
                 $self->fill_in_string($1, $dataRef, $parmsRef)
               }xgems;

  # And comments at BOL:
  $content =~ s{( ^\#.+ )}
               {
                 $self->_cur_offset($-[0]);
                 $self->fill_in_string($1, $dataRef, $parmsRef)
               }xgem;

  $file->content($content);
  $self->_cur_content(undef);

  return;
} # end munge_file

#---------------------------------------------------------------------
# Report a template error and die:

has _cur_filename => (
  is   => 'rw',
  isa  => 'Str',
);

# This is a reference to the text we're processing templates in
has _cur_content => (
  is   => 'rw',
  isa  => 'Maybe[ScalarRef]',
);

# This is the position in _cur_content where this template began
has _cur_offset => (
  is   => 'rw',
  isa  => 'Int',
);

sub template_error
{
  my ($self, %e) = @_;

  # Calculate the line number where the template started:
  my $offset = $self->_cur_offset;
  if ($offset) {
    $offset = substr(${ $self->_cur_content }, 0, $offset) =~ tr/\n//;
  }

  # Put the filename & line number into the error message:
  my $err = $e{error};
  my $fn  = $self->_cur_filename;
  $err =~ s/ at template line (\d+)/ " at $fn line " . ($1 + $offset) /eg;

  die $err;
} # end template_error

#---------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 DESCRIPTION

This plugin is the successor to L<Module::Build::DistVersion>.
It performs the following actions:

=over

=item 1.

It opens the F<Changes> file, and finds the first version listed.  The
line must begin with the version number, and everything after the
version number is considered to be the release date.  The version
number from Changes must match Dist::Zilla's idea of the
distribution version, or the process stops here with an error.

=item 2.

It processes each template file with Text::Template.  Template files
are specified with the L<< C<file> attribute|/"file" >>.  Any number of
templates may be present.

Each template may use the following variables:

=over

=item C<$changes>

The changes in the current release.  This is a string containing all
lines in F<Changes> following the version/release date line up to (but
not including) the next line that begins with a non-whitespace
character (or end-of-file).

You can include the changes from more than one release by setting the
L<< C<changes> attribute/"changes" >>.  This is useful when you make a
major release immediately followed by a bugfix release.

=item C<$date>

The release date as it appeared in F<Changes>.

=item C<$dist>

The name of the distribution.

=item C<$meta>

The hash of metadata that will be stored in F<META.yml>.

=item C<$version>

The distribution's version number.  (Also available as C<$dist_version>.)

=item C<$zilla>

The Dist::Zilla object that is creating the distribution.

=back

=item 3.

It finds each F<.pm> file (except those in the F<t> directory, if
any).  For each file, it processes each POD section and each comment
that starts at the beginning of a line through Text::Template.

Each section may use the same variables as step 2, plus the following:

=over

=item C<$module>

The name of the module being processed (i.e., its package).

=item C<$pm_info>

A Module::Build::ModuleInfo object containing information about the
module.  (Note that the filename in C<$pm_info> will not be correct.)

=item C<$version>

The module's version number.  This may be different than the
distribution's version, which is available as C<$dist_version>.

=back

=back

=for Pod::Loom-omit
CONFIGURATION AND ENVIRONMENT

=for Pod::Coverage
check_Changes
munge_file
munge_files
mvp_multivalue_args
template_error

=cut
