#!/usr/bin/perl
#
# ncsa-cert-retrieve-trans.pl
#
# This is the first version of ncsa-cert-retrieve in perl.  This is going
# to be mighty similar to the shell script version.  After this is gotten
# to a working state, a huge overhaul will make this into good perl code,
# and include some major changes that will take into account the need for
# modularity so that others may take this script and adapt it for their 
# CA needs.

use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use Cwd;

$version="0.4.2";
$progname = $0;
$progname =~ s|.*/||g;

# Verify that GLOBUS_LOCATION is set
# If not, then die.
$gpath = $ENV{GLOBUS_LOCATION};
if (!defined($gpath)) {
  die "GLOBUS_LOCATION needs to be set before running this script";
}

#### OK, here we set tons of variables ####

$secconfdir="/etc/grid-security";

#SSL related needs
$ssl_exec = "$gpath/bin/openssl";

# $ca_config is $gpath/share/gsi_ncsa_ca_tools/ncsa-ca.conf
# so $datadir should resolve to the share directory in $gpath
$ca_config = "$gpath/share/gsi_ncsa_ca_tools/ncsa-ca.conf";

$default_cert_file = "cert.pem";
$default_key_file = "key.pem";

# User's home directory
$userhome = $ENV{HOME};
# which is needed for $default_dir, which is just below this...

# Changing location of retrieved certs so that they can move certs
# wherever they want, and no accidental overwrites of existing certs
# in ~/.globus happens
$default_dir = "$userhome/.certs";

#$def_request_file = "req.pem";
#$def_request_id_file = "request_id";

#$def_ldap_cert_file = "ldapservercert.pem";
#$def_ldap_key_file = "ldapserverkey.pem";
#$def_ldap_request_file = "ldapservercert_req.pem";
#$def_ldap_request_id_file = "ldap_request_id";

$contact_email_addr = "consult\@alliance.paci.org";
$contact_url = "http://www.ncsa.uiuc.edu/UserInfo/Alliance/GridSecurity/";
$user_agent="ncsa-cert-request/$version";

# By default, nocheck is 1, and if specified on the cmd line can be set to
# 0.  if nocheck is 1, then checkState is run later on -- this is a simple
# sanity check.
#
# For now, must leave nocheck = 0 in all cases, as we have not figure out a
# good way to check the state of the system yet.
$nocheck = 0;

########
#      #
# MAIN #
#      #
########

# Main is pretty easy:
#    1) read cmd-line options
#    2) deal with them appropriately
#    3) check the system to make sure it can do proper OpenSSL stuff
#    4) get the certificate

### READ COMMAND LINE OPTIONS ###

GetOptions ( 'dir=s' => \$cl_dir,
	     'id=s'  => \$request_id,
	     'nocheck' =>
	     sub { $nocheck = 0; },
	     'cert=s' => \$cl_cert_file,
	     'key=s' => \$cl_key_file,
	     'version' => \$versionopt,
	     'help|?' => \$help,
	     'man' => \$man,
	     ) or pod2usage(2);

### DEAL WITH COMMAND LINE OPTIONS ###

if ($versionopt) {
  print "$progname Version $version\n";
  exit;
}

pod2usage(1) if $help;

pod2usage('exitval' => 0, '-verbose' => 2) if $man;

if (!$request_id) {
  print "
Please supply the serial number of your certificate as contained in the
email you received from the CA. (Note that this is not the same as the
request number you got when submitting your certificate.)

For example, if your certificate is serial number 45, please run:

$progname -id 45

If you want assistance please email $contact_email_addr
or visit

$contact_url\n";

exit;
}

# This is where nocheck may eventually be used to run checkState,
# or some other sanity checking dealie

# if ($nocheck) { print "i will run checkState here eventually.\n"; }

# If no command line args specify cert_file and/or key_file,
# set them to undef, so that we can just pass the empty guys 
# to preparePathsHash and determinePaths
if (! $cl_cert_file) { $cl_cert_file = undef; }
if (! $cl_key_file) { $cl_key_file = undef; }

# Figure out if we are using command line or default files and/or
# directories.  All these values are stored in the hash $files

$cl_files = preparePathsHash($cl_dir, $cl_cert_file, $cl_key_file);
$default_files = preparePathsHash($default_dir, $default_cert_file, $default_key_file);
$files = determinePaths($default_files, $cl_files);

# Pull the values out of $files hash and set them up as easy to
# remember variables for use throughout the rest of the script

$cert_file = $files->{'cert_file'};
$key_file = $files->{'key_file'};

checkGlobusSystem();

getCertificate();

exit;

##########################
##########################
###                    ###
###       SUBS         ###
###                    ###
##########################
##########################

###############################
#                             #
# inform                      #
#                             #
# Inform the user of an event #
#                             #
###############################
sub inform {
  my ($content, $override) = @_;
  print "$content\n" if $verbose or defined $override;
}

############################################
#                                          #
# action                                   #
#                                          #
# Perform some command and inform the user #
#                                          #
############################################
sub action {
  my ($command, $dir) = @_;
  my $pwd;

  if (defined $dir) {
    $pwd = cwd();
    inform("Changing to $dir");
    chdir $dir;
  }

  # Log the step
  inform($command);

  # Perform the step
  my $result = system("$command 2>&1");

  if ($result or $?) {
    # results are bad print them out.
    die "ERROR: Command failed\n";
  }

  if (defined $dir) {
    inform("Changing to $pwd");
    chdir $pwd;
  }
}

#################################
#                               #
# cleanup                       #
#                               #
# Usage: cleanup($f1, $f2, ...) #
# If the file exists, this      #
# script deletes it             #
#                               #
#################################
sub cleanup {
  my @items = @_;

  for ($i=0; $i<@items;$i++) {
    if (-f "$items[$i]") {
      action("rm $items[$i]");
    }
  }
}

########################################################
#                                                      #
# absolutePath                                         #
#                                                      #
# Takes and array as input, prepends the cwd to the    #
# filename if the filename does not start with a /,    #
# then returns an array containing files with absolute #
# pathnames.                                           #
#                                                      #
# *note* because absolutePath takes an array as input, #
# to use it on a single variable, you need to do it in #
# the following way: ($abs_path) = absolutePath($file) #
#                                                      #
########################################################

sub absolutePath {
  my @files = @_;

  # It seems like getting the CWD out of ENV is probably more standard
  # across platforms than trying to guess where pwd is or assuming
  # it's in $PATH.  I know it's almost always in /bin, but there's
  # always that one odd case that no one can foresee.
  #my $cwd = $ENV{'PWD'};
  #chomp ($cwd);

  # cwd() is included in the Cwd PM.  This only works if you have
  # use Cwd; at the top.
  my $cwd = cwd();

  for ($i=0;$i<@files;$i++) {
    if ($files[$i] !~ /^\//) {
      $files[$i] = $cwd."/".$files[$i];
    }
  }

  return @files;
}

################################################
#                                              #
# printPostData                                #
#                                              #
# Takes two strings as input, it returns the   #
# concatenation of the first and a url-encoded #
# second                                       #
#                                              #
################################################

sub printPostData {
  my ($var, $value) = @_;
  my ($str);

  # special characters %, @, &, and space (" ") are given their appropriate
  # corresponding hex values for proper transmission via HTTP
  #
  # since true url-encoding involves translating a great many more characters,
  # let's hope we don't hit any snags in that area.  we should fix this by
  # using CGI::Enurl or writing a big honkin' url-encoding function.  more
  # info is available at:
  #
  # <http://search.cpan.org/search?dist=CGI-Enurl>
  # <http://www.w3.org/International/O-URL-code.html>
  #

  $value =~ s/%/%25/g;
  $value =~ s/@/%40/g;
  $value =~ s/&/%26/g;
  $value =~ s/ /+/g;

  $str = "$var=$value";

  return $str;
}




###############################################
#                                             #
# longUsage                                   #
#                                             #
# print out long (verbose) usage instructions #
#                                             #
###############################################

sub longUsage {
  print "$short_usage\n";
  print "Options:\n";
  print "\t-dir <dir_name>\t: User certificate directory [\'$def_globus_dir \']\n";
  print "\t-nocheck\t: Don\'t do sanity checks on certificate\n";
}


###############################################
#                                             #
# checkState                                  #
#                                             #
# Sanity check to make sure we look ok to get #
# the certificate.                            #
#                                             #
###############################################

sub checkState {
  my $error = 0;

  # Does key file exist and is it readable?
  if (! -r $key_file) {
    print "Key file does not exist:  $key_file\n";
    $error = 1;
  }

  # Does Request ID file exist and is it readable?
  if (! -r $request_id_file) {
    print "Request ID file does not exist:  $request_id_file\n";
  }

  # If no error, return, else print error message and die
  if (! $error) {
    return;
  }
  else {

    # This is a good candidate of having a file of these messages be
    # separate and outside of this script.  Then we can just go get
    # the message, and print it.  This also saves people from editing
    # this script to change the message -- that way there are no
    # accidental breakings of this script when people put in stray
    # characters, delete the wrong line, etc.

    my $error_message =
"The above errors indicate that you are not prepared to
download a certificate.

Possibly you have not submited a certificate request with
ncsa-cert-request?

Did you specify a non-standard directory with -dir? In which
case you need to specify this same directory with
$progname

If you want assistance please email $contact_email_addr
or visit

$contact_url";

      die "$error_message\n";
  }
}

#############################
#                           #
# handleFailedRetrieve      #
#                           #
# Handle a failed retrieval #
#                           #
#############################
sub handleFailedRetrieve {
  my $post_out_file = shift;

  my $support_url = "http://www.ncsa.uiuc.edu/UserInfo/Alliance/GridSecurity/Support/";
  my $error_message =
    "The attempt to retrieve your certificate failed.

If you have not receive notification from the CA that
your certificate is ready, then it probably isn't and
you should wait until you receive notifcation and try
again.

If you have received notification from the CA that your
certificate is ready, then some other failure occurred.
This file contains a log of the session with the CA:

$post_out_file

You can examine it for the reason for the failure.
Please include this file with any correspondence
you have regarding this problem.

If you want assistance please email $contact_email_addr
or visit:

$support_url";

  print "$error_message\n";
}

# globusArgsShortUsage
sub globusArgsShortUsage {
  print "Syntax: $short_usage\n";
  print "\n";
  print "Use -help to display full usage.\n";
}

# globusArgsOptionError
sub globusArgsOptionError {
  my ($option, $error) = @_;

  print "Error, argument $option : $error\n";
  globusArgsShortUsage();
  die "\n";
}

# globusArgsUnrecognizedOption
sub globusArgsUnrecognizedOption {
  my ($option) = shift;

  globusArgsOptionError($option, "unrecognized option");
}

#########################################
#                                       #
# handleNewCert                         #
#                                       #
# Check and install the new certificate #
#                                       #
#########################################
sub handleNewCert {
  my $new_cert = shift;
  my $get_started_url = "http://www.ncsa.uiuc.edu/UserInfo/Alliance/GridSecurity/Certificates/Go2.html#test";

  print "Installing new certificate in $cert_file\n";

  action("mv $new_cert $cert_file");
  action ("chmod 644 $cert_file");

  my $success_message =
    "You have successfully retrieved your Alliance Certificate.
Please see the following url for information on how to get
started using your certificate:

$get_started_url";

  print "\n$success_message\n";

}

####################################################
#                                                  #
# checkGlobusSystem                                #
#                                                  #
# Ensure that the NCSA OpenSSL Configuration files #
# have been created by the Globus Sys.Admin        #
#                                                  #
####################################################
sub checkGlobusSystem {

  my $phrase = "Not Configured";
  my $error_message =
    "The NCSA Configuration files have not been setup.
Please have your system administrator install the
the gsi_ncsa_ca_setup package.";

  #  $/ = undef;
  local $/;
  open (FILE, $ca_config) || die "can't open $ca_config";
  my $contents = <FILE>;
  close (FILE);

  if ($contents =~ /$phrase/) {
    die "$error_message\n";
  }

}

#########################################
#                                       #
# getCertificate                        #
#                                       #
# Get the certificate from the NCSA CA. #
#                                       #
#########################################
sub getCertificate {

  my $tmpdir = "/tmp";
  my $server = "ca.ncsa.edu";
  my $port = "443";
  my $page = "/displayBySerial";

  print "Getting certificate $request_id from CA\n";

  # Temporary files
  my $post_data_file = "$tmpdir/$progname.$$.post_data";
  my $post_cmd_file = "$tmpdir/$progname.$$.post_cmd";
  my $post_out_file = "$tmpdir/$progname.$$.post_out";
  my $tmp_cert_file = "$tmpdir/$progname.$$.cert";

  action("rm -f $post_data_file");

  ### Build the post data
  my $tmpvar;
  open (POST_DATA_FILE, ">>$post_data_file") || die "can't open $post_data_file";

  $tmpvar = printPostData("op", "displayBySerial");
  print POST_DATA_FILE "$tmpvar";
  print POST_DATA_FILE "&";

  $tmpvar = printPostData("serialNumber", "$request_id");
  print POST_DATA_FILE "$tmpvar";
  print POST_DATA_FILE "&";

  $tmpvar = printPostData("submit", "Details");
  print POST_DATA_FILE "$tmpvar";
  print POST_DATA_FILE "\n\n";

  close (POST_DATA_FILE);

  # Get number of bytes we are posting
  my $len = -s $post_data_file;


  # Now build the actual text for sending to the web server
  open (POST_CMD_FILE, ">$post_cmd_file") || die "can't open $post_cmd_file";

  print POST_CMD_FILE "POST $page HTTP/1.0\n";
  print POST_CMD_FILE "Content-type: application/x-www-form-urlencoded\n";
  print POST_CMD_FILE "Content-length: $len\n";
  print POST_CMD_FILE "User-Agent: $user_agent\n";
  print POST_CMD_FILE "\n";
  open (POST_DATA_FILE, "$post_data_file") || die "can't open $post_data_file";
  while (<POST_DATA_FILE>) {
    print POST_CMD_FILE "$_";
  }
  close (POST_DATA_FILE);
  close (POST_CMD_FILE);

  action("rm -f $post_data_file");

  # Sleep to give server a chance to respond
  # action("(cat $post_cmd_file; sleep 10) | $ssl_exec s_client -quiet -connect $server:$port > $post_out_file 2>&1");

  # Don't actually need the sleep command.  It works w/o it fine.  Not sure
  # why it was in there.
  action("cat $post_cmd_file | $ssl_exec s_client -quiet -connect $server:$port > $post_out_file 2>&1");

  #  $/ = "\n";
  open (POST_OUT_FILE, "$post_out_file") || die "can't open $post_out_file";
  while (<POST_OUT_FILE>) {
    if ($_ =~ /certChainBase64 =/) {
      my @tmparray = split (/\"/, $_);
      $cert_data = $tmparray[1];
    }
  }
  close (POST_OUT_FILE);

  if (length ($cert_data) > 0) {
    action("rm -f $post_out_file");
    open (TMP_CERT_FILE, ">$tmp_cert_file") || die "can't open $tmp_cert_file";
    print TMP_CERT_FILE "-----BEGIN CERTIFICATE-----\n";
    print TMP_CERT_FILE "$cert_data\n";
    print TMP_CERT_FILE "-----END CERTIFICATE-----\n";
    close (TMP_CERT_FILE);

    handleNewCert($tmp_cert_file);
  }
  else {
    handleFailedRetrieve($post_out_file);

    # Append the $post_cmd_file to the $post_out_file
    # so that it can be used for debugging
    open (POST_OUT_FILE, ">>$post_out_file") || die "can't open $post_out_file";
    open (POST_CMD_FILE, "$post_cmd_file") || die "can't open $post_cmd_file";
    while (<POST_CMD_FILE>) {
      print POST_OUT_FILE "$_";
    }
    close (POST_OUT_FILE);
    close (POST_CMD_FILE);
  }

  action("rm -f $post_cmd_file");
}


### preparePathsHash( $dir, $my_cert_file, $my_key_file )
#
# create a hash based on the arguments passed to the subroutine
#

sub preparePathsHash {
  my ($dir, $my_cert_file, $my_key_file ) = @_;
  my $hash = {};

  $hash->{'dir'} = $dir;
  $hash->{'cert_file'} = $my_cert_file;
  $hash->{'key_file'} = $my_key_file;

  return $hash;
}

### determinePaths( $default_files, $cl_files )
#
# based on the hashes we're given, return a hash which contains the correct set
# of files (possibly containing a mixture of default- and commandline-specified
# files)
#

sub determinePaths {
  my ( $default_files, $cl_files ) = @_;
  my ( $my_cert_file );
  my ( $files );

  $files = {};

  # determine dir

  $tmp_dir = $cl_files->{'dir'};
  $tmp_dir =~ s:^[\s]+|[\s]+$::g;
  if ( defined($tmp_dir) ) {
    $dir = $tmp_dir;
  }
  else {
    $dir = $default_files->{'dir'};
  }

  if ( length($dir) == 0 ) {
    printf("no directory specified!\n");
    exit;
  }

  if ( ! grep(/^\//, $dir) ) {
    # make $tmp_dir an absolute path
    $dir = cwd() . "/" . $dir;
  }

  # create if it doesn't exist
  if ( ! -e $dir ) {
    makeDir($dir);
  }

  #
  # divine the path to the certificate file
  #

  $tmp = determineFile($default_files->{'cert_file'}, $cl_files->{'cert_file'}, "certificate file");
  $files->{'cert_file'} = $dir . "/" . $tmp;

  #
  # divine the path to the key file
  #

  $tmp = determineFile($default_files->{'key_file'}, $cl_files->{'key_file'}, "key file");
  $files->{'key_file'} = $dir . "/" . $tmp;

  return $files;
}

### determineFile( $default, $cl, $name )
#
# choose between the default- and the commandline-specified file.
# error out if we can't write to our choice.
#

sub determineFile {
  my ($default, $cl, $name) = @_;
  my ($tmp_file);

  #
  # if we were passed a commandline choice,
  # make sure that it's not just whitespace
  #

  $tmp_file = $cl;
  if ( defined($tmp_file) ) {
    $tmp_file =~ s:^[\s]+|[\s]+$::g;
  }
  else {
    $tmp_file = $default;
  }

  if ( length($tmp_file) == 0 ) {
    printf("no $name specified!\n");
    exit;
  }

  #
  # check that the chosen file doesn't have any slashes in it (isn't a path)
  #

  if ( grep(/\//, $tmp_file) ) {
    printf("$name can only be a filename!\n");
    exit;
  }

  #
  # check that, if our choice exists, we can write to it
  #

  if ( ( -e $tmp_file ) && ( ! -w $tmp_file ) ) {
    printf("can't write to $tmp_file");
    exit;
  }

  return $tmp_file;
}

### makeDir( $path )
#
# creates the directory structure in $path if it doesn't already exist
#

sub makeDir {
  my ($path) = @_;
  my (@dirs, $curr_dir);

  if ( ! -e $path ) {
    #
    # break the directories apart
    #

    @dirs = split(/\//, $path);

    for my $d (@dirs) {
      #
      # if the current directory is non-null
      #

      if ( length($d) gt 0 ) {
	$curr_dir = $curr_dir . "/" . $d;

	if ( ! -e $curr_dir ) {
	  mkdir($curr_dir) || die "can't make directory $curr_dir: $!\n";
	}
      }
    }
  }
}

##########################
##########################
###                    ###
###     END SUBS       ###
###                    ###
##########################
##########################

__END__

#####################
#                   #
# Pod Documentation #
#                   #
#####################

=head1 NAME

ncsa-cert-retrieve - Retrieve a certificate from the NCSA certificate authority

=head1 SYNOPSIS

ncsa-cert-retrieve [options] -id <id_number>

=head1 OPTIONS

=over 8

=item B<--dir=<dir_name>>

=item B<--cert=<file>>

=item B<--key=<file>>

=cut

# Cutting this option out of the pod docs for now, as it is 
# unimplemented in this version of the script

#=item B<--nocheck>>
#
#Attempt retrieval without checking system to make sure everything is correct to retrieve the certificate

=pod

=item B<--version>

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.


=back

=head1 DESCRIPTION

B<ncsa-cert-retrieve> will retrieve a certificate from the NCSA certificate
authority.

You can specify to B<ncsa-cert-retrieve> the name of the B<certificate file>, B<key file>, and/or the B<directory> they will be placed in.  If none of these are specified with the command line flags and arguments, default settings will be used.  Currently, these are:

      certificate: cert.pem

      key:         key.pem

      directory:   ~/.certs

If using the default directory, after you successfully retrieve your certificate, you must move the certificate to the appropriate place on your system, so that it may be used by Globus.

=head1 AUTHORS

 Joe Greenseid <jgreen@ncsa.uiuc.edu>,
 Chase Phillips <cphillip@ncsa.uiuc.edu>

=cut
