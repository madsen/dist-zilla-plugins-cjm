#---------------------------------------------------------------------
package tools::CompileTests;
#
# Copyright 2010 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 29 Mar 2010
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: create compile tests
#---------------------------------------------------------------------

use Moose;
use Moose::Autobox;
with(
  'Dist::Zilla::Role::FileGatherer',
  'Dist::Zilla::Role::FileFinderUser' => {
    default_finders => [ ':InstallModules' ],
  },
);

sub gather_files {
  my $self = shift;

  require Dist::Zilla::File::FromCode;

  my $file  = Dist::Zilla::File::FromCode->new({
    name => 't/00-compile.t',
    code => sub {

      my @modules = sort map { $_ = $_->name;
                               s!^lib/!!; s!\.pm$!!;
                               s!/!::!g;
                               $_ }
          @{ $self->found_files };

      my $count = @modules;

      @modules = grep { $_ ne 'Dist::Zilla::Plugin::GitVersionCheckCJM' }
                      @modules;

      my $version = $self->zilla->version;

      my $content = <<"END HEADER";
use Test::More tests => $count;

diag("Testing Dist-Zilla-Plugins-CJM $version");

END HEADER

      $content .= "use_ok('$_');\n" for @modules;

      $content .= <<'END GIT';

SKIP: {
  skip 'Git::Wrapper not installed', 1 unless eval "use Git::Wrapper; 1";

  use_ok('Dist::Zilla::Plugin::GitVersionCheckCJM');
}
END GIT

      $content;
    },
  });

  $self->add_file($file);
  return;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
