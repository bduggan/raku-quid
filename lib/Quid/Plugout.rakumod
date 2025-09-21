unit role Quid::Plugout;

has $.pane is rw;
has $.output; # optional: string or array
has $.clear-before = True;

method setup { }

method escape($html) {
  return '' unless defined $html;
  $html.Str.subst('&', '&amp;', :g)
       .subst('<', '&lt;', :g)
       .subst('>', '&gt;', :g)
       .subst('"', '&quot;', :g)
       .subst("'", '&#39;', :g);
}


method shell-open($file) {
  shell "open $file 2>/dev/null";
}
