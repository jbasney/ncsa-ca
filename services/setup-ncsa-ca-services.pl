#
# setup-ncsa-ca.pl
# ----------------
# Adapts the globus/ssl environment to conform with Alliance certs and
# signing policies.
#
# Send comments/fixes/suggestions to:
# Chase Phillips <cphillip@ncsa.uiuc.edu>
#

$gptpath = $ENV{GPT_LOCATION};
$gpath = $ENV{GLOBUS_LOCATION};

#
# sanity check environment
# ------------------------
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

#
# define global variables
# -----------------------
# Get user's GPT_LOCATION since we may be installing this using a new(er)
# version of GPT.
#

my $globusdir = $gpath;
my $setupdir = "$globusdir/setup/gsi_ncsa_ca_services";
my $secconfdir = "/etc/grid-security";
my $myname = "setup-ncsa-ca-services.pl";

#
# Set up path prefixes for use in the path translations
#

$prefix = ${globusdir};
$exec_prefix = "${prefix}";
$bindir = "${exec_prefix}/bin";

#
# Backup-related variables
#

$curr_time = time();
$backup_dir = "backup_gsi_ncsa_ca_services_${curr_time}";

#
# For now, assume that we are root (until we build command-line switches for this
# sort of thing)
#

$uid = $>;

if ($uid != 0)
{
    print "--> NOTE: You must be root to run this script! <--\n";
    exit 0;
}

#
# define main subroutines
# -----------------------
#

#
# We need to make sure it's okay to copy our setup files (if some files are already
# present).  If we do copy any files, we backup the old files so the user can (possibly)
# reverse any damage.
#

#
# perl modes
# 16877 = 755
#

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

sub s1_install_certs
{
    my (@dirlist) = @_;
    my @backupdirs, @installdirs;
    my $dir_count = 0;

    print "\nStage 1: Installing NCSA CA certificate and signing policy files..\n";
    print "\n";

    #
    # alternatively, we could create separate lists for backups, and installs
    #

    printf "Looking for directories to install my files into..\n";

    for my $d (@dirlist)
    {
        $num_certs = cert_files_present($d);

        if ( $num_certs eq "none" )
        {
            printf "  $d\n";

            push(@installdirs, $d);
            $dir_count += 1;
        }
        elsif ( $num_certs eq "some" )
        {
            printf "  $d (backup)\n";

            push(@backupdirs, $d);
            push(@installdirs, $d);
            $dir_count += 1;
        }
        else
        {
            ; # do nothing
        }
    }

    if ( $dir_count >= 1 )
    {
        #
        # we've actually got directories to install our files into
        #

        printf "\n";
        printf "Directories found: $dir_count\n";
        printf "\n";
        printf "Those entries marked with '(backup)' have some certificate files\n";
        printf "present, but not all.  Those with no marking beside them suggest\n";
        printf "that I found no NCSA CA certficate files present in them.\n";
        printf "\n";

        printf "Creating backups of critical files..\n";
        for my $d (@backupdirs)
        {
            printf "$d\n";

            backup_cert_dir($d);
        }

        printf "Copying certificates and policies..\n";
        for my $d (@installdirs)
        {
            printf "$d\n";

            action("cp ${setupdir}/5aba75cb.0 ${d}/5aba75cb.0");
            action("chmod 644 ${d}/5aba75cb.0");

            action("cp ${setupdir}/5aba75cb.signing_policy ${d}/5aba75cb.signing_policy");
            action("chmod 644 ${d}/5aba75cb.signing_policy");
        }
    }
    else
    {
        printf "Your machine either has no eligible certificate directories or\n";
        printf "already has all of the certificate files and signing policies\n";
        printf "necessary to work with the Alliance CA.\n";
    }
}

sub get_eligible_cert_dirs
{
    #
    # we've got to do some hand-tailoring, since some of these entries are built
    # from environmental variables, while others are hardcoded.  any tests to ensure
    # that the directory path has been 'imported' correctly should occur here.
    #

    my $homedir = $ENV{HOME};
    my $x509_path = $ENV{X509_CERT_DIR};

    my @dirlist, @eligible_dirs;

    if ( defined($x509_path) )
    {
        push(@dirlist, $x509_path);
    }

    push(@dirlist, "/etc/grid-security/certificates");
    push(@dirlist, "$globusdir/share/certificates");

    if ( defined($homedir) )
    {
        push(@dirlist, "$homedir/.globus/certificates");
    }

    #
    # build listing of eligible directories
    #

    for my $d (@dirlist)
    {
        $d =~ s!//+!/!g; # remove any series of 2 or more forward slashes
        $d =~ s!/$!!g;   # remove any trailing slashes

        if ( -d "$d" )
        {
            push(@eligible_dirs, $d);
        }
    }

    return @eligible_dirs;
}

#
# $retval = cert_files_present($dir)
# this function returns true if and only if both 5aba75cb.0 and 5aba75cb.signing_policy
# are both present in '$dir'.
#

sub cert_files_present
{
    my ($dir_path) = @_;
    my $count, $max_count;

    $count = $max_count = 0;

    #
    # we are looking for 5aba75cb.0 and 5aba75cb.signing_policy
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

#
# begin main
# ----------
#

#
# parse command line options
# --------------------------
# for now, no command-line options
# ideally, we would have --root and --non-root
# (this would effect which directories the files get installed into)
#

#
# verify directories
# backup files
#   /etc/grid-security/ncsa-ca-bak-{time}/
#     grid-security.conf
#     globus-user-ssl.conf
#     globus-host-ssl.conf
#     certificates/
#       5aba75cb.0
#       5aba75cb.signing_policy
# install the ncsa ca cert and policy
#
# file: grid-security.conf
# phase 1: modify (call grid-security-config)
# phase 2: move (cp grid-security.conf to /etc/grid-security/)
#
# file: globus-{host,user}-ssl.conf
# phase 1: modify (call grid-cert-request-config)
# phase 2: move (cp these files to /etc/grid-security/)
#
# file: ncsa-cert-{request,retrieve}
# phase 1: modify (run fixpaths() on this file to swap out the @ARCH@ variable)
# phase 2: move (cp files into $GL/bin/)
#

printf "---------------------------------------------------------------\n";
printf "$myname: Configuring package gsi_ncsa_ca_services..\n";
printf "\n";
printf "Hi, I'm the setup script for the gsi_ncsa_ca_services package!\n";
printf "\n";

@certdirlist = get_eligible_cert_dirs();

printf "I do a lot of my work by modifying and then copying a handful of\n";
printf "files.  The directories that may be affected by this install\n";
printf "include:\n";
printf "\n";

for my $d (@certdirlist)
{
    printf "  $d\n";
}

printf "\n";
printf "I will make backups of any files that may need to be overwritten.\n";
printf "\n";

$response = query_boolean("Do you wish to continue with the setup package?","y");

if ($response eq "n")
{
    print "\n";
    print "Okay.. exiting gsi_ncsa_ca_services setup.\n";

    exit 0;
}

s1_install_certs(@certdirlist);

my $metadata = new Grid::GPT::Setup(package_name => "gsi_ncsa_ca_services");

$metadata->finish();

print "\n";
print "$myname: Finished configuring package 'gsi_ncsa_ca_services'.\n";
print "---------------------------------------------------------------\n";

#
# define support subroutines
# --------------------------
# Just need a minimal action() subroutine for now..
#

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

sub mkdirpath
{
    my ($dirpath) = @_;

    my $start;
    my @directories;
    my $current_path;

    $current_path = "";

    @directories = split(/\//, $dirpath);

    $start = 1;

    for my $d (@directories)
    {
        if ($start eq 1)
        {
            $start = 0;
            $current_path = $d;
        }
        else
        {
            $current_path = $current_path . "/" . $d;
        }

        if ( (length($current_path) eq 0) )
        {
            next;
        }

        if ( ! -d "$current_path" )
        {
            if ( -e "$current_path" )
            {
                s_output("error", "Could not make directory: '$current_path'... already exists as non-directory.\n");

                return 0;
            }

            s_output("inform", "Could not find directory: '$current_path'... creating.\n");
            print "Could not find directory: '$current_path'... creating.\n";
            mkdir($current_path, 16877);
            # 16877 should be 755, or drwxr-xr-x
        }
    }

    return 1;
}
