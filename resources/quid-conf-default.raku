# quid-conf.raku
#
%*quid-conf =
  plugins => [
    / duck /   => 'Quid::Plugin::Duck',
    / llm  /   => 'Quid::Plugin::LLM',
    / text /   => 'Quid::Plugin::Text',
    / bash /   => 'Quid::Plugin::Bash',
    / html/    => 'Quid::Plugin::HTML',
  ],
  plugouts => [
    / csv  /   => 'Quid::Plugout::Duckview',
    / csv  /   => 'Quid::Plugout::DataTable',
    / html /   => 'Quid::Plugout::HTML',
    / .*   /   => 'Quid::Plugout::Raw',
  ]
;

