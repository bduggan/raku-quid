use Quid::Plugout;

unit class Quid::Plugout::Raw is Quid::Plugout;

has $.name = 'raw';
has $.description = 'Open the raw file in a browser, in a <pre> tag';
has $.clear-before = False;

method execute(IO::Path :$path!, IO::Path :$data-dir!, Str :$name!) {
  my $html-file = $data-dir.child("{$name}-raw.html");
  my $fh = open :w, $html-file;
  $fh.put: "<!DOCTYPE html>";
  $fh.put: "<html><head><meta charset='UTF-8'><title>{$name}</title></head><body><pre>";
  $fh.put($_) for $path.IO.lines;
  $fh.put: "</pre></body></html>";
  $fh.close;

  self.shell-open: $html-file;
}

