use Quid::Plugin;
use Log::Async;
use LLM::DWIM;

unit class Quid::Plugin::LLM does Quid::Plugin;

has $.name = 'llm-dwim';
has $.description = 'Execute text using LLM::DWIM';

has $.wrap = 'word';

method execute(:$cell, :$mode, :$page) {
 info "Executing LLM cell";
 my Str $content = $cell.get-content(:$mode, :$page);
 my $h = &warn.wrap: -> |c {
   warning "LLM warning: {c.raku}";
 }
 $!output = dwim($content);
 $h.restore;
}
