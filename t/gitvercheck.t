#! /usr/bin/perl
#---------------------------------------------------------------------

use strict;
use warnings;
use autodie ':io';

use Test::More;

BEGIN {
  eval "use Git::Wrapper; 1"
      or plan skip_all => "Git::Wrapper required for testing GitVersionCheckCJM";

  eval "use Test::Fatal; 1"
      or plan skip_all => "Test::Fatal required for testing GitVersionCheckCJM";
}

plan tests => 18;

use Dist::Zilla::Tester 'Builder';
use File::pushd 'pushd';
use File::Temp ();
use Path::Class qw(dir file);

my $stoppedRE = qr/Stopped because of errors/;

#---------------------------------------------------------------------
# Initialise Git working copy:

my $tempdir    = File::Temp->newdir;
my $gitRoot    = dir("$tempdir")->absolute;
my $gitHistory = file("corpus/gitvercheck.git")->absolute;

{
  my $wd = pushd($gitRoot);
  system "git init --quiet" and die "Couldn't init";
  system "git fast-import --quiet <\"$gitHistory\"" and die "Couldn't import";
}

my $git = Git::Wrapper->new("$gitRoot");

$git->config('user.email', 'example@example.org');
$git->config('user.name',  'E. Xavier Ample');
$git->checkout(qw(--force --quiet master));

#---------------------------------------------------------------------
sub edit
{
  my ($file, $edit) = @_;

  my $fn = $gitRoot->subdir("lib/DZT")->file("$file.pm");

  local $_ = do {
    local $/;
    open my $fh, '<:raw', $fn;
    <$fh>;
  };

  $edit->();

  open my $fh, '>:raw', $fn;
  print $fh $_;
  close $fh;
} # end edit

#---------------------------------------------------------------------
sub set_version
{
  my $version = shift;

  foreach my $file (@_) {
    edit($file, sub { s/(\$VERSION\s*=)\s*'[^']*'/$1 '$version'/ or die });
  }
} # end set_version

#---------------------------------------------------------------------
sub new_tzil
{
  my $tzil = Builder->from_config(
    { dist_root => $gitRoot },
  );

  # Something about the copy dzil makes seems to confuse git into
  # thinking files are modified when they aren't.
  # Run "git status" in the source directory to unconfuse it:
  Git::Wrapper->new( $tzil->tempdir->subdir("source") )->status;

  $tzil;
} # end new_tzil

#------------------------------------------------------n---------------
# Extract the errors reported by GitVersionCheckCJM:

sub errors
{
  my ($tzil) = @_;

  my @messages = grep { s/^.*GitVersionCheckCJM.*ERROR:\s*// }
                      @{ $tzil->log_messages };
  my %error;

  for (@messages) {
    s!\s*lib/DZT/(\S+)\.pm\b:?\s*!! or die "Can't find filename in $_";
    $error{$1} = $_;
  }

  #use YAML::XS;  print Dump $tzil->log_events;

  return \%error;
} # end errors

#---------------------------------------------------------------------
{
  my $tzil = new_tzil;
  is(exception { $tzil->build }, undef, "build 0.04");
  is_deeply(errors($tzil), {}, "no errors in 0.04");
#  print "$_\n" for @{ $tzil->log_messages };
#  print $tzil->tempdir,"\n"; my $wait = <STDIN>;
}

{
  set_version('0.04', 'Sample/Second');

  my $tzil = new_tzil;
  like(exception { $tzil->build }, $stoppedRE, "can't build modified 0.04");

  is_deeply(errors($tzil),
            { 'Sample/Second' => 'dist version 0.04 needs to be updated' },
            "errors in modified 0.04");
}

{
  set_version('0.05', 'Sample');

  my $tzil = new_tzil;
  like(exception { $tzil->build }, $stoppedRE, "can't build 0.05 yet");

  is_deeply(errors($tzil),
            { 'Sample/Second' => '0.04 needs to be updated' },
            "errors in 0.05");
}

{
  set_version('0.05', 'Sample/Second');

  my $tzil = new_tzil;
  is(exception { $tzil->build }, undef, "can build 0.05 now");
  is_deeply(errors($tzil), {}, "no errors in 0.05 now");
}

#---------------------------------------------------------------------
$git->reset(qw(--hard --quiet)); # Restore to checked-in state

{
  set_version('0.045', 'First');

  my $tzil = new_tzil;
  like(exception { $tzil->build }, $stoppedRE, "can't build with 0.045");
  is_deeply(errors($tzil), { First => '0.045 exceeds dist version 0.04' },
            "errors with 0.045");
}

{
  set_version('0.05', 'Sample');

  my $tzil = new_tzil;
  like(exception { $tzil->build }, $stoppedRE, "can't build 0.05 with 0.045");
  is_deeply(errors($tzil), {
    First => '0.045 needs to be updated',
  }, "errors in 0.05 with 0.045");
}

{
  $git->add('lib/DZT/First.pm');
  $git->commit(-m => 'checking in DZT::First 0.045');

  my $tzil = new_tzil;
  like(exception { $tzil->build }, $stoppedRE,
       "can't build 0.05 with 0.045 committed");
  is_deeply(errors($tzil), {
    First => '0.045 does not seem to have been released, but is not current',
  }, "errors in 0.05 with 0.045 committed");
}

{
  set_version('0.05', 'First');

  my $tzil = new_tzil;
  is(exception { $tzil->build }, undef, "can build with First 0.05");
  is_deeply(errors($tzil), {}, "no errors with First 0.05");
}

{
  edit('First', sub { s/^.*VERSION.*\n//m or die });

  my $tzil = new_tzil;
  like(exception { $tzil->build }, qr/ERROR: Can't find version/,
       "can't build with First unversioned");
  is_deeply(errors($tzil), { First => "Can't find version in" },
            "errors with First unversioned");
}

undef $tempdir;                 # Clean up temporary directory

done_testing;
