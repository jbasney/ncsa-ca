#
# setup-ncsa-ca.pl
# ----------------
# Adapts the globus/ssl environment to conform with Alliance certs and
# signing policies.
#
# Send comments/fixes/suggestions to:
# Chase Phillips <cphillip@ncsa.uiuc.edu>
#

use Getopt::Long;
use Cwd;

$gptpath = $ENV{GPT_LOCATION};
$gpath = $ENV{GLOBUS_LOCATION};

#
# sanity check environment
#

if (!defined($gpath))
{
    die "GLOBUS_LOCATION needs to be set before running this script"
}

#
# set up include path
#

if (defined($gptpath))
{
    @INC = (@INC, "$gptpath/lib/perl", "$gpath/lib/perl");
}
else
{
    @INC = (@INC, "$gpath/lib/perl");
}

require Grid::GPT::Setup;

my $globusdir = $gpath;
my $setupdir = "$globusdir/setup/gsi_ncsa_ca_services";
my $myname = "setup-ncsa-ca-services.pl";

#
# Backup-related variables
#

$curr_time = time();
$backup_dir = "backup_gsi_ncsa_ca_services_${curr_time}";

main();

exit;

#
# subroutines
#

sub main
{
    my(@certdirlist, $dirs, $response);

    printf("$myname: Configuring package gsi_ncsa_ca_services...\n");
    printf("-------------------------------------------------------------------------------\n");
    printf("Being the setup script for the gsi_ncsa_ca_services package, I do\n");
    printf("all of my work by copying a handful of certificate files into\n");
    printf("various directories.  In the odd case where I cannot find both the\n");
    printf("NCSA CA certificate and its signing policy in certain locations,\n");
    printf("but I do find one or the other alone, I will make a backup directory\n");
    printf("and copy the file I found into it (just in case).\n");
    printf("\n");

    @certdirlist = get_eligible_cert_dirs();
    $dirs = triageDirs(@certdirlist);

    if ( ! reviewDirs($dirs) )
    {
        printf("Your machine either has no eligible certificate directories or\n");
        printf("already has all of the certificate files and signing policies\n");
        printf("necessary to work with the NCSA CA.\n");

        printf("\n");
        printf("Exiting gsi_ncsa_ca_services setup.\n");
        exit(0);
    }

    $response = query_boolean("Do you wish to continue with the setup package?","y");

    if ($response eq "n")
    {
        print("\n");
        print("Exiting gsi_ncsa_ca_services setup.\n");

        exit(0);
    }

    install_certs($dirs);

    my $metadata = new Grid::GPT::Setup(package_name => "gsi_ncsa_ca_services");
    $metadata->finish();

    printf("\n");

    @installdirs = @{$dirs->{install}};   
    if (@installdirs)
    {
        printf("Additional Notes:\n");
        printf("\n");
        printf("  o A complete set of NCSA CA certificate files should now exist in\n");
        printf("    each of the directories listed above.  If, based on your local\n");
        printf("    needs, you need a copy of those CA files in an additional location,\n");
        printf("    just copy the files\n");
        printf("\n");
        printf("    \t5aba75cb.0 and\n");
        printf("    \t5aba75cb.signing_policy\n");
        printf("\n");
        printf("    from one of the following directories:\n");
        printf("\n");

        for my $dir (@installdirs)
        {
            printf("    \t$dir\n");
        }
    }

    printf("\n");
    printf("-------------------------------------------------------------------------------\n");
    printf("$myname: Finished configuring package gsi_ncsa_ca_services.\n");
}

sub triageDirs
{
    my (@dirlist) = @_;
    my @backupdirs, @installdirs;
    my $foo = {};

    $foo->{install} = \@installdirs;
    $foo->{backup} = \@backupdirs;

    if (@dirlist)
    {
        for my $d (@dirlist)
        {
            $num_certs = cert_files_present($d);

            if ( $num_certs eq "none" )
            {
                push(@installdirs, $d);
            }
            elsif ( $num_certs eq "some" )
            {
                push(@backupdirs, $d);
                push(@installdirs, $d);
            }
            else
            {
                ; # do nothing
            }
        }
    }

    return $foo;
}

sub reviewDirs
{
    my($foo) = @_;
    my(@installdirs, @backupdirs);

    @installdirs = @{$foo->{install}};
    @backupdirs = @{$foo->{backup}};

    if ( @installdirs or @backupdirs )
    {
        printf("The following directories will have certificate files installed into them:\n");
        printf("\n");

        for my $d (@installdirs)
        {
            if ( ! grep(/^$d$/, @backupdirs) )
            {
                printf("\t$d\n");
            }
            else
            {
                printf("\t$d (backup)\n");
            }
        }

        printf("\n");

        if (@backupdirs)
        {
            printf("NOTE: Those entries marked with '(backup)' are eligble to have\n");
            printf("those certificate files present in them be placed in a backup\n");
            printf("directory contained within their parent directory.  Those entries\n");
            printf("with no marking beside them suggest that I found no NCSA CA\n");
            printf("certficate files present in them and do not require any backup.\n");
            printf("\n");
        }

        return 1;
    }
    else
    {
        return 0;
    }
}

sub install_certs
{
    my ($dirs) = @_;
    my @backupdirs, @installdirs;
    my $dir_count = 0;

    @backupdirs = @{$dirs->{backup}};
    @installdirs = @{$dirs->{install}};

    print("\n[ Installing NCSA CA certificate and signing policy files ]\n");
    print("\n");

    #
    # well, @backupdirs should only ever be true if @installdirs is true, so
    # apologies.  testing both adds to readability of the code, imo, though.
    #

    if ( @installdirs or @backupdirs )
    {
        #
        # we've actually got directories to install our files into
        #

        if (@backupdirs)
        {
            printf("Creating backups of critical files...\n");
            for my $d (@backupdirs)
            {
                backup_cert_dir($d);
            }
        }

        if (@installdirs)
        {
            printf("Copying certificates and policies...\n");
            for my $d (@installdirs)
            {
                action("cp ${setupdir}/5aba75cb.0 ${d}/5aba75cb.0");
                action("chmod 644 ${d}/5aba75cb.0");

                action("cp ${setupdir}/5aba75cb.signing_policy ${d}/5aba75cb.signing_policy");
                action("chmod 644 ${d}/5aba75cb.signing_policy");
            }
        }
    }
}

    #
    # From <http://www.globus.org/security/v2.0/env_variables.html>
    #
    # GLOBUS_LOCATION
    # The GSI libraries use GLOBUS_LOCATION as one place to look for the trusted
    # certificates directory. The location $GLOBUS_LOCATION/share/certficates is
    # used if X509_CERT_DIR is not set and /etc/grid-security and
    # $HOME/.globus/certificates do not exist.
    #
    # to be safe, install certs into the following directories:
    #   /etc/grid-security/certificates
    #   $GLOBUS_LOCATION/share/certificates
    #   $X509_CERT_DIR
    #   $HOME/.globus/certificates
    #

sub get_eligible_cert_dirs
{
    my @dirlist, @eligible_dirs;

    #
    # we've got to do some hand-tailoring, since some of these entries are built
    # from environmental variables, while others are hardcoded.  any tests to ensure
    # that the directory path has been 'imported' correctly should occur here.
    #

    my $homedir = $ENV{HOME};
    my $x509_path = $ENV{X509_CERT_DIR};

    #
    # prepare for adding $GL/share/certificates to our path
    #

    if ( defined($x509_path) )
    {
        $dir = $x509_path;

        if ( ! -e $dir )
        {
            mkdirpath($dir);
        }

        if ( -d $dir )
        {
            push(@dirlist, $dir);
        }
    }

    #
    # prepare for adding /etc/grid-security/certificates to our path
    #

    $dir = "/etc/grid-security/certificates";

    if ( ! -e $dir )
    {
        mkdirpath($dir);
    }

    if ( -d $dir )
    {
        push(@dirlist, $dir);
    }

    #
    # prepare for adding $GL/share/certificates to our path
    #

    $dir = "$globusdir/share/certificates";

    if ( ! -e $dir )
    {
        mkdirpath($dir);
    }

    if ( -d $dir )
    {
        push(@dirlist, $dir);
    }

    #
    # prepare for adding $HOME/.globus/certificates
    #

    if ( defined($homedir) )
    {
        $dir = "$homedir/.globus/certificates";

        if ( ! -e $dir )
        {
            mkdirpath($dir);
        }

        if ( -d $dir )
        {
            push(@dirlist, $dir);
        }
    }

    #
    # build listing of eligible directories
    #

    for my $d (@dirlist)
    {
        $d =~ s!//+!/!g; # remove any series of 2 or more forward slashes
        $d =~ s!/$!!g;   # remove any trailing slashes

        if ( isMutable($d) )
        {
            push(@eligible_dirs, $d);
        }
    }

    return @eligible_dirs;
}

### isMutable( $dir )
#
# this function is used to simplify what could appear to be a complicated conditional
# into one name.
#

sub isMutable
{
    my ($dir) = @_;

    if ( ( -d $dir ) && ( -w $dir ) && ( -r $dir ) )
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

### cert_files_present( $dir_path )
#
# given some directory, return a string describing how many certificate files are
# present in that directory.
#

sub cert_files_present
{
    my ($dir_path) = @_;
    my $count, $max_count;

    $count = $max_count = 0;

    #
    # tally up the count of files present in our directory, along with the
    # maximum count along the way.
    #

    $max_count += 1;
    if ( -e "$dir_path/5aba75cb.0" )
    {
        $count += 1;
    }

    $max_count += 1;
    if ( -e "$dir_path/5aba75cb.signing_policy" )
    {
        $count += 1;
    }

    #
    # our counting is finished.  make our decision based on how many files
    # files are present.
    #

    if ( $count == 0 )
    {
        $retval = "none";
    }
    elsif ( $count == $max_count )
    {
        $retval = "all";
    }
    else
    {
        $retval = "some";
    }

    return $retval;
}

sub backup_cert_dir
{
    my ($dir_path) = @_;
    my $current_backup_dir;

    $current_backup_dir = "${dir_path}/${backup_dir}";

    #
    # sanity checking to make sure we're not going overboard
    #

    if ( ( ! -e "${dir_path}/5aba75cb.0" ) && ( ! -e "${dir_path}/5aba75cb.signing_policy" ) )
    {
        #
        # nothing to back up.
        #

        return 0;
    }

    #
    # verify that backup directory path exists
    #

    if ( ! mkdirpath($current_backup_dir) )
    {
        #
        # ouch.  couldn't make backup directories.
        #

        printf("Unable to make backup directory... not backing up files in ${dir_path}.\n");

        return 0;
    }

    #
    # copy current certs and signing policy to backup dir
    #

    if ( -e "${dir_path}/5aba75cb.0" )
    {
        action("mv ${dir_path}/5aba75cb.0 ${current_backup_dir}/5aba75cb.0");
    }

    if ( -e "${dir_path}/5aba75cb.signing_policy" )
    {
        action("mv ${dir_path}/5aba75cb.signing_policy ${current_backup_dir}/5aba75cb.signing_policy");
    }

    return 1;
}

sub action
{
    my ($command) = @_;

    printf "$command\n";

    my $result = system("$command 2>&1");

    if (($result or $?) and $command !~ m!patch!)
    {
        die "ERROR: Unable to execute command: $!\n";
    }
}

sub query_boolean
{
    my ($query_text, $default) = @_;
    my $nondefault, $foo, $bar;

    #
    # Set $nondefault to the boolean opposite of $default.
    #

    if ($default eq "n")
    {
        $nondefault = "y";
    }
    else
    {
        $nondefault = "n";
    }

    print "${query_text} ";
    print "[$default] ";

    $foo = <STDIN>;
    ($bar) = split //, $foo;

    if ( grep(/\s/, $bar) )
    {
        # this is debatable.  all whitespace means 'default'

        $bar = $default;
    }
    elsif ($bar ne $default)
    {
        # everything else means 'nondefault'.

        $bar = $nondefault;
    }
    else
    {
        # extraneous step.  to get here, $bar should be eq to $default anyway.

        $bar = $default;
    }

    return $bar;
}

#
# (void) s_output( $msg_type, $msg );
# print setup output to the user based on the type of message and the user's
# verbosity selection.
#
# +----------+-----------+
# | msg_type | msg_level |
# +----------+-----------+
# | error    | 0         |
# | warn     | 1         |
# | inform   | 2         |
# +----------+-----------+
#
# theory here is that if the user has:
#   o -v, --verbose=0, then they get all messages level 0;
#   o -vv, -v -v, --verbose=1, then they get all messages with levels 0 and 1;
#   o -vvv, -v -v -v, --verbose=2, then they get all messages with levels 0 through 2.
#

sub s_output
{
    my ($msg_type, $msg) = @_;

    #
    # for now, we default to not print anything but errors to the user
    #

    my $user_level = 0;

    if ($msg_type eq "inform")
    {
        $msg_level = 2;
    }
    elsif ($msg_type eq "warn")
    {
        $msg_level = 1;
    }
    elsif ($msg_type eq "error")
    {
        $msg_level = 0;
    }
    else
    {
        $msg_level = 0;
    }

    if ($user_level ge $msg_level)
    {
        print "$msg";
    }
}

### mkdirpath( $dirpath )
#
# given a path of one or more directories, build a complete path in the
# filesystem to match it.
#

sub mkdirpath
{
    my ($dirpath) = @_;

    #
    # watch out for extra debug stuff
    #

    $dirpath =~ s:/+:/:g;
    $absdir = absolutePath($dirpath);

    @directories = split(/\//, $absdir);
    @newdirs = map { $x = $_; $x =~ s:^\s+|\s+$|\n+::g; $x; }
               grep { /\S/ } @directories;

    #
    # prepare for our loop
    #

    $current_path = "";

    for my $d (@newdirs)
    {
        $current_path = $current_path . "/" . $d;

        #
        # cases where we should just go to the next iteration
        #

        if ( -d $current_path )
        {
            next;
        }

        #
        # we bomb out if we find something that exists in the filesystem
        # (and isn't a directory)
        #

        if ( -e $current_path )
        {
            return 0;
        }

        #
        # time to get to work
        #

        if ( ! myMkdir($current_path) )
        {
            return 0;
        }
    }

    return 1;
}

### myMkdir( $dir )
#
# try to create a directory
#

sub myMkdir
{
    my ($dir) = @_;
    my $result;

    # Perform the mkdir
    $result = system("mkdir $dir 2>&1");

    if ($result or $?)
    {
        return 0;
    }

    return 1;
}

### absolutePath( $file )
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
