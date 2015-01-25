#!/usr/bin/perl
# TODO:
#  add IP's to posts
#  add IP's to accounts
#  add sticky threads
#  remove public core dumps
use warnings;
use strict;
use Plack::Request;
use DBI;
use Data::Dumper qw(Dumper);
$Data::Dumper::Sortkeys = 1;
use HTML::Escape qw(escape_html);

# App uri and name are used in the main loop and to write out proper links
my $app_uri	 = '';
my $app_name	 = 'board';
my $disp_threads = 15;	# -1 for all
my $disp_posts	 = 20;	# -1 for all
my $max_post_length = 5000;

my $dbfile = 'boards.db';	# Boards database
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile",
	"", "",
	{RaiseError=>1},
) or die $DBI::errstr;

sub list_threads {
	my $response = "";
	my $sth = $dbh->prepare("SELECT * FROM threads ORDER BY mtime DESC LIMIT ?");
	$sth->execute($disp_threads);

	my $threads;
	while($threads = $sth->fetchrow_hashref()) {
		$response .= "<a href=\"$app_uri/$app_name/$threads->{id}/\"><p>$threads->{topic}</p></a>\n";
		$response .= "<p class=\"meta\">by $threads->{author}";
		$response .= " last post $threads->{mtime}" if ($threads->{mtime});
		$response .= "</p>\n";
	}

	$response .= "<br />\n";
	$response .= "<input type=\"submit\" value=\"New thread\" onclick=\"document.getElementById('form').style.display='';return false;\">\n";
	$response .= "<form name=\"newThreadForm\" action=\"new_thread\" method=\"post\" id=\"form\">";
	$response .= "Title: <input name=\"title\" /> \n";
	$response .= "Username: <input name=\"username\" /> \n";
	$response .= "<input type=\"submit\" value=\"Post\" />\n";
	$response .= "</form>\n";

	$sth->finish();
	return $response;
}

sub get_thread {
	my $thread = shift;
	my $response = "";
	my $sth = $dbh->prepare("SELECT * FROM posts WHERE THREAD = ? AND hidden IS NULL ORDER BY id ASC LIMIT ?");
	$sth->execute($thread, $disp_posts);

	my $posts;
	while($posts = $sth->fetchrow_hashref()) {
		$response .= "<p class=\"meta\">Posted by $posts->{author} on $posts->{ctime}<p>\n";
		$response .= "<p class=\"post\">$posts->{post}</p>\n\n";
	}

	#if ($response) {
		$response .= "<br />\n";
		$response .= "<input type=\"submit\" value=\"New post\" onclick=\"document.getElementById('form').style.display='';return false;\">\n";
		$response .= "<form name=\"replyForm\" action=\"reply\" method=\"post\" id=\"form\">\n";
		$response .= "Username: <br /><input name=\"username\" /><br />\n";
		$response .= "<textarea name=\"post\" cols=\"60\" rows=\"7\" maxlength=\"$max_post_length\"></textarea><br />\n";
		$response .= "<input type=\"submit\" value=\"Post\" />\n";
		$response .= "</form>\n";
	#}

	$sth->finish();
	return $response || "No thread found<br />\n";
}

sub new_post {
	# FIXME: Display some 'working' message before redirect
	my $env = shift;
	my $thread = shift;
	my $req = Plack::Request->new($env);
	my $response = "";

	# Enforce our $max_post_length rule. 
	# Select 0-$max_post_length characters along a word boundary and group it.
	# Treat the whole string as a single line.
	(my $post) = ($req->param('post') =~ /^(.{0,$max_post_length})\b.*$/s);
	# Empty usernames default to Anonymous Coward
	# Empty posts default to bumps
	my $sth = $dbh->prepare("INSERT INTO posts (thread,post,author) VALUES(?,?,?)");
	$sth->execute($thread, escape_html($post) || "<i class=\"meta\">bump</i>", escape_html($req->param('username')) || "Anonymous Coward");

	$sth->finish();
	return $response;
}

sub new_thread {
	# FIXME: Display some 'working' message before redirect
	my $env = shift;
	my $req = Plack::Request->new($env);
	my $response = "";

	# Empty usernames default to Anonymous Coward
	# Empty threads are useless, just abort
	if ($req->param('title')) {
		my $sth = $dbh->prepare("INSERT INTO threads (topic,author) VALUES(?,?)");
		$sth->execute(escape_html($req->param('title')), escape_html($req->param('username')) || "Anonymous Coward");
		$sth->finish();
	}

#	# FIXME: Huge race here
#	$sth = $dbh->prepare("SELECT id FROM threads ORDER BY ctime DESC LIMIT 1");
#	$sth->execute();
#
#	return &get_thread($sth->fetch());

	return &list_threads();
}

sub throw_404 {
	return [404, ['Content-Type'=>'text/html'], ['404 Not Found']];
}

my $app = sub {
	my $env = shift;
	my $page = "";
	#print Dumper($env) . "\n";	# Log the incoming headers

	$page .= "<html>
		<head>
			<title>boards</title>
			<link rel=\"stylesheet\" href=\"main.css\">
		</head>\n";
	$page .= "<body onload=\"document.getElementById('form').style.display='none';return false;\">
		<div class=\"container\">
		<div class=\"site\">
		<div class=\"header\">
			<h1 class=\"title\"><a href=\"$app_uri/$app_name/\">boards</a></h1>
			<a class=\"extra\" href=\"#\">stuff</a>
		</div>";
	$env->{PATH_INFO} =~ s/$app_uri\/$app_name//;
	if ($env->{PATH_INFO} eq '/') {
		# Root of the app, thread index goes here
		$page .= &list_threads();
	} elsif (my ($css_file) = ($env->{PATH_INFO} =~ /.*\/(.+?\.css)$/)) {
		# Serve up our css manually so we don't rely on the web server
		# Needs to be at the top of the chain to catch sub paths
		open my $fh, "<", $css_file or return &throw_404();
		return [200, ['Content-Type'=>'text/css'], $fh];
	} elsif ($env->{PATH_INFO} =~ /new_thread$/ && $env->{REQUEST_METHOD} eq 'POST') {
		# We only care about POSTs, don't let people come here with a GET
		$page .= new_thread($env);
	} elsif (my ($thread) = ($env->{PATH_INFO} =~ /^\/(\d+)/)) {
		# Assign the regex groups (\d+) to the variables list
		# Hijack /reply links
		# Then fall through to display the thread with the new post
		# We only care about POSTs, don't let people come here with a GET
		# FIXME: double-post protection
		$page .= new_post($env, $thread) if ($env->{PATH_INFO} =~ /reply$/ && $env->{REQUEST_METHOD} eq 'POST');
		# Grab a list of threads that corresponds to our forum
		$page .= &get_thread($thread);
	} else {
		# Send everything else a 404 page
		return &throw_404();
	}
	$page .= "</div></div></body></html>";

	return [200, ['Content-Type'=>'text/html'], [$page]];
};
