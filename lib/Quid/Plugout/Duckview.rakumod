use Quid::Plugout;
use Log::Async;

unit class Quid::Plugout::Duckview is Quid::Plugout;

has $.name = "duckview";
has $.description = "Use duckdb to summarize a csv file";

method execute(IO::Path :$path!) {
  my $proc = Proc::Async.new('duckdb', '-c', "SELECT * FROM read_csv_auto('$path');", :out, :err);
  try {
    react {
      whenever $proc.stdout.lines {
        self.pane.put: $_;
      }
      whenever $proc.stderr.lines {
        self.pane.put: $_;
      }
      whenever $proc.start {
        self.pane.put: "Process terminated with signal $_" if .signal;
        self.pane.put: "Process exited with code $_" if .exitcode;
        self.pane.put: "-- done --";
        done
      }
    }
    CATCH {
      default {
        self.pane.put: "Error executing duckview plugout: $_";
        error "Error executing duckview plugout: $_";
      }
    }
  }
}

