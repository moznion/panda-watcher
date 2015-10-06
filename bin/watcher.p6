use v6;
use HTTP::Tinyish;
use JSON::Faster;
use Log::Minimal;
use DBIish;

my constant $http = HTTP::Tinyish.new(agent => 'panda-watcher/1.0');
my constant $log = Log::Minimal.new;
my constant $dbh = DBIish.connect('SQLite', :database<db.sqlite3>, :RaiseError);

my $exit_code = shell 'rakudobrew build moar && rakudobrew build-panda';
if $exit_code != 0 {
    $log.errorf('Failed to build moar and panda');
}

$dbh.do(q:to/STATEMENT/);
    DROP TABLE IF EXISTS modules
STATEMENT

$dbh.do(q:to/STATEMENT/);
    CREATE TABLE IF NOT EXISTS modules (
        name    VARCHAR(30) NOT NULL PRIMARY KEY,
        url     VARCHAR(100) NOT NULL,
        status  INT(1) NOT NULL DEFAULT 2 -- 0: succeeded, 1: failed, 2: unknown
    )
STATEMENT

$dbh.do(q:to/STATEMENT/);
    CREATE INDEX status ON modules(status)
STATEMENT

my %res = $http.get("https://raw.githubusercontent.com/perl6/ecosystem/master/META.list");
%res<content>.split(/\n/).map(-> $url {
    $log.infof($url);
    my %meta = from-json($http.get($url)<content>);

    my $module-name = %meta<name>;
    my $source-url = %meta<source-url>;

    my ($user-name, $repo-name) = $source-url.split(rx!'/'!)[3..4];
    my $repo-url = "https://github.com/$user-name/$repo-name";

    my $status;
    my $exit_code = shell "panda install $source-url";
    if $exit_code == 0 {
        $status = 0;
    } else {
        $status = 1;
    }

    my $sth = $dbh.prepare(q:to/STATEMENT/);
        INSERT INTO modules (name, url, status)
        VALUES (?, ?, ?)
    STATEMENT
    $sth.execute($module-name, $repo-url, $status);

    CATCH {
        default {
            $log.warnf('Something wrong (url: %s)', $url);
            if $module-name && $repo-url {
                my $sth = $dbh.prepare(q:to/STATEMENT/);
                    INSERT INTO modules (name, url, status)
                    VALUES (?, ?, ?)
                STATEMENT
                $sth.execute($module-name, $repo-url, 2);
                $log.warnf('Status unknown (%s: %s)', $module-name, $repo-url);
            }
        }
    }
});
