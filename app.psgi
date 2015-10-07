use v6;
use Crust::Request;
use Template::Mojo;
use DBIish;

my constant $dbh = DBIish.connect("SQLite", :database<db.sqlite3>, :RaiseError);

my $sth = $dbh.prepare(q:to/STATEMENT/);
    SELECT * FROM modules ORDER BY name ASC
STATEMENT

my $tmpl = Template::Mojo.new(q:heredoc/END/);
% my (@modules) = @_;
<!doctype html>
<html>
  <head>
    <title>Panda Watcher</title>
  </head>
  <body>
    <h1>Panda Watcher</h1>
    <p>Today's instalation status of perl6 modules</p>
    <table>
    % for @modules -> $module {
      % my $status = @$module[2];
      % my $badge-url;
      % if $status == 0 {
      %   $badge-url = "https://img.shields.io/badge/install-success-green.svg?style=flat";
      % } elsif $status == 1 {
      %   $badge-url = "https://img.shields.io/badge/install-fail-red.svg?style=flat";
      % } else {
      %   $badge-url = "https://img.shields.io/badge/install-unknown-lightgrey.svg?style=flat";
      % }
      <tr>
        <td><a href="<%= @$module[1] %>"><%= @$module[0] %></a></td>
        <td><img src=<%= $badge-url %>></td>
      <tr>
    % }
  <table>
  </body>
</html>
END

sub app($env) {
    my $req = Crust::Request.new($env);

    if $req.path-info eq '/' {
        $sth.execute();
        my $modules = $sth.fetchall_arrayref();
        my $content = $tmpl.render(@$modules).encode('utf-8');
        return [200,
            [
                'Content-Type' => 'text/html; charset=utf-8'
            ],
            [$content]
        ];
    }
}
