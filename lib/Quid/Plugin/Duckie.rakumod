use Quid::Plugin;
use Log::Async;
use Duckie;

unit class Quid::Plugin::Duckie does Quid::Plugin;

has $.name = 'duckie';
has $.description = 'Use in-line duckdb driver for queries';

has $.db = Duckie.new;

method execute(:$cell, :$mode, :$page) {
 info "Executing LLM cell";
 my $content = $cell.get-content(:$mode, :$page);
 $!res = $.db.query($content);
 $!output = self.output-duckie($!res);
}
