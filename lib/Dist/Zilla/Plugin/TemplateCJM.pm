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
# Copy module version numbers to secondary locations
#---------------------------------------------------------------------

our $VERSION = '0.01';

use Moose;
use Moose::Autobox;
with 'Dist::Zilla::Role::FileMunger';
with 'Dist::Zilla::Role::ModuleInfo';
with 'Dist::Zilla::Role::TextTemplate';

sub mvp_multivalue_args { qw(file) }

has changelog => (
  is   => 'ro',
  isa  => 'Str',
  default  => 'Changes',
);

has changes => (
  is   => 'ro',
  isa  => 'Int',
  default  => 1,
);

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
__PACKAGE__->meta->make_immutable;
no Moose;
1;
