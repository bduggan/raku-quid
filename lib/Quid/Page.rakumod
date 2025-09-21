
use Log::Async;
use Terminal::ANSI::OO 't';

use Quid::Plugins;
use Quid::Cell;
use Quid::Conf;

logger.untapped-ok = True;

class Quid::Page {

  has Str $.content;
  has IO::Path $.wkdir is required;
  has Str $.name is required;
  has $.suffix = 'quid';
  has @.cells;
  has $.mode is rw = 'eval'; # or 'raw'
  has $.current-cell is rw;
  has Str $.errors;

  multi method get-cell(Int $index) {
    return Nil if $index < 0 || $index >= @!cells.elems;
    $!current-cell = @!cells[$index];
    $!current-cell;
  }

  multi method get-cell(Str $name) {
    $!current-cell = @!cells.first({ .name eq $name });
    $!current-cell;
  }

  method path {
    $.wkdir.child(self.filename)
  }

  method filename {
    return $.name without $.suffix;
    $.name ~ '.' ~ $.suffix;
  }

  method save {
     $.content ==> spurt self.path;
  }

  sub count-lines($str, $pos) {
    return 0 if $pos == 0;
    my $before = $str.substr(0, $pos - 1);
    return +$before.lines + 1;
  }

  method title-height { 1 }

  method maybe-load(:$plugins!) {
    return True if @!cells;
    self.load(:$plugins);
  }

  method show(:$pane, :$plugins!) {
    my $mode = self.mode;
    my $page = self;
    if $mode eq 'raw' {
       $pane.put: [ t.color(%COLORS<raw>) => "-- { self.name } --" ], :center, meta => %( :$page );
    } else {
       $pane.put: [ t.color(%COLORS<title>) => "〜 { self.name } 〜" ], :center, meta => %( :$page );
    }
    unless self.load(:$plugins) {
      if $page.errors {
        $pane.put: 'sorry, got some errors!';
        $pane.put([ t.color(%COLORS<error>) => $_ ], meta => :$page) for $page.errors.lines
      };
      if $page.content -> $c {
        $pane.put([ t.color(%COLORS<inactive>) => $_ ], meta => :$page) for $c.lines;
      }
      return;
    }
    with self.content {
      for self.cells -> $cell {
        my $select-action = $cell.select-action;
        my @actions;
        my %meta;
        if $select-action {
          @actions.push: t.color(%COLORS<button>) => " [run",
                         t.color(%COLORS<cell-name>) => " { $cell.name }",
                         t.color(%COLORS<button>) => "]";
          %meta = ( action => 'run', cell => $cell );
        }
        %meta<page> = self;
        %meta<cell> = $cell;
        $pane.put: [
          t.color(%COLORS<cell-type>) => "━━ " ~ $cell.cell-type.fmt('%-20s'),
          |@actions,
         ], :%meta;
        for $cell.conf.list -> $conf {
          $pane.put: [ t.color(%COLORS<cell-type>) => "━━> " ~ $conf.raku ];
        }
        try {
           CATCH {
             default {
               $pane.put: [ t.red => "Error displaying cell: $_" ], meta => %( :$cell, :self, error => $_ );
             }
           }
           my $*page = self;
           my $out = $cell.get-content(:$mode, page => self);
           if $cell.errors {
             $pane.put( [ t.color(%COLORS<error>) => "--> $_" ] ) for $cell.errors.lines;
           }
           for $out.lines {
             my %meta = $cell.line-meta($_);
             my $line = $cell.line-format($_);
             $pane.put: $line, meta => %( :$cell, :self, |%meta );
           }
         }
      }
    } else {
      $pane.put: [ t.color('#666666') => "(blank page)" ], meta => %( :self );
    }
  }

  method load($content = self.path.slurp, :$plugins!) {
    info "loading page: {self.path}";
    $!content = $content;
    @!cells = ();
    if $! {
      error "failed to load page file: {self.path} - $!";
      $!errors = "failed to load page file: {self.path} - $!";
      return False;
    }
    my regex cell-type { \h* <[a..zA..Z0..9_-]>+ \h* }
    my regex cell-name { <[a..zA..Z0..9_-]>+ }
    my regex cell-header {
      ^^ '--' <cell-type>  [ ':' <cell-name> ]? $$
    }
    my @blocks = $content.split( / <cell-header> /, :v );
    @blocks.shift while @blocks.head ~~ /^\s*$/; # remove leading empty blocks

    my $line-count = self.title-height - 1;
    unless @blocks %% 2 {
      error "malformed page file: {self.path} - could not split cells";
      $!errors = "malformed page file: {self.path} - could not split cells, got {+@blocks} blocks { @blocks[0].raku }";
      $!content = $content;
      return False;
    }

    info "loading page {self.path} with {+@blocks div 2} cells";

    my regex confkey {
      \S+
    }
    my regex confvalue {
      \V+
    }
    my rule confline {
      ^^ '--' <confkey> ':' <confvalue> $$
    }

    for @blocks -> $cell-lead, $cell-content {
      my @lines = $cell-content.lines[1..*];
      my $cell-type;
      my $cell-name;
      $cell-lead ~~ /<cell-header>/ or die "malformed cell header: $cell-lead";
      $cell-type = $<cell-header><cell-type>.Str.trim;
      with $<cell-header><cell-name> -> $n {
        $cell-name = $n.Str.trim;
      }
      #my $cell-type = $cell-lead.subst('--','').trim;
      my @conf;
      while @lines[0] && @lines[0] ~~ &confline {
        info "confline: " ~ @lines[0];
        @conf.push: ( $<confkey>.Str => $<confvalue>.Str );
        @lines.shift;
      }
      my $data-dir = $!wkdir.child(self.name);
      @!cells.push: Quid::Cell.new:
        :@conf,
        :$!wkdir,
        :name( $cell-name // "cell-{+@!cells}" ),
        :$data-dir,
        :$cell-type,
        content => @lines.join("\n") ~ "\n",
        index => $++,
        start-line => $line-count,
        page-name => $.name;
      @!cells.tail.load-plugin: :$plugins;
      $line-count += +$cell-content.lines;
    }
    return True;
  }

  method run-cell(Quid::Cell $cell, :$btm, :$top) {
    my \btm := $btm;
    my \top := $top;
    btm.clear;

    $!current-cell = $cell;

    my $running = start { $cell.execute: mode => self.mode, :page(self) };
    if $cell.stream-output {
      my $streamer = start {
        loop {
          my $line = $cell.output-stream.receive;
          last unless $line;
          if $line.isa(Hash) {
            btm.put: $line<txt>, meta => $line<meta>;
          } else {
            btm.put: $line;
          }
        }
      }
    }
    await $running;

    with $cell.errors {
      btm.put([ t.red => $_ ] ) for .lines;
    }
    with $cell.output {
      given $cell.output.^name {
        when 'Str' {
          btm.put( $_, wrap => $cell.wrap ) for $cell.output.lines;
        }
        when 'Array' {
          info $cell.output.raku;
          for $cell.output<> -> $line {
            if $line.isa(Hash) {
              btm.put: $line<txt>, meta => $line<meta>;
            } else {
              btm.put: $line;
            }
          }
        }
        default {
          btm.put( $cell.output, wrap => $cell.wrap );
        }
      }
    }
  }

}
