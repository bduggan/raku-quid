use Quid::Plugout;
use Log::Async;
use Duck::CSV;

unit class Quid::Plugout::HTML is Quid::Plugout;

has $.name = 'html';
has $.description = 'Open an HTML file';
has $.clear-before = False;

method execute(IO::Path :$path!, IO::Path :$data-dir!, Str :$name!) {
  self.shell-open($path);
}

