#!/usr/bin/perl
#
# ncsa-cert-request.pl
#
# Generate a certificate request which can be sent to the NCSA CA, who may
# subsequently sign it.  This script uses ncsa-ca.conf.
#
# When generating a certificate request for cert types gatekeeper, host,
# and ldap, the -nopw option is simulated.  This guarantees that the key
# is not protected by a passphrase.
#
# note: variable binding is something that is just _dying_ to be cleaned
#       up in this script.
#
### License info
#
# ncsa-cert-request is Copyright 2002 The Board of Trustees of the University
# of Illinois.
#
# All rights to ncsa-cert-request are held by the authors, the National
# Center for Supercomputing Applications and the University of Illinois.
#
# You may freely distribute ncsa-cert-request in any form as along as
# it is accompanied by this license.
#
# You may freely use ncsa-cert-request for non-commercial applications.
# You are asked, but not required, to inform the authors if you use
# ncsa-cert-request.
#
# You may freely modify ncsa-cert-request and redistribute with your
# changes as long as you clearly indicate that you have made changes
# and describe your changes, preferably in a separate README file.
# Modifications to ncsa-cert-request do not effect this license.
#

use Getopt::Long;
use Pod::Usage;
use Cwd;

#
# the upper portion of this file consists of global variable defines.
#

#
# verify that globus location is set
#

$gpath = $ENV{GLOBUS_LOCATION};
if (!defined($gpath))
{
    die("GLOBUS_LOCATION needs to be set before running this script\n");
}

my ($versionid, $program_name);

$versionid = "0.4.6";
$program_name = $0;
$program_name =~ s|.*/||g;

#
# variables which will hold our arguments
#

my (
    $name, $gatekeeper, $type, $cl_dir, $cl_cert_file, $cl_key_file,
    $cl_request_file, $nopw, $interactive, $force, $resubmit, $version,
    $help, $man, $verbose
   );

#
# default values go here
#

$type = "user";
$man = 0;
$help = 0;

#
# for our authentication with the ncsa ca, we're using openssl
#

my $secconfdir = "/etc/grid-security";
my $secure_tmpdir = "/tmp";
my $ssl_exec = "$gpath/bin/openssl";
my $ca_config = "$gpath/share/gsi_ncsa_ca_tools/ncsa-ca.conf";

my $req_input = "$secure_tmpdir/req_input.$$";
my $req_output = "$secure_tmpdir/req_output.$$";
my $req_head = "$secure_tmpdir/req_header.$$";

#
# rand_temp is a filename of where we will store our seed data
#

my $rand_temp = "${secure_tmpdir}/${program_name}.$$.random";

#
# default pathnames to various directories and files
#

$userhome = $ENV{HOME};
if ( !defined($userhome) && !defined($cl_dir) )
{
    die("HOME needs to be set before running this script without the -dir flag\n");
}

$default_dir = "$userhome/.globus";
$default_cert_file = "usercert.pem";
$default_key_file = "userkey.pem";
$default_request_file = "req.pem";
$default_request_id_file = "request_id";

#
# info sent with the certificate
#

my $subject = "";
my $userid = "$>";
my $host = generateHostname();

#
# various addresses and user agents
#

my $contact_email_addr = "consult\@alliance.paci.org";
my $contact_url = "http://www.ncsa.uiuc.edu/UserInfo/Alliance/GridSecurity/";
my $user_agent = "ncsa-cert-request/$versionid";

#
# urls that give more information about submitting and completing requests
#

my $url_howto_submit = "http://www.ncsa.uiuc.edu/UserInfo/Alliance/GridSecurity/Certificates/Go.html";
my $url_howto_complete = "http://www.ncsa.uiuc.edu/UserInfo/Alliance/GridSecurity/Certificates/Go2.html\#fax";

#
# argument specification.  we offload some processing work from later functions
# to verify correct args by using anon subs in various places.
#

GetOptions( 'name=s' =>
                sub
                {
                    my ($optname, $optval) = @_;

                    $name = $optval;
                    $name =~ s:^[\s]+|[\s]+$::g;
                },
            'gatekeeper=s' => \$gatekeeper,
            'type=s' =>
                sub
                {
                    my ($optname, $optval) = @_;

                    $type = $optval;

                    if ( ($type eq "gatekeeper") || ($type eq "host") || ($type eq "ldap") )
                    {
                        $nopw = 1;
                        $no_des = "-nodes";
                    }

                    if ( ( $type ne "gatekeeper" ) && ( $type ne "host" ) && ( $type ne "ldap" ) && ( $type ne "user" ) )
                    {
                        printf("I don't know how to request a certificate of type '$type'!\n");
                        exit;
                    }
                },
            'dir=s' => \$cl_dir,
            'cert|certificate=s' => \$cl_cert_file,
            'key=s' => \$cl_key_file,
            'req|request=s' => \$cl_request_file,
            'nopw|nodes|nopassphrase' => 
                sub
                {
                    my ($optname, $optval) = @_;

                    $nopw = $optval;
                    $no_des = "-nodes";
                },
            'interactive' => \$interactive,
            'force' => \$force,
            'resubmit' => \$resubmit,
            'version' => \$version,
            'help|?' => \$help,
            'man' => \$man,
            'verbose' => \$verbose
          ) or pod2usage(2);

#
# check to see if we need to do tilde expansion on a specified command line
# directory
#

if ($cl_dir =~ /^~/)
{
    $cl_dir = tilde_expand($cl_dir);
}

#
# if version is enabled, we print our current $versionid and exit
#

if ($version)
{
    printf("$versionid\n");
    exit;
}

#
# if $help is specified, print the synopsis, options, and/or arguments sections
#

if ($help)
{
    pod2usage(1);
}

#
# if $man is specified, exit with value 0 and print the entire pod document
#

if ($man)
{
    pod2usage('-exitval' => 0, '-verbose' => 2);
}

#
# call main, and then exit
#

main($name);

exit;

#
# subroutines
#

sub tilde_expand
{
    my $dir = shift;

    ($homedir, @rest) = split (/\//, $dir);

    my $real_homedir = `/bin/echo $homedir`;
    chomp($real_homedir);

    my $expanded_path = $real_homedir;
    for (my $i=0; $i<@rest; $i++)
    {
        $expanded_path = "$expanded_path/$rest[$i]";
    }

    return $expanded_path;
}

### generateHostname( )
#
# return a FQDN-version of the local hostname
#

sub generateHostname
{
    my $host;

    $host = `$gpath/bin/globus-hostname`;
    $host =~ s:^[\n]+|[\n]+$::g;

    if (length($host) eq 0)
    {
        $host = `hostname -f`;
        $host =~ s:^[\n]+|[\n]+$::g;

        if (length($host) eq 0)
        {
            printf("Cannot determine a FQDN-version of your hostname.  Does\n");
            printf("$gpath/bin/globus-hostname exist?\n");
            exit;
        }
    }

    return $host;
}

### cleanup( $item0, $item1, ... )
#
# remove some set of files
#

sub cleanup
{
    my @items = @_;

    for my $i (@items)
    {
        if (-f "$i")
        {
            action("rm -f $i");
        }
    }
}

### preparePathsHash( $dir, $cert_file, $key_file, $request_file, $request_id_file )
#
# create a hash based on the arguments passed to the subroutine
#

sub preparePathsHash
{
    my ($dir, $cert_file, $key_file, $request_file, $request_id_file ) = @_;
    my $hash = {};

    $hash->{'dir'} = $dir;
    $hash->{'cert_file'} = $cert_file;
    $hash->{'key_file'} = $key_file;
    $hash->{'request_file'} = $request_file;
    $hash->{'request_id_file'} = $request_id_file;

    return $hash;
}

### determinePaths( $default_files, $cl_files )
#
# based on the hashes we're given, return a hash which contains the correct set
# of files (possibly containing a mixture of default- and commandline-specified
# files)
#

sub determinePaths
{
    my ( $default_files, $cl_files ) = @_;
    my ( $cert_file );
    my ( $files );

    $files = {};

    # determine dir

    $tmp_dir = $cl_files->{'dir'};
    if ( defined($tmp_dir) )
    {
        $dir = $tmp_dir;
    }
    else
    {
        $dir = $default_files->{'dir'};
    }

    $dir =~ s:^[\s]+|[\s]+$::g;
    if ( length($dir) == 0 )
    {
        printf("no directory specified!\n");
        exit;
    }

    # make $tmp_dir an absolute path if need be
    $dir = absolutePath($dir);

    # create $dir if it doesn't exist
    makeDir($dir);

    #
    # derive the path to the certificate file
    #

    $tmp = determineFile($default_files->{'cert_file'}, $cl_files->{'cert_file'}, "certificate file");
    $files->{'cert_file'} = $dir . "/" . $tmp;

    #
    # derive the path to the key file
    #

    $tmp = determineFile($default_files->{'key_file'}, $cl_files->{'key_file'}, "key file");
    $files->{'key_file'} = $dir . "/" . $tmp;

    #
    # derive the path to the request file
    #

    $tmp = determineFile($default_files->{'request_file'}, $cl_files->{'request_file'}, "request file");
    $files->{'request_file'} = $dir . "/" . $tmp;

    #
    # derive the path to the request file
    #

    $tmp = determineFile($default_files->{'request_id_file'}, $cl_files->{'request_id_file'}, "request id file");
    $files->{'request_id_file'} = $dir . "/" . $tmp;

    return $files;
}

### determineFile( $default, $cl, $name )
#
# choose between the default- and the commandline-specified file.  error out if we
# can't write to our choice.
#

sub determineFile
{
    my ($default, $cl, $name) = @_;
    my ($tmp_file);

    #
    # if we were passed a commandline choice, make sure that it's not just whitespace
    #

    $tmp_file = $cl;
    if ( defined($tmp_file) )
    {
        $file = $tmp_file;
    }
    else
    {
        $file = $default;
    }

    $file =~ s:^[\s]+|[\s]+$::g;
    if ( length($file) == 0 )
    {
        printf("no $name specified!\n");
        exit;
    }

    #
    # check that the chosen file doesn't have any slashes in it (isn't a path)
    #

    if ( grep(/\//, $file) )
    {
        printf("$name can only be a filename!\n");
        exit;
    }

    #
    # check that, if our choice exists, we can write to it
    #

    if ( ( -e $file ) && ( ! -w $file ) )
    {
        printf("can't write to $file");
        exit;
    }

    return $file;
}

### makeDir( $path )
#
# creates the directory structure in $path if it doesn't already exist
#

sub makeDir
{
    my ($path) = @_;
    my (@dirs, $curr_dir);

    if ( ( -e $path ) && ( ! -d $path ) )
    {
        printf("$path exists and isn't a directory!\n");
        exit;
    }

    if ( ! -e $path )
    {
        #
        # break the directories apart
        #

        @dirs = split(/\//, $path);

        for my $d (@dirs)
        {
            #
            # if the current directory is non-null
            #

            if ( length($d) gt 0 )
            {
                $curr_dir = $curr_dir . "/" . $d;

                if ( ( -e $curr_dir ) && ( ! -d $curr_dir ) )
                {
                    printf("$curr_dir exists and isn't a directory!\n");
                    exit;
                }

                if ( ! -e $curr_dir )
                {
                    mkdir($curr_dir) || die "can't make directory $curr_dir: $!\n";
                }
            }
        }
    }
}

### writeFile( $filename, $fileinput )
#
# create the inputs to the ssl program at $filename, appending the common name to the
# stream in the process
#

sub writeFile
{
    my ($filename, $fileinput) = @_;

    #
    # test for a valid $filename
    #

    if ( !defined($filename) || (length($filename) lt 1) )
    {
        die "Filename is undefined";
    }

    if ( ( -e "$filename" ) && ( ! -w "$filename" ) )
    {
        die "Cannot write to filename '$filename'";
    }

    #
    # write the output to $filename
    #

    open(OUT, ">$filename");
    print OUT "$fileinput";
    close(OUT);
}

### createInputFileString( $name, $ca_config_filename )
#
# create the inputs to the ssl program at $filename, appending the common name to the
# stream in the process
#

sub createInputFileString
{
    my ($name, $ca_config_filename) = @_;
    my ($parsing, @defaults, $output);

    #
    # test for the existence of the config file
    #

    if ( ! -r "${ca_config_filename}" )
    {
        die("Cannot read ${ca_config_filename}");
    }

    #
    # read the ca config file and extract the default data
    #

    open(IN, "<${ca_config_filename}");

    while (<IN>)
    {
        if ( grep(/^\[ req_distinguished_name \]/, $_) )
        {
            $parsing = 1;
            next;
        }
        if ( grep(/^\[ .*/, $_) )
        {
            $parsing = 0;
            next;
        }
        if ( grep(/^[a-zA-Z0-9\.]*_default[ \t]*=/, $_) && ($parsing == 1) )
        {
            push(@defaults, $_);
        }
    }

    close(IN);

    #
    # format the default values into k/v pairs and append the value to the
    # output string
    #

    for my $line (@defaults)
    {
        $line =~ s|[\n]+$||g;

        my ($key, $value) = split(/=/, $line);

        $key =~ s:^[\s]+|[\s]+$::g;
        $value =~ s:^[\s]+|[\s]+$::g;

        $output .= $value . "\n";
    }

    $output .= $name . "\n";

    return $output;
}

### createServiceRequestHeader( $request_id_file, $contact_url, $contact_email_addr, $subject )
#
# generate the request header for a generic service
#

sub createServiceRequestHeader
{
    my ($request_id_file, $contact_url, $contact_email_addr, $subject) = @_;

    my $str;

    $str .= "This is a Certficate Request file for an Alliance Certificate.\n";
    $str .= "\n";
    $str .= "This request should already have been submitted to the Alliance\n";
    $str .= "CA for approval and you will be notified by email when your\n";
    $str .= "certificate is ready. Your request ID number can be found in the\n";
    $str .= "file: ${request_id_file}\n";
    $str .= "\n";
    $str .= "If you have any questions or concerns please visit\n";
    $str .= "\n";
    $str .= "${contact_url}\n";
    $str .= "\n";
    $str .= "or send mail to Alliance consulting at ${contact_email_addr}\n";
    $str .= "\n";
    $str .= "=========================================================================\n";
    $str .= "Certificate Subject:\n";
    $str .= "\n";
    $str .= "$subject\n";

    return $str;
}

### createRequestHeader( $request_id_file, $contact_url, $contact_email_addr, $subject )
#
# generate a request header
#

sub createRequestHeader
{
    my $str;

    $str .= "This is a Certificate Request file for an Alliance Certificate.\n";
    $str .= "\n";
    $str .= "This request should already have been submitted to the Alliance\n";
    $str .= "CA for approval and you will be notified by email when your\n";
    $str .= "certificate is ready. Your request ID number can be found in the\n";
    $str .= "file: ${request_id_file}\n";
    $str .= "\n";
    $str .= "If you have any questions or concerns please visit\n";
    $str .= "\n";
    $str .= "${contact_url}\n";
    $str .= "\n";
    $str .= "or send mail to Alliance consulting at ${contact_email_addr}\n";
    $str .= "\n";
    $str .= "=========================================================================\n";
    $str .= "Certificate Subject:\n";
    $str .= "\n";
    $str .= "${subject}\n";

    return $str;
}

### readFile( $filename )
#
# reads and returns $filename's contents
#

sub readFile
{
    my ($filename) = @_;

    open (IN, "$filename") || die "Can't open '$filename': $!";
    $/ = undef;
    $data = <IN>;
    $/ = "\n";
    close(IN);

    return $data;
}

### checkGlobusSystem( $ca_config )
#
# verify that the local system has a valid CA configuration file
#

sub checkGlobusSystem
{
    my ($ca_config) = @_;
    my $size, $data, $rc;

    $data = readFile($ca_config);

    if ( grep(/Not Configured/, $data) )
    {
        printf("The NCSA Configuration files have not been setup.\n");
        printf("Please have your system administrator install the\n");
        printf("ncsa-ca packages.\n");
        die;
    }
}

### checkCerts( $cert_file, $key_file, $request_file )
#
# check the system for preexisting valid files.  remove them if '-force' was
# given as an argument.
#

sub checkCerts
{
    my ($cert_file, $key_file, $request_file) = @_;
    my $found = 0;
    my (@files, @found);

    push(@files, $request_file, $cert_file, $key_file);

    for my $f (@files)
    {
        if ( ( length($f) gt 0 ) && ( -r "$f" ) )
        {
            push(@found, $f);
        }
    }

    if (scalar(@found) gt 0)
    {
        if ($force)
        {
            cleanup(@files);
        }
        else
        {
            printf("ERROR: Found the following file(s):\n");
            for my $f (@found)
            {
                printf("\t$f\n");
            }
            printf("\n");
            printf("Please remove all of the listed files before running this program again.\n");
            printf("\n");
            printf("If you are attempting to resubmit an already generated request\n");
            printf("use the '-resubmit' option.\n");
            exit;
        }
    }
}

### getCN( $type, $name )
#
# get the name for the cert request based on $type
#

sub getCN
{
    my ($type, $name) = @_;
    my ($str);

    if ($type eq "user")
    {
        $str = getUserCN($name);
    }
    elsif ($type eq "ldap")
    {
        $str = getLdapCN($name);
    }
    elsif ($type eq "host")
    {
        $str = getHostCN($name);
    }
    elsif ($type eq "gatekeeper")
    {
        #
        # gatekeeper is really just an alias for a host certificate
        #

        $str = getHostCN($name);
    }
    else
    {
        die("I don't know how to get the CN for a certificate request of type '$type'!");
    }

    return $str;
}

### getUserCN( $name )
#
# get the common name for the user cert request
#

sub getUserCN
{
    my ($name) = @_;
    my ($userinput, $start, $valid) = ("", 1, 0);

    #
    # we should check the value that was passed into the program
    #

    if (defined($name))
    {
        #
        # transform and then verify that $name is a valid entry
        #

        $valid = validateUserString($name, 1);
    }

    #
    # if the value is invalid, or was undefined, we loop over the user's input
    #

    while ( ! $valid )
    {
        printf("Enter your name (eg. John Smith): ");
        $userinput = <STDIN>;

        #
        # do some formatting of the user input
        #

        $userinput =~ s:^[\s]+|[\s]+$|[\n]+$::g;

        $valid = validateUserString($userinput, 0);

        if ( $valid )
        {
            $name = $userinput;
        }
    }

    return $name;
}

### validateUserString( $userinput )
#
# check $userinput to verify its integrity as a user CN.  No transformations should
# occur in this function.
#

sub validateUserString
{
    my ($userinput, $quiet) = @_;

    if (length($userinput) == 0)
    {
        printf("Name is required!\n") unless $quiet;
        return 0;
    }

    return 1;
}

### validateHostString( $userinput )
#
# check $userinput to verify its integrity as a host CN.  No transformations should
# occur in this function.
#

sub validateHostString
{
    my ($name, $quiet) = @_;
    my ($response, $error);

    #
    # variable init
    #

    $error = 0;

    if (length($name) == 0)
    {
        printf("A valid hostname is required!\n") unless $quiet;
        return 0;
    }

    #
    # check for properties a host name should have
    #

    if ( (!$error) && ( grep(/\s/, $name) ) )
    {
        printf("The hostname '$name' does not appear to be properly formatted.\n");
        $error = 1;
    }

    if ( (!$error) && ( (! grep(/\./, $name)) || grep(/\s/, $name) ) )
    {
        printf("The hostname '$name' does not appear to be fully qualified.\n");
        $error = 1;
    }

    #
    # if there was an error, ask the user if they wish to continue
    #

    if ($error)
    {
        $response = query_user_boolean("Do you wish to continue?", "n");

        if ($response eq "n")
        {
            printf("Exiting...\n");
            exit;
        }
        else
        {        
            return 1;
        }
    }

    return 1;
}

### query_user_boolean( $querystr, $defaultval )
#
# Query the user with a boolean string
#

sub query_user_boolean
{
    my ($querystr, $defaultval) = @_;
    my ($valid, @tmp);

    while ( ! $valid )
    {
        printf("$querystr [$defaultval] ");
        $response = <STDIN>;
        $response =~ s:[\n]+$::g;

        #
        # transform the response to remove 
        #

        $response_tr = $response;
        $response_tr =~ s:^[\s]+|[\s]+$::g;

        #
        # if the user hits <enter>, then return $defaultval
        # else if the user types in something other than 'n', 'N', 'y', 'Y', error and
        #   request better input
        # else lowercase the input and return that string
        #

        if ( length($response_tr) == 0 )
        {
            return $defaultval;
        }

        $response_tr = lc($response_tr);
        @tmp = split(//, $response_tr);

        if ( ( $tmp[0] ne "y" ) && ( $tmp[0] ne "n" ) )
        {
            printf("Invalid input: $response\n");
        }
        else
        {
            $valid = 1;
            $response = $tmp[0];
        }
    }

    return $response;
}

### getHostCN( $name )
#
# get the host name for the host cert request
#

sub getHostCN
{
    my ($name) = @_;
    my ($userinput, $start, $valid) = ("", 1, 0);

    #
    # we should check the value that was passed into the program
    #

    if (defined($name))
    {
        #
        # transform and then verify that $name is a valid entry
        #

        $valid = validateHostString($name, 1);
    }

    #
    # if the value is invalid, or was undefined, we loop over the user's input
    #

    while ( ! $valid )
    {
        printf("Enter the FQDN of your host (eg. foo.bar.edu): ");
        $userinput = <STDIN>;

        #
        # do some formatting of the user input
        #

        $userinput =~ s:^[\s]+|[\s]+$|[\n]+$::g;

        $valid = validateHostString($userinput, 0);

        if ( $valid )
        {
            $name = $userinput;
        }
    }

    $name = "host/" . $name;

    return $name;
}

### getLdapCN( $name )
#
# get the host name for the ldap cert request
#

sub getLdapCN
{
    my ($name) = @_;
    my ($userinput, $start, $valid) = ("", 1, 0);

    #
    # we should check the value that was passed into the program
    #

    if (defined($name))
    {
        #
        # transform and then verify that $name is a valid entry
        #

        $valid = validateHostString($name, 1);
    }

    #
    # if the value is invalid, or was undefined, we loop over the user's input
    #

    while ( ! $valid )
    {
        printf("Enter the FQDN of your host (eg. foo.bar.edu): ");
        $userinput = <STDIN>;

        #
        # do some formatting of the user input
        #

        $userinput =~ s:^[\s]+|[\s]+$|[\n]+$::g;

        $valid = validateHostString($userinput, 0);

        if ( $valid )
        {
            $name = $userinput;
        }
    }

    $name = "ldap/" . $name;

    return $name;
}

### createCerts( $type, $name )
#
# use $ssl_exec program to create the key and certificate files on a system
#

sub createCerts
{
    my ($type, $name) = @_;
    my ($umsk, $tmpfile, $addendum);

    printf("A certificate request and private key is being created.\n");

    if (!defined($nopw))
    {
        printf("You will be asked to enter a PEM pass phrase.\n");
        printf("This pass phrase is akin to your account password,\n");
        printf("and is used to protect your key file.\n");
        printf("If you forget your pass phrase, you will need to\n");
        printf("obtain a new certificate.\n");
    }

    #
    # create the certificate file
    #

    $umsk = umask();
    umask("022");
    action("touch $cert_file");

    #
    # create some semi random data for key generation
    # (this code is heavily influenced by a later version of Globus's grid-cert-request)
    #

    umask("066");
    action("touch ${rand_temp}");
    if ( -r "/dev/urandom" )
    {
        action("head -c 1000 /dev/urandom >> ${rand_temp}");
    }
    action("date >> ${rand_temp}");
    action("netstat -in >> ${rand_temp}");
    action("ps -ef >> ${rand_temp}");
    my $home = $ENV{'HOME'};
    action("ls -ln $home >> ${rand_temp}");
    action("ls -ln /tmp >> ${rand_temp}");

    #
    # create the key and request files
    #
    # we redirect to /dev/null in one case: where $nopw is set and $interactive isn't.  in all
    # other cases, the user should be seeing the output of the openssl program.
    #

    umask("177");

    if ($interactive)
    {
        action("${ssl_exec} req -new -keyout ${key_file} -out ${req_output} \\
                                -rand ${rand_temp}:/var/adm/wtmp:/var/log/messages \\
                                -config ${ca_config} ${no_des}");
    }
    else
    {
        if (defined($nopw))
        {
            $addendum = "> /dev/null";
        }
        else
        {
            $addendum = "";
        }

        $tmpstring = createInputFileString( $name, $ca_config );
        writeFile($req_input, $tmpstring);
        action("${ssl_exec} req -new -keyout ${key_file} -out ${req_output} \\
                                -rand ${rand_temp}:/var/adm/wtmp:/var/log/messages \\
                                -config ${ca_config} ${no_des} < ${req_input} $addendum");
        printf("\n");
 
        cleanup($req_input);
    }

    cleanup($rand_temp);

    #- the following code should emulate this routine
    #- SUBJECT="`${SSL_EXEC} req -text -noout < ${REQ_OUTPUT} 2>&1 |\
    #-        ${GLOBUS_SH_GREP-grep} 'Subject:' | ${GLOBUS_SH_AWK-awk} -F: '{print $2}' |\
    #-        ${GLOBUS_SH_CUT-cut} -c2- `"

    $tmpfile = "/tmp/tmp.$$";
    action("${ssl_exec} req -text -noout < ${req_output} > ${tmpfile}");
    $data = readFile($tmpfile);

    @lines = split(/\n/, $data);
    for my $line (@lines)
    {
        if ( grep(/Subject:/, $line) )
        {
            @strs = split(/:/, $line);
            $subject = substr($strs[1], 1);
            last;
        }
    }

    #- the following code should emulate this routine
    #- #Convert the subject to the correct form.
    #- SUBJECT=`echo "/"${SUBJECT} | ${GLOBUS_SH_SED-sed} -e 's|, |/|g'`

    $subject = "/" . $subject;
    $subject =~ s|, |/|g;

    if ($type eq "user")
    {
          $str = createRequestHeader( $request_id_file, $contact_url, $contact_email_addr, $subject );
          open(OUT, ">${req_head}");
          print OUT $str;
          close(OUT);
    }
    else
    {
          $str = createServiceRequestHeader( $request_id_file, $contact_url, $contact_email_addr, $subject );
          open(OUT, ">${req_head}");
          print OUT $str;
          close(OUT);
    }

    #
    # finalize the Request file.
    #

    action("cat $req_head $req_output > $request_file");
    cleanup($req_head, $req_output, $tmpfile);

    umask($umsk);
}

### printPostData( $string )
#
# returns the concatenation of $var and a url-encoded $value
#

sub printPostData
{
    my ($var, $value) = @_;
    my ($str);

    #
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

    $str = "$var=$value";

    $str =~ s/%/%25/g;
    $str =~ s/@/%40/g;
    $str =~ s/&/%26/g;
    $str =~ s/ /+/g;

    return $str;
}

### processReqFile( $file )
#
# given the name of a certreq file, process and print
# contents suitabily encoded for inclusion in POST data.
#

sub processReqFile
{
    my ($file) = @_;
    my ($contents, $parsing, $formatted);

    $contents = readFile($file);

    #
    # You may choose to substitute your own demarcation strings, if you do not
    # like these.
    #

    $start_string = "BEGIN CERTIFICATE REQUEST";
    $end_string = "END CERTIFICATE REQUEST";

    #
    # Set $contents to be everything that exists between
    # $start_string and $end_string
    #

    $formatted = "";
    $parsing = 0;
    @data = split(/\n/, $contents);
    for my $d (@data)
    {
        if ( grep(/$start_string/, $d) )
        {
            $parsing = 1;
        }

        if ($parsing)
        {
            $formatted .= $d . "\n";
        }

        if ( grep(/$end_string/, $d) )
        {
            $parsing = 0;
        }
    }

    #
    # Special characters: +, /, =, \n, and spaces (" ") are given their
    # appropriate corresponding hex values for proper transmission via HTTP
    #
    # the same url-encoding statements go for this are as for printPostData.
    # since multiple areas of this script use url-encoding (every one dealing
    # with posting info via http) we may consider just queueing up the url-
    # encoding for one big shot right before the submittal.
    #

    $formatted =~ s/\+/%2B/g;
    $formatted =~ s/ /+/g;
    $formatted =~ s/\//%2F/g;
    $formatted =~ s/=/%3D/g;
    $formatted =~ s/\n/%0D%0A/g;

    return $formatted;
}

### handleSuccessfulPost( $post_out_file, $request_id_file )
#
# get the request id number from the output file generated via the post
#

sub handleSuccessfulPost
{
    my ($post_out_file, $request_id_file) = @_;
    my ($data, $request_id);
    my (@strs, @splitdata);

    $data = readFile($post_out_file);

    @strs = split(/\n/, $data);
    for my $s (@strs)
    {
        if ( grep(/fixed\.requestId =/, $s) )
        {
            @splitdata = split(/"/, $s);
            $request_id = $splitdata[1];
            last;
        }
    }

    #
    # write the returned request_id to a file, but for no good reason
    #

    open(OUT, ">$request_id_file");
    print OUT "$request_id\n";
    close(OUT);

    printf("Your certificate request for an Alliance certificate has been successfully\n");
    printf("sent to the Alliance Certificate Authority (CA).\n");
    printf("\n");
    printf("You must now follow the directions on the following web page in order\n");
    printf("to complete the request process:\n");
    printf("\n");
    printf("${url_howto_complete}\n");
    printf("\n");
    printf("If you have any questions or concerns please contact Alliance consulting\n");
    printf("at ${contact_email_addr}.\n");
    printf("\n");
    printf("You request id is ${request_id}. Please use it in any correspondence\n");
    printf("with Alliance consulting.\n");

    return;
}

### handleFailedPost( $post_out_file )
#
# attempt to diagnose the error which occurred during the post to the CA
#

sub handleFailedPost
{
    my ($post_out_file) = @_;
    my ($data);

    $data = readFile($post_out_file);

    if ( grep(/connect/, $data) )
    {
        printf("An error occurred sending your request to the NCSA CA.\n");
        printf("\n");
        printf("If you are inside a firewall, please verify with your firewall\n");
        printf("administrator that you are allowed to make sure httpd conntections\n");
        printf("(https) through the firewall.\n");
        printf("\n");
        printf("If you wish to try again at a later time (e.g. you know it's a\n");
        printf("network problem) you may do so by running:\n");
        printf("\n");
        printf("${program_name} -resubmit\n");
        printf("\n");
        printf("You can get help by visiting the following url:\n");
        printf("\n");
        printf("${contact_url}\n");

        return;
    }

    @strs = split(/\n/, $data);
    for my $s (@strs)
    {
        if ( grep(/fixed\.unexpectedError =/, $s) )
        {
            @splitdata = split(/"/, $s);
            $server_error = $splitdata[1];
            last;
        }
    }

    if ( length($server_error) gt 0 )
    {
        printf("A server error occurred: ${server_error}\n\n");
    }

    printf("An error occurred attempting to post your certificate request\n");
    printf("to the NCSA CA. Please contact Alliance consulting for assistance\n");
    printf("at ${contact_email_addr}. Please include the following file\n");
    printf("in your email as it will help in diagnosising the error:\n");
    printf("${post_out_file}.\n");
    printf("\n");
    printf("Thank you and sorry for the inconvience.\n");

    return;
}

### postReq( $user_name, $user_email, $user_phone, $request_id_file )
#
# Post the req to the web server.
#

sub postReq
{
    my ($user_name, $user_email, $user_phone, $request_id_file) = @_;

    my ($server, $port, $enroll_page);
    my ($post_cmd_file, $post_out_file);
    my ($extra_email);

    # https://ca.ncsa.edu/NCSAUserGridCertEnroll.html
    $server = "ca.ncsa.edu";
    $port = "443";
    $enroll_page = "/enrollment";

    # Temporary files
    $post_cmd_file = "${secure_tmpdir}/$program_name.$$.post_cmd";
    $post_out_file = "${secure_tmpdir}/$program_name.$$.post_out";

    $req_content = processReqFile($request_file);

    $comment = "host=$host";

    # Build the post data
    $postdata .= "pkcs10Request=${req_content}";
    $postdata .= "%0D%0A&";

    $postdata .= printPostData("csrRequestorName", "${user_name}");
    $postdata .= "&";

    # Also send email to this address on certificate generation
    # EXTRA_EMAIL=", paciacct@ncsa.uiuc.edu <mailto:paciacct@ncsa.uiuc.edu>"
    $extra_email=", paciacct\@ncsa.uiuc.edu <mailto:paciacct\@ncsa.uiuc.edu>";

    $postdata .= printPostData("csrRequestorEmail", "${user_email}${extra_email}");
    $postdata .= "&";

    $postdata .= printPostData("csrRequestorPhone", "${user_phone}");
    $postdata .= "&";

    $postdata .= printPostData("csrRequestorComments", ${comment});
    $postdata .= "&";

    # The following are hidden values in the form
    $postdata .= printPostData("requestFormat", "pkcs10");
    $postdata .= "&";

    $postdata .= printPostData("certType", "server");
    $postdata .= "&";

    $postdata .= printPostData("ssl_server", "true");
    $postdata .= "&";

    $postdata .= printPostData("digital_signature", "true");
    $postdata .= "&";

    $postdata .= printPostData("non_repudiation", "true");
    $postdata .= "&";

    $postdata .= printPostData("key_encipherment", "true");
    $postdata .= "&";

    $postdata .= printPostData("data_encipherment", "true");
    $postdata .= "&";

    $postdata .= printPostData("reencodeSubjectName", "true");
    $postdata .= "&";

    $postdata .= printPostData("submit", "Submit");
    $postdata .= "\n\n";

    #
    # Get number of bytes we are posting
    #

    $content_len = length($postdata);

    #
    # Now build the actual text for sending to the web server
    #

    $postcmd .= "POST ${enroll_page} HTTP/1.0\n";
    $postcmd .= "Content-type: application/x-www-form-urlencoded\n";
    $postcmd .= "Content-length: ${content_len}\n";
    $postcmd .= "User-Agent: ${user_agent}\n";
    $postcmd .= "\n";
    $postcmd .= $postdata;

    open(OUTPUT, ">$post_cmd_file");
    print OUTPUT $postcmd;
    close(OUTPUT);

    #
    # Sleep to give server a chance to respond
    #

    #- (cat ${POST_CMD_FILE}; sleep 10) | ${SSL_EXEC} s_client -quiet -connect ${SERVER}:${PORT} > ${POST_OUT_FILE} 2>&1
    action("${ssl_exec} s_client -quiet -connect ${server}:${port} < ${post_cmd_file} > ${post_out_file}");

    $data = readFile($post_out_file);

    if ( grep(/CMS Request Pending/, $data) )
    {
        handleSuccessfulPost($post_out_file, $request_id_file);

        cleanup($post_out_file);
    }
    else
    {
        handleFailedPost($post_out_file);

        #
        # Append the POST_CMD_FILE to the POST_OUT_FILE and then leave it so
        # that it can be used for debugging.
        #

        action("cat ${post_cmd_file} >> ${post_out_file}");
    }

    cleanup($post_cmd_file);
}

### getUserEmail( )
#
# get the email address for the user cert request
#

sub getUserEmail
{
    my ($userinput, $start, $valid) = ("", 1, 0);
    my ($name);

    #
    # if the value is invalid, or was undefined, we loop over the user's input
    #

    while ( ! $valid )
    {
        printf("Enter your full email address (eg. user\@somewhere.edu): ");
        $userinput = <STDIN>;

        #
        # do some formatting of the user input
        #

        $userinput =~ s:^[\s]+|[\s]+$|[\n]+$::g;

        $valid = validateUserEmailString($userinput, 0);

        if ( $valid )
        {
            $name = $userinput;
        }
    }

    return $name;
}

### validateUserEmailString( $userinput )
#
# check $userinput to verify its integrity as a user email.  No transformations should
# occur within this function.
#

sub validateUserEmailString
{
    my ($userinput, $quiet) = @_;

    if (length($userinput) == 0)
    {
        printf("A valid email address is required!\n") unless $quiet;
        return 0;
    }

    if ( ! grep(/\@/, $userinput ) )
    {
        printf("A valid email address is required!\n") unless $quiet;
        return 0;
    }

    return 1;
}

### getUserPhone( )
#
# get the phone number of the user
#

sub getUserPhone
{
    my ($userinput, $start, $valid) = ("", 1, 0);
    my ($name);

    #
    # if the value is invalid, or was undefined, we loop over the user's input
    #

    while ( ! $valid )
    {
        printf("Enter your phone number (with area code): ");
        $userinput = <STDIN>;

        #
        # do some formatting of the user input
        #

        $userinput =~ s:^[\s]+|[\s]+$|[\n]+$::g;

        $valid = validateUserPhoneString($userinput, 0);

        if ( $valid )
        {
            $name = $userinput;
        }
    }

    return $name;
}

### validateUserPhoneString( $userinput )
#
# check $userinput to verify its integrity as a user phone.  No transformations should
# occur within this function.
#

sub validateUserPhoneString
{
    my ($userinput, $quiet) = @_;

    if (length($userinput) == 0)
    {
        printf("A valid phone number is required!\n") unless $quiet;
        return 0;
    }

    return 1;
}

### getUserName( )
#
# get the user's name for the user cert request
#

sub getUserName
{
    my ($userinput, $start, $valid) = ("", 1, 0);

    #
    # if the value is invalid, or was undefined, we loop over the user's input
    #

    while ( ! $valid )
    {
        printf("Enter your name (eg. John Smith): ");
        $userinput = <STDIN>;

        #
        # do some formatting of the user input
        #

        $userinput =~ s:^[\s]+|[\s]+$|[\n]+$::g;

        $valid = validateUserName($userinput, 0);

        if ( $valid )
        {
            $name = $userinput;
        }
    }

    return $name;
}

### validateUserName( $userinput )
#
# check $userinput to verify its integrity as a user name.  No transformations
# should occur in this function.
#

sub validateUserName
{
    my ($userinput, $quiet) = @_;

    if (length($userinput) == 0)
    {
        printf("Name is required!\n") unless $quiet;
        return 0;
    }

    return 1;
}

### checkResubmit( )
#
# check to see if we set to try resubmission
#

sub checkResubmit
{
    my (@error);

    if ( -e $request_id_file )
    {
        $output .= "Error: ${request_id_file} exists.\n";
        $output .= "\n";
        $output .= "The above file exists, indicating that you have already\n";
        $output .= "successfully submitted your certificate request.\n";
        $output .= "\n";
        $output .= "If you are certain that this is incorrect, you may remove\n";
        $output .= "this file and try resubmitting again.\n";
        $output .= "\n";
        $output .= "If you want assistance please email ${contact_email_addr}\n";
        $output .= "or visit:\n";
        $output .= "\n";
        $output .= "${contact_url}\n";
        $output .= "\n";
        printf("$output");
        exit;
    }

    if ( ! -e $request_file )
    {
        push(@error, "request file ($request_file)");
    }

    if ( ! -e $key_file )
    {
        push(@error, "key file ($key_file)");
    }

    if ( scalar(@error) gt 0 )
    {
        printf("The following file(s) were not found on the system:\n");
        for my $e (@error)
        {
            printf("\t$e\n");
        }
        $error = 1;
    }

    if ( $error )
    {
        $output .= "\n";
        $output .= "Cannot resubmit.  You apparently have not generated a certificate\n";
        $output .= "request and need to run ${program_name} without -resubmit.\n";
        $output .= "\n";
        $output .= "If you want assistance please email ${contact_email_addr}\n";
        $output .= "or visit:\n";
        $output .= "\n";
        $output .= "${contact_url}\n";
        printf("$output");
        exit;
    }

    # Everything checks out

    $name = getCNFromRequest();

    return $name;
}

### getCNFromRequest( )
#
# read the request file and pull out the CN part of the subject line
#

sub getCNFromRequest
{
    my ($parsing, @strs, $data, @caught, $mycn, $myname);

    #
    # get all of the data in the $request_file
    #

    $data = readFile($request_file);

    #
    # get everything between the 'Certificate Subject' and 'Begin Cert' lines
    # (non-inclusive)
    #

    @strs = split(/\n/, $data);
    $parsing = 0;
    for my $s (@strs)
    {
        if ($s =~ /^-----BEGIN CERTIFICATE REQUEST-----/)
        {
            $parsing = 0;
        }

        if ($parsing)
        {
            push(@caught, $s);
        }

        if ($s =~ /^Certificate Subject/)
        {
            $parsing = 1;
        }
    }

    $data = join('', @caught);
    $data =~ s:^[\s]+|[\s]+$|[\n]+::g;

    if (length($data) eq 0)
    {
        printf("Found improperly formatted or non-existant subject line in $request_file!\n");
        exit;
    }

    #
    # cleanup variables
    #

    @strs = ();
    $parsing = undef;
    @caught = ();

    #
    # get everything from the CN to the end of the string
    #

    @strs = split(/\//, $data);
    $parsing = 0;
    for my $s (@strs)
    {
        if ($s =~ /^CN/)
        {
            $parsing = 1;
        }

        if ($parsing)
        {
            push(@caught, $s);
        }
    }

    $data = join('/', @caught);

    if (length($data) eq 0)
    {
        printf("Found improperly formatted or non-existant subject line in $request_file!\n");
        exit;
    }

    #
    # get everything after the CN= portion of the subject
    #

    ($mycn, $myname) = split(/=/, $data);

    if (length($myname) eq 0)
    {
        printf("Found improperly formatted or non-existant subject line in $request_file!\n");
        exit;
    }

    return $myname;
}

### printPreamble( )
#
# print out a generic text message to the user so they may know what is about to happen
#

sub printPreamble
{
    my $foo;

    printf("You are about to request a certificate from the Alliance\n");
    printf("Certificate Authoriy.\n");
    printf("\n");
    printf("Before preceeding make sure you have read the directions at:\n");
    printf("\n");
    printf("${url_howto_submit}\n");
    printf("\n");
    printf("Press return to continue.\n");

    $foo = <STDIN>;
}

### absolutePath( )
#
# accept a list of files and, based on our current directory, make their pathnames absolute
#

sub absolutePath
{
    my ($file) = @_;
    my $cwd = cwd();

    if ($file !~ /^\//)
    {
        $file = $cwd . "/" . $file;
    }

    return $file;
}

### inform( $content, $override )
#
# inform the user of an event
#

sub inform
{
    my ($content, $override) = @_;

    if ( $verbose or defined($override) )
    {
        print "$content\n";
    }
}

### action( $command, $dir )
#
# perform some command and inform the user
#

sub action
{
    my ($command, $dir) = @_;
    my $pwd;
    if (defined $dir) {
        $pwd = cwd();
        inform("[ Changing to $dir ]");
        chdir($dir);
    }

    # Log the step
    inform($command);

    # Perform the step
    my $result = system("$command 2>&1");

    if ($result or $?)
    {
        # results are bad print them out.
        die("ERROR: Command failed\n");
    }

    if (defined $dir)
    {
        inform("[ Changing to $pwd ]");
        chdir($pwd);
    }
}

### main( $name )
#
# driver function
#

sub main
{
    my ($name) = @_;
    my ($user_email, $user_phone);

    #
    # based on the type, build the path to the certificates
    #

    $cl_files = preparePathsHash($cl_dir, $cl_cert_file, $cl_key_file, $cl_request_file, $cl_request_id_file);
    $default_files = preparePathsHash($default_dir, $default_cert_file, $default_key_file, $default_request_file, $default_request_id_file);
    $files = determinePaths($default_files, $cl_files);

    $cert_file = $files->{'cert_file'};
    $key_file = $files->{'key_file'};
    $request_file = $files->{'request_file'};
    $request_id_file = $files->{'request_id_file'};

    if ( -e $cert_file || -e $key_file )
    {
        my $files, $error_message;

        $error_message  = "One or more system files already exist at:\n";
        $error_message .= "\n";

        if ( -e $cert_file )
        {
            $error_message .= "\t$cert_file (certificate)\n";
        }

        if ( -e $key_file )
        {
            $error_message .= "\t$key_file (key)\n";
        }

        $error_message .= "\n";
        $error_message .= "If you wish to request another certificate and place it in the above\n";
        $error_message .= "location, you must either move or delete the file(s) that are present.\n";
        $error_message .= "\n";
        $error_message .= "If you wish to place this certificate you are trying to request in a\n";
        $error_message .= "different location, please use the -dir option.\n";
        $error_message .= "\n";
        $error_message .= "If you wish to name this certificate differently, please use the -cert\n";
        $error_message .= "and/or the -key option.\n";
        $error_message .= "\n";
        $error_message .= "For more help on these options and others, please run $program_name -help or\n";
        $error_message .= "$program_name -man.\n";

        die($error_message);
    }

    checkGlobusSystem($ca_config);

    if ( ! $resubmit )
    {
        checkCerts($cert_file, $key_file, $request_file);

        printPreamble();

        $name = getCN($type, $name);

        #
        # perform some additional data gathering before we create our certificates
        #

        #
        # we should figure out if the csrRequestorName variable sent in the post to the server
        # is looking for the user's name, or the common name of the certificate.  if it's the
        # former, then we should uncomment the next piece of code and call postReq() accordingly.
        #
        # if ($type eq "user")
        # {
        #     $user_name = $name;
        # }
        # else
        # {
        #     $user_name = getUserName();
        # }

        $user_name = $name;
        $user_email = getUserEmail();
        $user_phone = getUserPhone();
        printf("\n");

        createCerts($type, $name);
    }
    else
    {
        $name = checkResubmit();

        printPreamble();

        $user_name = $name;
        $user_email = getUserEmail();
        $user_phone = getUserPhone();
        printf("\n");
    }

    postReq($user_name, $user_email, $user_phone, $request_id_file);
}

__END__

=head1 NAME

ncsa-cert-request - Request a certificate from the NCSA (Alliance) CA

=head1 SYNOPSIS

ncsa-cert-request [options]

  Help-Related Options:
    -help       brief help message
    -man        full documentation

=head1 OPTIONS

=over 8

=item B<-type <cert_type>>

Generate a certificate request of type <cert_type>.  A listing of the types of requests
this script can generate is available by invoking this program with the '-man' argument.

=item B<-name <name>>

Set the name to include in the certificate request to <name>.

=item B<-dir <dir_name>>

User-specified certificate directory. (eg. $HOME/.globus or /etc/grid-security)

=item B<-cert <filename>>

File name of the certificate.

=item B<-key <filename>>

File name of the user key.

=item B<-req <filename>>

File name of the certificate request.

=item B<-nopw>

Create the certificate without a password.

=item B<-interactive>

Prompt user for each component of the DN.  (Only use this if you know what you are doing!)

=item B<-force>

Overwrite any prexisting certificates.

=item B<-resubmit>

Resubmit a previously generated certificate request.

=item B<-verbose>

Increase the amount of output that will be generated by the program.

=item B<-version>

Print the version identifier of this program and exit.

=item B<-help>

Print a brief help message and exit.

=item B<-man>

Print the manual page and exit.

=back

=head1 DESCRIPTION

B<ncsa-cert-request> will request a certificate from the NCSA certificate
authority.  This program understands four different types of certificates:
'user', 'host', 'ldap', and 'gatekeeper'.  The gatekeeper certificate type
is just an alias to a certificate type of host.  If no type is specified on
the command-line, the script will attempt to request a certificate of type
'user'.

By default, this script tries to place its files in $HOME/.globus.  You can
override this behaviour using the -dir command-line flag.

=head1 EXAMPLES

=head2 Requesting a User Certificate

To request a user certificate specifying that you want this request's files
to appear in /home/myhome/.globus/user2, and that the key file should be
named 'mykey.pem':

B<ncsa-cert-request -dir "/home/myhome/.globus/user2" -key "mykey.pem">

=head2 Requesting an LDAP Certificate

To request an LDAP certificate with the directory to write to set as
/etc/grid-security, setting the name to myhost.mydomain.edu, overwriting any
files that match its defaults, and requesting verbose output:

B<ncsa-cert-request -type ldap -dir "/etc/grid-security" -name "myhost.mydomain.edu" -force -verbose>

(Note that with certificate types of 'host', 'ldap', and 'gatekeeper', the
key file will be generated unencrypted.  That is, you do not have to specify
-nopw on the command-line, it will be done for you automatically.  Also note
that if only root can write to /etc/grid-security, then only root should be
able to perform this command.)

=head2 Requesting a Host/Gatekeeper Certificate

To request a Host certificate using the default directory of $HOME/.globus,
and to be prompted for all of the distinguished name information during key
and request generation:

B<ncsa-cert-request -type host -interactive>

=head2 Resubmitting a Previously-Generated Request

To resubmit a request which was not sent to the Alliance CA due to some
connection error, you can use the -resubmit option.  If all of your request
files exist in, eg. /home/myhome/mycerts:

B<ncsa-cert-request -resubmit -dir "/home/myhome/mycerts">

=head1 AUTHORS

 Chase Phillips <cphillip@ncsa.uiuc.edu>,
 Joe Greenseid <jgreen@ncsa.uiuc.edu>

=cut
