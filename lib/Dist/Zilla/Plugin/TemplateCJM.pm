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

has format => (
  is  => 'ro',
  isa => 'Str', # should be more validated Later
);

#---------------------------------------------------------------------
# Create the Text::Template for the VERSION section:

sub pod_VERSION_template
{
  my ($self, $pmFilesRef) = @_;

  my $template = $self->format;

  unless (defined $template) {
    $template = ('This document describes version {{$version}}'.
                 ' of {{$module}}, released {{$date}}');

    $template .= ' as part of {{$dist}} version {{$dist_version}}'
        if @$pmFilesRef > 1; # this distribution contains multiple modules

    $template .= '.';
  } # end if no format specified in config

  Text::Template->new(TYPE => 'STRING', SOURCE => $template,
                      DELIMITERS => $self->delim);
} # end pod_VERSION_template

#---------------------------------------------------------------------
# Main entry point:

sub munge_files {
  my ($self) = @_;

  my $files = $self->zilla->files;

  # Get release date & changes from Changes file:
  my $changesFile = $files->grep(sub{ $_->name eq 'Changes' })->head
      or die "No Changes file\n";

  my ($release_date, $changes) = $self->check_Changes($changesFile);

  # Process template_files:
  my %data = (
     changes => $changes,
     date    => $release_date,
     dist    => $self->zilla->name,
     meta    => $self->zilla->distmeta,
     version => $self->zilla->version,
  );

  $data{dist_version} = $data{version};

  my $any = $self->template_files->any;

  foreach my $file ($files->grep(sub { $_->name eq $any })->flatten) {
    printf "Processing %s\n", $file->name;
    $file->content($self->fill_in_string($file->content, \%data));
  } # end foreach $file

  # Update VERSION section in modules:
  $files = $files->grep(sub { $_->name =~ /\.pm$/ and $_->name !~ m{^t/};});

  my $template = $self->pod_VERSION_template($files);

  foreach my $file ($files->flatten) {
    $self->munge_file($file, $template, \%data);
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
  open(my $Changes, '<:utf8', \$changesFile->content) or die;

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
# Update the VERSION section of a module:

sub munge_file
{
  my ($self, $file, $template, $dataRef) = @_;

  # Extract information from the module:
  my $pmFile  = $file->name;
  my $pm_info = $self->get_module_info($file);

  my $version = $pm_info->version
      or die "ERROR: Can't find version in $pmFile";

  # Split the modules content, into an array:
  my @lines = split /\n/, $file->content;

  my $i = 0;
  my $foundHeading;

  # Find the VERSION section:
  while (defined $lines[$i] and not $lines[$i] =~ /^=head1 VERSION/) {
    $foundHeading = 1 if not $foundHeading and $lines[$i] =~ /^=head/;
    ++$i;
  }

  # Skip blank lines:
  1 while defined $lines[++$i] and not $lines[$i] =~ /\S/;

  # Verify the section:
  if (not defined $lines[$i]) {
    # It's ok to have no VERSION section if you have no POD:
    die "ERROR: $pmFile has no VERSION section\n" if $foundHeading;
  } elsif (not $lines[$i] =~ /^This (?:section|document)/) {
    die "ERROR: $pmFile: Unexpected line $lines[$i]";
  } else {
    print "Updating $pmFile: VERSION $version\n";

    $dataRef->{version} = "$version";
    $dataRef->{module}  = $pm_info->name;

    $lines[$i] = $template->fill_in(HASH => $dataRef)
        or die "TEMPLATE ERROR: " . $Text::Template::ERROR;
  }

  $file->content(join "\n", @lines);

  return;
} # end munge_file

#---------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
no Moose;
1;
