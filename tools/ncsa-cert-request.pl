#!/usr/bin/perl
#
# ncsa-cert-request.pl
#
# Generate a certificate request which can be sent to the NCSA CA, who may
# subsequently sign it.  This script uses ncsa-ca.conf.
#
# When generating a certificate request for some types of certs (currently
# gatekeeper, host, and ldap), the -nopw option is simulated.  This
# guarantees that the key is not protected by a passphrase.
#

use Getopt::Long;
use Pod::Usage;
use Cwd;
use Data::Dumper;

#
# the upper portion of this file has a lot of global variable defines.
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

$versionid = "0.4.5";
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

#$man = 0;
#$help = 0;

#
# for our authentication with the ncsa ca, we're using openssl
#

my $secconfdir = "/etc/grid-security";
my $secure_tmpdir = "/tmp";
my $ssl_exec = "$gpath/bin/openssl";
my $ca_config = "$gpath/share/gsi_ncsa_ca_tools/ncsa-ca.conf";

my $req_input = "$secconfdir/req_input.$$";
my $req_output = "$secconddir/req_output.$$";
my $req_head = "$secconfdir/req_header.$$";

#
# default pathnames to various directories and files
#

$userhome = $ENV{HOME};
if ( !defined($userhome) && !defined($cl_dir) )
{
    die("HOME needs to be set before running this script without the --dir flag\n");
}

$default_dir = "$userhome/.certs";
$default_cert_file = "cert.pem";
$default_key_file = "key.pem";
$default_request_file = "req.pem";
$default_request_id_file = "request_id";

#
# info sent with the certificate
#

my $subject = "";
my $userid = "$>";
my $host = `$gpath/bin/globus-hostname`;
$host =~ s:^[\n]+|[\n]+$::g;

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
# argument specification
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
            'int|interactive' => \$interactive,
            'force' => \$force,
            'resubmit' => \$resubmit,
            'version' => \$version,
            'help|?' => \$help,
            'man' => \$man,
            'verbose' => \$verbose
          ) or pod2usage(2);

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

pod2usage(1) if $help;

#
# if $man is specified, exit with value 0 and print the entire pod document
#

pod2usage('-exitval' => 0, '-verbose' => 2) if $man;

main();

exit;

### cleanup( $item0, $item1, ... )
#
# remove some set of files
#
# WORKSFORME (cphillip)
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

#- readCommandLine () {
#-  # Expects $* from the shell invocation
#- 
#-   while [ "X$1" !=  "X" ]
#-   do
#-     case $1 in
#-       -cn | -commonname)
#-         COMMON_NAME="$2"
#-         shift ; shift
#-         ;;
#-
#-       -gatekeeper)
#-         SERVICE="gatekeeper"
#-         COMMON_NAME="$2"
#-         NO_DES="-nodes"
#-         shift ; shift
#-         ;;
#-
#-       -host)
#-         SERVICE="host"
#-         SERVICE_HOST="$2"
#-         NO_DES="-nodes"
#-         shift ; shift
#-         ;;
#-
#-       -ldap)
#-         SERVICE="ldap"
#-         SERVICE_HOST="$2"
#-         NO_DES="-nodes"
#-         shift ; shift
#-         ;;
#-
#-       -dir)
#-         CL_GLOBUS_DIR="$2"
#-         shift ; shift
#-         ;;
#-
#-       -cert|-certificate)
#-         CL_CERT_FILE="$2"
#-         shift ; shift
#-         ;;
#-
#-       -key)
#-         CL_KEY_FILE="$2"
#-         shift ; shift
#-         ;;
#-
#-       -req|-request)
#-         CL_REQUEST_FILE="$2"
#-         shift ; shift
#-         ;;
#-
#-       -nopw|-nodes|-nopassphrase)
#-         NO_DES="-nodes"
#-         shift
#-         ;;
#-
#-       -int|-interactive)
#-         INTERACTIVE="TRUE"
#-         shift
#-         ;;
#-
#-       -force)
#-         FORCE="TRUE"
#-         shift
#-         ;;
#-
#-       -resubmit)
#-         RESUBMIT="TRUE"
#-         shift
#-         ;;
#-
#-       *)
#-         globus_args_unrecognized_option "$1"
#-         ;;
#-    esac
#-  done
#- }

### preparePathsHash( $dir, $cert_file, $key_file, $request_file )
#
# create a hash based on the arguments passed to the subroutine
#

sub preparePathsHash
{
    my ($dir, $cert_file, $key_file, $request_file ) = @_;
    my $hash = {};

    $hash->{'dir'} = $dir;
    $hash->{'cert_file'} = $cert_file;
    $hash->{'key_file'} = $key_file;
    $hash->{'request_file'} = $request_file;

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
    $tmp_dir =~ s:^[\s]+|[\s]+$::g;
    if ( defined($tmp_dir) )
    {
        $dir = $tmp_dir;
    }
    else
    {
        $dir = $default_files->{'dir'};
    }

    if ( length($dir) == 0 )
    {
        printf("no directory specified!\n");
        exit;
    }

    if ( ! grep(/^\//, $dir) )
    {
        # make $tmp_dir an absolute path
        $dir = cwd() . "/" . $dir;
    }

    # create if it doesn't exist

    if ( ! -e $dir )
    {
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

    #
    # divine the path to the certificate file
    #

    $tmp = determineFile($default_files->{'request_file'}, $cl_files->{'request_file'}, "request file");
    $files->{'request_file'} = $dir . "/" . $tmp;

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
        $tmp_file =~ s:^[\s]+|[\s]+$::g;
    }
    else
    {
        $tmp_file = $default;
    }

    if ( length($tmp_file) == 0 )
    {
        printf("no $name specified!\n");
        exit;
    }

    #
    # check that the chosen file doesn't have any slashes in it (isn't a path)
    #

    if ( grep(/\//, $tmp_file) )
    {
        printf("$name can only be a filename!\n");
        exit;
    }

    #
    # check that, if our choice exists, we can write to it
    #

    if ( ( -e $tmp_file ) && ( ! -w $tmp_file ) )
    {
        printf("can't write to $tmp_file");
        exit;
    }

    return $tmp_file;
}

### makeDir( $path )
#
# creates the directory structure in $path if it doesn't already exist
#

sub makeDir
{
    my ($path) = @_;
    my (@dirs, $curr_dir);

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
# WORKSFORME (cphillip)
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

### createInputFileString( $commonname, $ca_config_filename )
#
# create the inputs to the ssl program at $filename, appending the common name to the
# stream in the process
#
# WORKSFORME (cphillip)
#

sub createInputFileString
{
    my ($commonname, $ca_config_filename) = @_;
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

    $output .= $commonname . "\n";

    return $output;
}

### createServiceRequestHeader( $request_id_file, $contact_url, $contact_email_addr, $subject )
#
# generate the request header for a generic service
#
# WORKSFORME (cphillip)
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
# WORKSFORME (cphillip)
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
# WORKSFORME (cphillip)
#

sub readFile
{
    my ($filename) = @_;

    # my ($size, $data, $rc);
    #
    # open(FILE, "$filename") or die "ERROR: cannot open $filename";
    # $size = (stat($filename))[7];
    # $rc = read(FILE, $data, $size);

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
# WORKSFORME (cphillip)
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
# check the system for preexisting valid files.  remove them if '--force' was
# given as an argument.
#
# WORKSFORME (cphillip)
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
        die("Do not know how to get CN for type '$type'");
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
        printf("Enter your name [eg. John Smith]: ");
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
        printf("Enter the FQDN of your host [eg. foo.bar.edu]: ");
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
        printf("Enter the FQDN of your host [eg. foo.bar.edu]: ");
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

### createCerts( )
#
# use $ssl_exec program to create the key and certificate files on a system
#

sub createCerts
{
    my ($umsk);

    if (length($type) == 0)
    {
        printf("A certificate request and private key is being created.\n");
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
    # create the key and request files
    #
 
    if ($interactive)
    {
        # REM
        # action("${ssl_exec} req -new -keyout ${key_file} -out ${req_output} -config ${ca_config} ${no_des}");
    }
    else
    {
        $tmpstring = createInputFileString( $name, $ca_config );
        writeFile($req_input, $tmpstring);
        # REM
        # action("${ssl_exec} req -new -keyout ${key_file} -out ${req_output} -config ${ca_config} ${no_des} < ${req_input}");
 
        cleanup($req_input);
    }

    #- the following code should emulate this routine
    #- SUBJECT="`${SSL_EXEC} req -text -noout < ${REQ_OUTPUT} 2>&1 |\
    #-        ${GLOBUS_SH_GREP-grep} 'Subject:' | ${GLOBUS_SH_AWK-awk} -F: '{print $2}' |\
    #-        ${GLOBUS_SH_CUT-cut} -c2- `"

    action("${ssl_exec} req -text -noout < ${req_output} 2>&1 > ${tmpfile}");
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
    cleanup($req_head, $req_output);

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

    $value =~ s/%/%25/g;
    $value =~ s/@/%40/g;
    $value =~ s/&/%26/g;
    $value =~ s/ /+/g;

    $str = "$var=$value";

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
    my ($contents);

    $contents = readFile($file);

    #
    # Special characters: +, /, =, \n, and spaces (" ") are given their
    # appropriate corresponding hex values for proper transmission via HTTP
    #
    # the same url-encoding statements go for this are as for printPostData.
    # since multiple areas of this script use url-encoding (every one dealing
    # with posting info via http) we may consider just queueing up the url-
    # encoding for one big shot right before the submittal.
    #

    $contents =~ s/\+/%2B/g;
    $contents =~ s/ /+/g;
    $contents =~ s/\//%2F/g;
    $contents =~ s/=/%3D/g;
    $contents =~ s/\n/%0D%0A/g;

    #
    # You may choose to substitute your own demarcation strings, if you do not
    # like these.
    #

    $start_string = "BEGIN CERTIFICATE REQUEST";
    $end_string = "END CERTIFICATE REQUEST";

    #
    # However, if you do decide to change the above strings, you may have to edit
    # these regexps to take into account special characters, if you use them.
    # These expressions are designed to work for strings which use only:
    #   letters: [A-Z][a-z]
    #    spaces: " "
    #

    $start_string =~ s/ /\\+/g;
    $end_string =~ s/ /\\+/g;

    #
    # Set $contents to be everything that exists between
    # $start_string and $end_string
    #

    $contents =~ s/^.*$start_string(.*)$end_string.*$/$1/g;

    #
    # These expressions undo some of the changes made above.  After these
    # expressions are evaluated, $start_string and $end_string no longer
    # contain the character "\"
    #

    $start_string =~ s/\\//g;
    $end_string =~ s/\\//g;

    #
    # The evaluation above ($contents =~ s/.../$1/g) pulls out everything between
    # $start_string and $end_string.  In order to have the correct string to
    # transmit, we need to prepend and append $start_string and $end_string
    #

    $formatted = $start_string.$contents.$end_string;

    return ($formatted);
}

### handleSuccessfulPost( $post_out_file )
#
# get the request id number from the output file generated via the post
#

sub handleSuccessfulPost
{
    my ($post_out_file) = @_;
    my ($data, $request_id);
    my (@strs, @splitdata);

    readFile($post_out_file);

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

    printf("Your certificate request for an Alliance certificate has been successfully\n");
    printf("sent to the Alliance Certificate Authority (CA).\n");
    printf("\n");
    printf("You must now follow the directions on the following web page in order\n");
    printf("to complete the request process:\n");
    printf("\n");
    printf("${url_howto_complete}\n");
    printf("\n");
    printf("If you have any questions or concerns please contact Alliance consulting\n");
    printf("at ${contact_email_addr}\n");
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
        printf("A server error occurred: ${server_error}\n");
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

### postReq( )
#
# Post the req to the web server.
#

sub postReq
{
    my ($server, $port, $enroll_page);
    my ($post_data_file, $post_cmd_file, $post_out_file);
    my ($extra_email);

    # https://ca.ncsa.edu/NCSAUserGridCertEnroll.html
    $server = "ca.ncsa.edu";
    $port = "443";
    $enroll_page = "/enrollment";

    # Temporary files
    $post_data_file = "${secure_tmpdir}/$program_name.$$.post_data";
    $post_cmd_file = "${secure_tmpdir}/$program_name.$$.post_cmd";
    $post_out_file = "${secure_tmpdir}/$program_name.$$.post_out";

    $req_content = processReqFile($request_file);

    $comment = "host=$host";

    cleanup($post_data_file);

    # Build the post data
    $postdata .= "pkcs10Request=${req_content}";
    $postdata .= "%0D%0A&";

    $postdata .= printPostData("csrRequestorName", "${common_name}");
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

    # Get number of bytes we are posting
    $content_len = (stat($post_data_file))[7];
		
    # Now build the actual text for sending to the web server
    $postcmd .= "POST ${enroll_page} HTTP/1.0\n";
    $postcmd .= "Content-type: application/x-www-form-urlencoded\n";
    $postcmd .= "Content-length: ${content_len}\n";
    $postcmd .= "User-Agent: ${user_agent}\n";
    $postcmd .= "\n";
    $postcmd .= $postdata;

    cleanup($post_data_file);

    open(OUTPUT, ">$post_cmd_file");
    print OUTPUT $post_cmd_file;
    close(OUTPUT);

    #
    # Sleep to give server a chance to respond
    #

    #- (cat ${POST_CMD_FILE}; sleep 10) | ${SSL_EXEC} s_client -quiet -connect ${SERVER}:${PORT} > ${POST_OUT_FILE} 2>&1
    # REM
    # action("(cat $post_cmd; sleep 10) | ${ssl_exec} s_client -quiet -connect ${server}:${port} > ${post_out_file}");

    $data = readFile($post_out_file);

    if ( grep(/CMS Request Pending/, $data) )
    {
        handleSuccessfulPost(${post_out_file});

        cleanup(${post_out_file});
    }
    else
    {
        handleFailedPost(${post_out_file});

        #
        # Append the POST_CMD_FILE to the POST_OUT_FILE and then leave it so
        # that it can be used for debugging.
        #

        action("cat ${post_cmd_file} >> ${post_out_file}");
    }

    cleanup(${post_cmd_file});
}

### getUserEmail( )
#
# get the email address for the user cert request
#

sub getUserEmail
{
    my ($userinput, $start, $valid) = ("", 1, 0);

    #
    # if the value is invalid, or was undefined, we loop over the user's input
    #

    while ( ! $valid )
    {
        printf("Enter your full email address [eg. user\@somewhere.edu]: ");
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
        printf("A valid email address is required!\n") unless quiet;
        return 0;
    }

    if ( ! grep(/@/, $userinput ) )
    {
        printf("A valid email address is required!\n") unless quiet;
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
        printf("A valid phone number is required!\n") unless quiet;
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
        $output .= "or visit\n";
        $output .= "\n";
        $output .= "${contact_url}\n";
        printf("$output");
        exit;
    }

    if ( ! -e $request_file )
    {
        push(@error, "certificate request file ($request_file)");
    }

    if ( ! -e $key_file )
    {
        push(@error, "certificate key file ($key_file)");
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
        $output .= "request and apparently need to run ${program_name} without\n";
        $output .= "-resubmit.\n";
        $output .= "\n";
        $output .= "If you want assistance please email ${contact_email_addr}\n";
        $output .= "or visit\n";
        $output .= "\n";
        $output .= "${contact_url}\n";
        printf("$output");
        exit;
    }

    # Everything checks out
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
    printf("Press return to continue\n");

    $foo = <STDIN>;
}

### absolutePath( )
#
# accept a list of files and, based on our current directory, make their pathnames absolute
#

sub absolutePath
{
    my @files = @_;
    my $cwd = abs_path();

    for my $f (@files)
    {
        if ($f !~ /^\//)
        {
            $f = abs_path($f);
        }
    }

    return @files;
}

### inform( $content, $override )
#
# inform the user of an event
#

sub inform
{
    my ($content, $override) = @_;

    print "$content\n" if $verbose or defined $override;
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
        inform("Changing to $dir");
        chdir $dir;
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
        inform("Changing to $pwd");
        chdir $pwd;
    }
}

### main( )
#
# driver function
#

sub main
{
    #
    # based on the type, build the path to the certificates
    #

    $cl_files = preparePathsHash($cl_dir, $cl_cert_file, $cl_key_file, $cl_request_file);
    $default_files = preparePathsHash($default_dir, $default_cert_file, $default_key_file, $default_request_file);
    $files = determinePaths($default_files, $cl_files);

    printf("%s\n", Dumper($files));

    $cert_file = $files->{'cert_file'};
    $key_file = $files->{'key_file'};
    $request_file = $files->{'request_file'};

    # <testing>
    checkCerts($cert_file, $key_file, $request_file);

    exit;
    # </testing>

    checkGlobusSystem($ca_config);

    if ( ! $resubmit )
    {
        checkCerts($cert_file, $key_file, $request_file);
    }

    if ($resubmit)
    {
        checkResubmit();
    }
    else
    {
        printPreamble();

        $name = getCN($type, $name);
    }

    # Additional stuff for ncsa-cert-req
    $user_email = getUserEmail();
    $user_phone = getUserPhone();
    printf("\n\n");

    createCerts();

    #-  COMMON_NAME="`echo ${SUBJECT} | ${GLOBUS_SH_SED-sed} -e 's|^.*/CN=||'`"
    # what do i replace the above with?

    postReq();

    cleanup($req_head, $req_output, $req_input);
}

__END__

=head1 NAME

ncsa-cert-request - Request a certificate from the NCSA CA

=head1 SYNOPSIS

ncsa-cert-request [options]

  Help-Related Options:
    --help       brief help message
    --man        full documentation

=head1 OPTIONS

=over 8

=item B<--type=<cert_type>>

Create a certificate request of type <type>.

=item B<--name=<name>>

Set the name to include in the certificate request to <name>.

=item B<--dir=<dir_name>>

User-specified certificate directory. (e.g. $HOME/.globus)

=item B<--cert=<file>>

File name of the certificate.

=item B<--key=<file>>

File name of the user key.

=item B<--req=<file>>

File name of the certificate request.

=item B<--nopw>

Create the certificate without a password.

=item B<--interactive>

Prompt user for each component of the DN.

=item B<--force>

Overwrite any prexisting certificates.

=item B<--resubmit>

Resubmit a previously generated certificate request.

=item B<--verbose>

Increase the amount of output that will be generated by the program.

=item B<--version>

Print the version identifier of this program and exit.

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print the manual page and exit.

=back

=head1 DESCRIPTION

B<ncsa-cert-request> will request a certificate from the NCSA certificate
authority.  This program understands three different types of certificates:

    host
      A certificate of type 'host' represents a validation that the machine
      is truly affiliated with its current institution.

    user
      The user certificate is a representation that the NCSA CA has verified
      a user's affiliation with their organization.

    ldap
      The ldap certificate is a representation that the NCSA CA has verified
      the affiliation between a machine's ldap service and its organization.

    gatekeeper
      Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam
      nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat
      volutpat.

Drink your ovaltine!

=cut