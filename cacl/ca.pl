#!/usr/local/bin/perl -w
# 
# Copyright (c) 2002 The Regents of the University of California. All
# rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met: 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following
# disclaimer. 2. Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution. 3. All advertising materials mentioning features or use
# of this software must display the following acknowledgement: This
# product includes software developed by the San Diego Supercomputer
# Center and its contributors. 4. Neither the name of the Center nor the
# names of its contributors may be used to endorse or promote products
# derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
#
# SDSC Certificate Authority Daemon
# June, 2000 
# Wayne Schroeder  http://www.sdsc.edu/~schroede 
#
# Revised by: William J. Link
# September, 2001

# This is the daemon side of a CA system developed at SDSC.  There are
# two pieces to this system, this daemon and the client utility.  The
# client and daemon communicate via sockets.  There is also some
# shared files, such as the CA certificate.  The utility generates the
# requests and sends it to this daemon for processing.  The daemon
# utilizes OpenSSL commands to perform the actual certificate signing,
# and related functions.

# User identity is confirmed via the user's local login password.  The
# certificate request is encrypted with the CA's public key (from it's
# certificate) since this password is included with the request.

# See the utility (developed by Bill Link) for more information.

# parameters:
$PORT=3434;
$CERTDIR="/certman/CA_SYSTEM";
$KEYDIR="$CERTDIR/ca.db.keys";
$PUB_PKI_DIR="/projects/security/PKI";
$PUB_CERT_DIR="/projects/security/PKI/certificates";
$REQUEST_FILE_U="$CERTDIR/work/request_u.txt"; # unencrypted request file
$CA_KEY="$CERTDIR/ca.key";
$CA_CERT="$CERTDIR/ca.pem";
$PW_FILE="/sdsc/local/generic/sdscbin/PAS/data/master_accnts.db";
$CONF="$CERTDIR/sdsc.cnf";
$OSSL="/usr/local/apps/openssl/bin/openssl";
$WORKDIR="$CERTDIR/work/";
$LOGFILE="$CERTDIR/CA.log";
@inetaddr=("0","0","0","0");
@TF173I_IP=("132","249","20","148");
@TF174I_IP=("132","249","20","147");
@TF004I_1_IP=("192","67","82","4");
@TF004I_2_IP=("192","67","21","205");
@ULTRA_IP=("132","249","20","141");
@GAOS_IP=("132","249","20","170");
@APOGEE_IP=("198","202","75","80");
@PERIGEE_IP=("198","202","75","81");

    use Socket;

    socket_setup();

    for (;;) {
        $SERIAL = `cat $CERTDIR/ca.db.serial`;
        chomp ($SERIAL); 
Åwait_for_and_rcv_request();

        $msg = "No msg yet\n";

Ådo_CA_stuff();

Åprintf("msg=%s\n",$msg);
        
        $logdate = `date`;
Å$do_copy=0;
        if ($msg eq "Success\n") {
 Å   $msg2 = `cat $cert_file`;
 Å   $msg = "Success ".$msg2;
           `echo "$logdate" >> $LOGFILE`;
           `echo "$msg" >> $LOGFILE`;
Å   $do_copy=1;
        }
        else {
           $msg2 = $msg;
           $msg = "Error   ".$msg2;
           `echo "$logdate" >> $LOGFILE`;
           `echo "$msg" >> $LOGFILE`;
        }

        send(NS,$msg,0);
        if ($do_copy) {
           shutdown(NS, 1);
           get_key();
        }
        close(NS);

        unlink $REQUEST_FILE_U;
        unlink $cert_file;
        unlink $error_file;
        unlink $request_file;

Åif ($do_copy==1) {
Å    copy_certs();
Å}
    }


#
# Do the Certificate Authority processing, set msg to result
#
sub do_CA_stuff {

# decrypt (Note that having a password on the private key doesn't really
# make it much more secure (it is access to the key that is
# controlled), but what the heck...

    `echo "$CP"|$OSSL smime -decrypt -in $request_file -out $REQUEST_FILE_U -recip $CA_CERT -inkey $CA_KEY -passin stdin`;
    if ($? != 0) {
         $msg = "request decrypt failed\n";
Åreturn;
    }

# check fields

    check_req_fields();
    if ($msg ne "No msg yet\n") {return;}

# check the master passwd file to verify the information in the cert request

    if (("@inetaddr" eq "@TF173I_IP") || ("@inetaddr" eq "@TF174I_IP")
         || ("@inetaddr" eq "@TF004I_1_IP") || ("@inetaddr" eq "@TF004I_2_IP")) {
       printf("Checking $PW_FILE for Bluehorizon\n");
       check_pw($PW_FILE,"bigblue");
    } elsif (("@inetaddr" eq "@ULTRA_IP") || ("@inetaddr" eq "@GAOS_IP")) {
       printf("Checking $PW_FILE for HPC Sun systems, ultra or gaos\n");
       check_pw($PW_FILE,"HPC_Sun"); 
    } elsif  (("@inetaddr" eq "@APOGEE_IP") || ("@inetaddr" eq "@PERIGEE_IP")) {
       printf("Checking $PW_FILE for HPC Sun systems, apogee or perigee\n");
       check_pw($PW_FILE,"HPC_Sun"); 
    } else {
       printf("Checking $PW_FILE for workstation\n");
       check_pw($PW_FILE,"workstation");
    }

    if ($msg ne "No msg yet\n") {return;}

# everything looks good, attempt to issue and sign it

    sign_it();

    if ($msg eq "No msg yet\n") {$msg="Internal error\n";} #shouldn't happen

}

#
# Issue and sign the certificate
#
# Note that the OpenSSL CA command will make additional checks on the
# request.  In particular, it will not issue a certificate that matches
# an existing certificate.
#
sub sign_it {
     
     if ($CN=~ /Guest/i) {
        `echo "y\ny\n" | $OSSL ca -config $CONF -days 7 -in $REQUEST_FILE_U -out $cert_file -key $CP 2> $error_file`;      
     } else {
        `echo "y\ny\n" | $OSSL ca -config $CONF -in $REQUEST_FILE_U -out $cert_file -key $CP 2> $error_file`;
     } 
     if ($? != 0) {
Åunlink $cert_file;  # clean up 0 length cert on error
Å$msg2 = `cat $error_file`;
Å$msg = "Signing failed:\n".$msg2;
Åreturn;
     }
     chmod (0444, $cert_file);
     $msg = "Success\n";

}

#
# Check the user-entered password and verify the Common Name.  This is a little
# complicated because this information can be found in different locations 
# depending on which machine is being checked.
#
sub check_pw {  

    $PW=`$OSSL req -config $CONF -text -in $REQUEST_FILE_U 2>$error_file | grep challengePassword`;
    if (!$PW) {
Å$msg=`cat $error_file`;
Åreturn;
    }
    
    $PW=substr($PW,index($PW,":")+1);
    chop($PW);

    $pwline="none";
    if (($_[1] eq "bigblue") || ($_[1] eq "HPC_Sun")) {
        $uidtest = $USERID."-hpc:";
    } else {
        $uidtest = $USERID.":";
    }

    $pwgrep=`grep $uidtest $_[0]`;
    @lines=split(/\n/, $pwgrep);
    foreach $line (@lines) {
        if (index($line,$uidtest) == 0) {
Å    $pwline = $line;
        }
    }

    if ($pwline eq "none") {
       $msg="User not found in password file\n";
       return;
    }

    @pwitems = split(":",$pwline);
    if ($_[1] ne "bigblue") {
       $PASSWORD = $pwitems[1];
    } else {
       $PASSWORD = $pwitems[10]
    }

    if (length($PASSWORD) < 2) {
Å$msg="No password in password file for user\n";
Åreturn;
    }

    $name = $pwitems[4];  # get the 5th field from the entry
    $name =~ s/,.*$//;
    if ($name ne $CN) {
        $msg="CN ($CN) does not match name in password file ($name)\n";
        return;
    }

    $SALT = substr($PASSWORD, 0, 2);
    $E_PW = crypt($PW, $SALT);

    if ($PASSWORD ne $E_PW) {
        $msg = "The login password you entered is incorrect\n";
       return;
    }
    return;

}

#
# Check that the request parses OK and the fields are correct.
# And set the USERID and CN fields.
#
sub check_req_fields {
    $DN=`$OSSL req -config $CONF -text -in $REQUEST_FILE_U 2>$error_file | grep Subject:`;
    if (!$DN) {
Å$msg=`cat $error_file`;
Åreturn;
    }
    printf("DN=%s\n",$DN);
    if (index($DN,"C=US")<0) {
        $msg="Not correct country field C=US\n";
Åreturn;
    }
    if (index($DN,"O=NPACI")<0) {
        $msg="Not correct organization O=NPACI\n";

Åreturn;
    }
    if (index($DN,"OU=SDSC")<0) {
        $msg="Not correct organizational unit OU=SDSC\n";
Åreturn;
    } 
    $CN=substr($DN,index($DN,"CN=")+3);
    $CN=substr($CN,0,index($CN,"/"));

    $USERID=substr($DN,index($DN,"USERID=")+7);
    chop($USERID);
    $nextfld = index($USERID, "/");
    if ($nextfld>0) {
       $USERID=substr($USERID,0,$nextfld);
    }
    return;
}


#
# Wait for a connection to come in.
# When one does, read the data and store it into a file until the
# end-flag message is received.  Then update the ca.db.index file
# by checking for expired certificates that still have a valid status
# and changing the status to expired.
# 
sub wait_for_and_rcv_request {
        $CP = `cat $ENV{"HOME"}/.cp"`;
        chomp ($CP);
        print "Listening \n";
        ($addr = accept(NS,S)) || die $!;
        print "accept ok\n";

        ($af,$PORT,$inetaddr) = unpack($sockaddr,$addr);
        @inetaddr = unpack('C4',$inetaddr);
        print "$af $PORT @inetaddr\n";
 
        $date=`date +%y%m%d_%H%M%S`;
        chop($date);
Å$base_name = $WORKDIR.$date;
Å$request_file=$base_name.".req";
        $error_file=$base_name.".err";
Å$cert_file=$base_name.".cert";


Åopen(F, ">".$request_file);

        $count=0;
Åwhile (<NS>) {   # read NS (new socket) and put it in variable $_
Å     last if $_ eq "All done\n";
             print F;
Å     $count++;
        }
Åclose(F);

        mark_expired_certs_in_index();
}

#
# Set up a server-type socket (bound to a specific port)
#
sub socket_setup {

    $name = 0;
    $family = 0;
    $aliases = 0;
    $sockaddr = 'S n a4 x8';

    ($name, $aliases, $proto) = getprotobyname('tcp');

    $this = pack($sockaddr, &AF_INET, $PORT, "\0\0\0\0");

    socket(S, &AF_INET, &SOCK_STREAM, $proto) || die "socket: $!";
    bind(S, $this) || die "bind: $!";

    $mysockaddr = getsockname(S);
    ($family,$myport) = unpack($sockaddr,$mysockaddr);
    printf("port=%d\n",$myport);

    listen(S, 1) || die "listen: $!";

    select(S);  $| = 1;  select(STDOUT); #set S to force flush after write
}

#
# Copy Certs.
# Copy all recently created certificates to a shared directory
#
sub copy_certs {
   print ("Copying files to $PUB_CERT_DIR.\n\n");
   $certs=`find $CERTDIR/ca.db.certs -mtime -2 -type f -print`;
   @certfiles=split(/\n/, $certs);
   foreach $certfile (@certfiles) {
      chmod 0644, "$certfile";
      `cp -p $certfile $PUB_CERT_DIR`;
    }

    `cp "$CERTDIR/ca.db.index" $PUB_PKI_DIR`;
}

#
# 
#  This subroutine goes through the ca.db.index file, finds expired 
#  certificate entries, and updates their status field  from V (valid) to 
#  E (expired).  This update allows users whose certificates have expired
#  to have new certificates issued.
#
sub mark_expired_certs_in_index {

$CHANGED=0;
$NOW=`/bin/date +%y%m%d%H%M%S`;
chomp $NOW;

open(IN,"$CERTDIR/ca.db.index");
open(OUT,">$CERTDIR/ca.db.index.new");
select(OUT);
while (<IN>) {
   @FIELDS = split(" ");
   $STATUS = $FIELDS[0];
   $EXPIRATION = $FIELDS[1];
   chop $EXPIRATION;
   if (($EXPIRATION le $NOW) && ($STATUS eq "V")) {
      s/V/E/;
      $CHANGED=1;
   }
   print;
}

close(IN);
close(OUT);
select(STDOUT);

if ($CHANGED) {
    printf("Marking expired certificates in ca.db.index file.\n");
    unlink ("$CERTDIR/ca.db.index.old");
    rename ("$CERTDIR/ca.db.index","$CERTDIR/ca.db.index.old");
    rename ("$CERTDIR/ca.db.index.new","$CERTDIR/ca.db.index");
    `cp "$CERTDIR/ca.db.index" $PUB_PKI_DIR`;
} else {
    unlink ("$CERTDIR/ca.db.index.new");
}

}

#
# This subroutine gets and stores the encrypted private key for the
# certificate which was just issued.
#
sub get_key {

print "Waiting for key. \n";

open(F, ">$KEYDIR/$SERIAL.key");

$count=0;
while (<NS>) {   # read NS (new socket) and put it in variable $_
   last if $_ eq "All done\n";
   print F;
   $count++;
}
close(F);

}
