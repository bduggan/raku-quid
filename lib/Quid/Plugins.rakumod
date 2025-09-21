unit class Quid::Plugins;
use Quid::Conf;
use Log::Async;
use Quid::Plugin;

has @.rules;

method configure(Quid::Conf $conf) {
  @.rules = $conf.plugins;
}

method get(Str $name) {
  my $found = @!rules.first: { my $r := .<regex>; $name ~~ $r };
  return $found<handler> if $found;
  fail "No suitable plugin found for name: $name";
}

method list-all {
  return @!rules.map: {
    %(
    regex => .<regex>,
    name => .<handler>.name,
    desc => .<handler>.description
    )
  }
}

