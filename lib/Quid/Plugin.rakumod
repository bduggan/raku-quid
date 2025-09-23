unit role Quid::Plugin;

use Terminal::ANSI::OO 't';
use Prettier::Table;
use Duckie;
use Duckie::Result;
use Quid::Conf;
use Log::Async;

method name { ... }
method description { ... }

method wrap { 'none' }
method stream-output { False }

method setup {}

method output-ext { 'csv' }
method write-output { True }

has $.output; # Str or array
has Channel $.output-stream = Channel.new;

multi method stream(:$txt!, :$meta) {
  self.stream: %( :$txt, :$meta )
}

multi method stream($stuff) {
  $!output-stream.send: $stuff;
}

method info(Str $what) {
  self.stream: [t.color(%COLORS<info>) => $what]
}

method doing(Str $what) {
  self.stream: [t.color(%COLORS<info>) => $what]
}

method error(Str $what) {
  self.stream: [t.color(%COLORS<error>) => $what]
}

method warn(Str $what) {
  self.stream: [t.color(%COLORS<warn>) => $what]
}

has Str $.errors;
has $.res;

method line-meta(Str $line) {
  %();
}

method line-format(Str $line) {
  $line;
}
 
method execute(:$cell) {
  ... 
}

sub format-cell($cell) {
  given $cell.^name {
    when 'Str' { $cell.fmt('%-15s ') }
    when 'Int' { $cell.fmt('%-15d ') }
    when 'Num' { $cell.fmt('%-15.4f ') }
    when 'Date' { $cell.yyyy-mm-dd }
    when 'DateTime' { $cell.truncated-to('second').Str }
    when 'Bool' { $cell ?? 'true'.fmt('%-15s ') !! 'false'.fmt('%-15s ') }
    when 'Nil' { 'NULL' }
    default  { $cell.raku.fmt('%-15s ') }
  }
}

sub format-row(@row) {
  @row.map({ format-cell($_) })
}

multi method output-duckie(Duckie::Result $result-set) {
  my $table = Prettier::Table.new(
    field-names => $result-set.column-names,
  );
  for $result-set.rows(:arrays) -> @row {
    $table.add-row(format-row(@row));
  }
  return $table.gist;
}

multi method output-duckie(IO::Path $path) {
  $!res = Duckie.new.query("select * from read_csv('{$path}');");
  self.stream:
    txt => [ t.color(%COLORS<normal>) => 'wrote to ', t.color(%COLORS<button>) => "[{ $path.basename }]" ],
    meta => %( action => 'do_output', :$path );

  return self.output-duckie($!res);
}

