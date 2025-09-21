unit role Quid::Events;
use Terminal::ANSI::OO 't';
use Quid::Page;
use Quid::Conf;
use Log::Async;

method show-page { ... }
method show-dir { ... }
method plugouts { ... }
method data-dir { ... } #= current data directory

method set-events {
  $.ui.bind: 'pane', 'e' => 'edit';
  my (\top,\btm) = $.ui.panes;

  top.on-sync: edit => -> :%meta {
    my $line = top.current-line-index;
    put t.text-reset;
    put t.clear-screen;
    put t.reset-scroll-region;
    sleep 0.1;
    my $page = %meta<page> // %meta<target_page> // self.current-page;
    if $page {
      try shell <<$.editor "+$line" {$page.path}>>;
      if $! {
        $.ui.panes[1].put: "error starting editor: $!";
      } else {
        self.show-page: $page;
        $.ui.refresh: :hard;
        top.select: $line;
      }
    } else {
      $.ui.panes[1].put: "no page to edit";
      $.ui.panes[1].put: %meta.raku;
    }
  };

  $.ui.bind: 'pane', 'r' => 'refresh';
  top.on: refresh => -> :%meta {
    my $line = top.current-line-index;
    my $page = %meta<page> // self.current-page;
    self.show-page($_) with $page;
    top.select: $line;
  };

  $.ui.bind: 'pane', 'm' => 'toggle-mode';
  top.on: toggle-mode => -> :%meta {
    my $line = top.current-line-index;
    my $page = %meta<page> // self.current-page;
    with $page && $page.mode {
      when 'eval' { $page.mode = 'raw' }
      when 'raw'  { $page.mode = 'eval' }
    }
    self.show-page($_) with $page;
    top.select: $line;
  }


  top.on: select => -> :%meta {
    debug "Top pane action { %meta<action>.raku }";
    with %meta<action> {
      when 'run' {
        my $cell = %meta<cell> or die "NO CELL";
        self.current-page.run-cell($cell, btm => btm, top => top);
      }
      when 'load_page' {
        my $page = %meta<target_page> // Quid::Page.new(name => %meta<page_name>, wkdir => %meta<wkdir>);
        top.clear;
        self.show-page: $page;
        with %meta<data_dir> -> $dir {
          self.show-dir($dir, pane => btm, header => False);
        }
        # $.ui.refresh: :hard;
        top.select: 0;
      }
      when 'chdir' {
        self.show-dir(%meta<dir>);
      }
      when 'do_output' {
        with %meta<path> -> $path {
           $.plugouts.dispatch($path, pane => btm);
        }
      }

      default {
        info "Unknown action { %meta<action> }";
      }
    }
  }

  btm.on: select => -> :%meta {
    info "Bottom pane action { %meta<action>.raku }";
    with %meta<action> {
      when 'kill_proc' {
        with %meta<proc> -> $proc {
          info "Killing process { $proc.pid.result }";
          btm.put: "Killing process { $proc.pid.result }";
          $proc.kill;
        }
      }
      when 'do_output' {
        my $page = self.current-page;
        my $cell = $page.current-cell // $page.cells[0];
        with %meta<path> -> $path {
           $.plugouts.dispatch($path, pane => btm, data-dir => self.data-dir, name => $cell.name,
           |%( %meta<plugout_name> ?? %( plugout_name => %meta<plugout_name>) !! %() )
         );
        }
      }
    }
  }

  $.ui.bind: 'pane', ']' => 'next-query';
  top.on: next-query => -> :%meta {
    my $page = %meta<page> // self.current-page;
    with %meta<cell> -> $cell {
      if $cell.index < $page.cells - 1 {
       top.select: $page.cells[$cell.index + 1].start-line + $page.title-height;
     }
    } else {
      top.select: $page.title-height;
    }
  }

  $.ui.bind: 'pane', '[' => 'prev-query';
  top.on: prev-query => -> :%meta {
    with %meta<page> -> $page {
      with %meta<cell> -> $cell {
          if $cell.index == 0 {
            top.select: $page.title-height;
          } else {
            top.select: $page.cells[$cell.index - 1].start-line + $page.title-height;
         }
      }
    }
  }

  $.ui.bind('pane', l => 'list-dir');
  top.on: list-dir => -> :%meta (:$dir, *%) { self.show-dir($dir || self.wkdir) };
  btm.on: list-dir => -> :%meta (:$dir, *%) { self.show-dir($dir || self.data-dir, pane => btm, header => False) };

}


