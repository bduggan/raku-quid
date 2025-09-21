use Quid::Plugin;
use Log::Async;
use Terminal::ANSI::OO 't';
use Quid::Conf;

unit class Quid::Plugin::HTML does Quid::Plugin;

has $.name = 'html';
has $.description = 'Display some HTML';
method output-ext { 'html' }

method execute(:$cell, :$mode, :$page) {
  $cell.get-content(:$mode, :$page) ==> spurt $cell.output-file;
  shell <<open { $cell.output-file } 2>/dev/null>>;
}
