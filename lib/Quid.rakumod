use Terminal::ANSI::OO 't';
use Terminal::UI;
use Log::Async;
use Time::Duration;

use Quid::Events;
use Quid::Page;
use Quid::Plugins;
use Quid::Plugouts;
use Quid::Conf;

unit class Quid:ver<0.0.1>:api<1>:auth<zef:bduggan> does Quid::Events;

has $.ui = Terminal::UI.new;
my \top := my $;
my \btm := my $;

has $.log = logger;
has @.startup-log;

has $.conf;

has $.wkdir is rw is required;
has $.editor is rw;
has Quid::Page $.current-page is rw;
has $.plugins = Quid::Plugins.new;
has $.plugouts = Quid::Plugouts.new;
has Str $.config-file;
has $.conf-errors;

method data-dir {
  $.wkdir.child( $.current-page.name );
}

submethod TWEAK {
  unless $!wkdir.IO.d {
    @!startup-log.push: "Creating working directory at " ~ $!wkdir;
    mkdir $!wkdir
  }
  unless $!conf {
    $!config-file = %*ENV<QUID_CONF> // $!wkdir.child('quid-conf.raku').Str;
    if $!config-file.IO.e {
      @!startup-log.push: "Using config file " ~ $!config-file;
      info "Using config file " ~ $!config-file;
    } else {
      @!startup-log.push: "Creating new config file " ~ $!config-file;
      info "Creating default config file " ~ $!config-file;
      @!startup-log.push: "Creating default config file " ~ $!config-file;
      my $default = "resources/quid-conf-default.raku";
      die "Couldn't find $default" unless $default.IO.e;
      copy $default, $!config-file;
    }
    $!conf = Quid::Conf.new(file => $!config-file);
  }

  try {
    $!plugins.configure($!conf);
    @!startup-log.push: "Available plugins: ";
    for $!plugins.list-all -> $p {
      @!startup-log.push: [
        t.color(%COLORS<cell-type>) => $p<regex>.raku.fmt(' %-20s '),
        t.color(%COLORS<plugin-info>) => $p<name>.fmt('%20s : '),
        t.color(%COLORS<plugin-info>) => $p<desc> // '(no description)',
      ];
    }
    CATCH {
      default {
        $!conf-errors = $_;
        @!startup-log.push: "Error configuring plugins: $_";
        error "Error configuring plugins: $_";
        return;
      }
    }
  }

  try {
    $!plugouts.configure($!conf);
    @!startup-log.push: "Available plugouts: ";
    for $!plugouts.list-all -> $p {
      @!startup-log.push: [
        t.color(%COLORS<cell-type>) => $p<regex>.raku.fmt(' %-20s '),
        t.color(%COLORS<plugin-info>) => $p<name>.fmt('%20s : '),
        t.color(%COLORS<plugin-info>) => $p<desc> // '(no description)',
      ];
    }
    CATCH {
      default {
        $!conf-errors = $_;
        @!startup-log.push: "Error configuring plugouts: $_";
        error "Error configuring plugouts: $_";
      }
    }
  }
}

multi method start-ui(Str :$page) {
  info "starting ui";
  self.start-ui: page => Quid::Page.new(name => $page, :$.wkdir);
}

multi method start-ui(Quid::Page :$page!) {
  $!current-page = $page;
  $.ui.setup: :2panes;
  (top, btm) = $.ui.panes;
  top.auto-scroll = False;
  btm.auto-scroll = False;
  self.show-page: $page;
  self.set-events;
  if @!startup-log {
    btm.put: $_ for @!startup-log;
    @!startup-log = ();
  }
  $.ui.interact;
  $.ui.shutdown;
}

multi method start-ui('browse') {
   $.ui.setup: :2panes;
    (top, btm) = $.ui.panes;
    top.auto-scroll = False;
    btm.auto-scroll = False;
    self.set-events;
    if @!startup-log {
      btm.put: $_ for @!startup-log;
      @!startup-log = ();
    }
    self.show-dir($!wkdir);
    $.ui.interact;
    $.ui.shutdown;
}

multi method show-page(Str $name) {
  self.show-page: Quid::Page.new( :$name, :$.wkdir );
}

multi method show-page(Quid::Page $page) {
  top.clear;
  btm.clear;
  $page.show(pane => top, :$!plugins);
  $!current-page = $page;
}

method show-dir(IO::Path $dir, :$suffix = 'quid', :$pane = top, Bool :$header = True) {
  my \pane := $pane;
  $dir = $!wkdir unless $dir;
  pane.clear;
  if $header {
    pane.put: [t.yellow => "$dir"], :center;
    pane.put: [t.white => "../"], meta => %(dir => $dir.parent, action => 'chdir'), :!scroll-ok;
  } else {
    pane.put: [t.yellow => $dir.basename ~ '/'];
  }

  unless $dir && $dir.d {
    pane.put: "$dir does not exist";
    return;
  }

  my @subdirs = $dir.dir(test => { "$dir/$_".IO.d && !"$dir/$_".IO.basename.starts-with('.') }).sort: *.accessed;
  my %subs = @subdirs.map({.basename}).Set;
  my %shown = Set.new;

  my @pages = reverse $dir.IO.dir(test => { /'.' [ $suffix ] $$/ }).sort: *.accessed;
  for @pages -> $d {
    my $name = $d.basename.subst(/'.' $suffix/,'');
    my $title = "〜 { $name } 〜";
    my %meta =
      target_page => Quid::Page.new( :$name, :path($d), :$.wkdir ),
      action => "load_page",
      data_dir => $.wkdir.child($name),
    ;
    my $width = pane.width;
    my @row = t.color(%COLORS<title>) => $title.fmt('%-40s');
    %shown{$name} = True;
    %meta<dir> = $dir.child($name);
    @row.push: t.color(%COLORS<info>) => ago( (DateTime.now - $d.accessed).Int ).fmt("%{$width - 45}s");
    pane.put: @row, :%meta, :!scroll-ok;
  }

  my @others = reverse $dir.IO.dir(test => { !$dir.child($_).d && !/'.' [ $suffix ] $$/ && !.starts-with('.') }).sort: *.accessed;
  for @others -> $path {
    pane.put: [ t.color(%COLORS<datafile>) => $path.basename.fmt('%-40s'),
                t.color(%COLORS<info>) => ago( (DateTime.now - $path.accessed).Int).fmt("%{$pane.width - 43}s")
             ],
    meta => %( :$path, action => "do_output", dir => $dir) :!scroll-ok;
  }

  pane.select(@subdirs + 2);
}

method generate-welcome-page {
  info "Generating welcome page";
  my $content = qq:to/TXT/;
-- text

Welcome to quid!  This is a sample quid page.

Press j and k to move the green selector line up and down.

Press e to edit this page.

Click 'run' below as a demo, or for some more examples,
check out the [tutorial] page.

-- duck

/*
 * This is a duckdb query.
 * Press return on the line above to run it!
 */
select 'hello' as world;
TXT
   my $page = Quid::Page.new: :$content, :$.wkdir, :name<welcome>;
   @!startup-log.push: "Creating welcome page at " ~ $page.path;
   $page.save;
}

method page-exists($name) {
  info "path is " ~ Quid::Page.new( :$name, :$.wkdir ).path;
  Quid::Page.new( :$name, :$.wkdir ).path.e;
}

method pages-exist {
  $!wkdir.IO.dir(test => { /'.' [ 'quid' ] $$/ }).elems > 0;
}

=begin pod

=head1 NAME

Quid -- Raku notebooks for data exploration

=head1 SYNOPSIS

=begin code

Usage:
  quid -- Browse pages
  quid new -- Open a new page for editing
  quid edit <name> -- Edit a page with the given name
  quid reset-conf -- Reset the configuration to the default
  quid conf -- Edit the configuration file

=end code

=head1 DESCRIPTION

Quid is a console application for data exploration and analysis.

It has some similarities to other notebooks like Wolfram,  R, Jupyter and Observable,
but is primarily aimed at being used in the console, and tries to
be "opinionated about being not opinionated" by emphasizing a pluggable
architecture in which arbitrary languages and tools can be used for
parsing cell input and displaying cell output.  Here's a quick example:

=begin code

-- bash
echo "a,b,c" > out.csv
echo "1,2,3" >> out.csv
echo "done!"

-- duck
select * from 'out.csv';

-- python
print("hello world")

-- ruby
puts "hello world"

-- llm

Tell me about the differences between ruby and python
when printing hello world.  Be concise.

-- html
<pre>
python says:
  〈 cells(2).content 〉
  〈 cells(2).out 〉

 and ruby says
   〈 cells(3).content 〉
   〈 cells(3).out 〉
</pre>

and the LLM says

<pre>
  〈 cells(4).out 〉
</pre>

=end code

Some of its features:

* Notebooks (called "pages") are plain text.  Pages are divided into cells.
  Lines starting with two dashes ("--") divide a page into cells.

* Data streams have first class support; unbuffered output or live data sources
  appear as it is available, not after the entire cell is finished executing.

* Cell input and output are defined by plugins.

* Cell types are defined by a configuration file, and new cell types can be easily added with
  the cell plugin architecture.

* Cell output is serialized with the data directory, so it can be re-used between sessions.

* Displaying outputs of cells is also done with a plugout architectures, and new output/export
  options can be added as plugouts.  Images, HTML, etc can be rendered in a browser.  So despite
  being console focused, output in the browser is intended to be well-supported.

=head1 CONFIGURATION

Quid comes with a default configuration file, it looks like this

    # quid-conf.raku
    #
    %*quid-conf =
      plugins => [
        / duck /   => 'Quid::Plugin::Duck',
        / llm  /   => 'Quid::Plugin::LLM',
        / text /   => 'Quid::Plugin::Text',
        / bash /   => 'Quid::Plugin::Bash',
        / html/    => 'Quid::Plugin::HTML',
      ],
      plugouts => [
        / csv  /   => 'Quid::Plugout::Duckview',
        / csv  /   => 'Quid::Plugout::DataTable',
        / html /   => 'Quid::Plugout::HTML',
        / .*   /   => 'Quid::Plugout::Raw',
      ]
    ;

Inputs (plugins) and outputs (plugouts) are defined by regular expressions which are
applied to the first word after the "--" that starts a cell.   Defining new plugins
is a matter of writing a module that produces output.  This can also be done
inline for simple cases, e.g. here are two plugins for handling python and
ruby cells:

    use Quid::Plugin::Process;

    %*quid-conf =
      plugins => [
        / duck /   => 'Quid::Plugin::Duck',
        / llm  /   => 'Quid::Plugin::LLM',
        / text /   => 'Quid::Plugin::Text',
        / bash /   => 'Quid::Plugin::Bash',
        / html /   => 'Quid::Plugin::HTML',
        / python / => class QuidPython does Quid::Plugin::Process[
                       name => 'python',
                       cmd => 'python3' ] {
           has %.add-env = PYTHONUNBUFFERED => '1';
          },
        / ruby /   => class QuidRuby does Quid::Plugin::Process[
                       name => 'ruby',
                       cmd => 'ruby' ] { },
      ],
      plugouts => [
        / csv  /   => 'Quid::Plugout::Duckview',
        / csv  /   => 'Quid::Plugout::DataTable',
        / html /   => 'Quid::Plugout::HTML',
        / .*   /   => 'Quid::Plugout::Raw',
      ]
    ;

=head2 EXAMPLES

More examples!

Sample page 1:

=begin code

-- duck
select 42 as the_answer;

-- llm
What is the question if 〈prev.rows[0]<the_answer> 〉 is the answer?

-- html
First cell output was 〈cells(0).rows[0]<the_answer> 〉.

=end code

This page has two cells.  The first is a duckdb query, the second is an LLM query.

After running the first, a CSV file is created.  Refreshing the page updates
the second one to look like this:

=begin code

-- duck
select 42 as the_answer;

-- llm
What is the question if 42 is the answer?

=end code

Then running the second sends a query to an LLM.

The symbols "〈" and "〉" are used to indicate code that should be evaluated.  You
can also use "<<<" and ">>>".  Pro tip: if you use vim, you can type "〈" using a
digraph: type "control-k" and then "<" and "/".

Here's an example using the python plugin defined above:

=begin code

-- llm

How do I print a python df to a csv?  be concise

-- python

import pandas as pd
import os
print(os.getcwd())
df = pd.DataFrame( { 'a': [1,2,3,4], 'b': [5,6,7,8] } )
df.to_csv('out.csv')
print(df)

-- duck

select * from 'out.csv'

-- python
import pandas as pd
import matplotlib.pyplot as plt
df = pd.read_csv('out.csv')
df.plot(kind='bar', x='a', y='b')
plt.savefig('plot.png')
plt.show()
plt.close()
df

-- html
<h2>data</h2>
<p>
<img src='plot.png'>
</p>
<pre>
code:
〈 cells(1).content 〉
</pre>

=end code


=end pod

