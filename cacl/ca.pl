#!/usr/bin/perl -w
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
$C="US";
$O="National Center for Supercomputing Applications";
$PORT=3434;
$CERTDIR="/usr/local/certman/CA_SYSTEM";
$KEYDIR="$CERTDIR/ca.db.keys";
$PUB_PKI_DIR="/usr/local/projects/security/PKI";
$PUB_CERT_DIR="/usr/local/projects/security/PKI/certificates";
$REQUEST_FILE_U="$CERTDIR/work/request_u.txt"; # unencrypted request file
$CA_KEY="$CERTDIR/ca.key";
$CA_CERT="$CERTDIR/ca.pem";
$CONF="$CERTDIR/ncsa.cnf";
$OSSL="/usr/bin/openssl";
$WORKDIR="$CERTDIR/work/";
$LOGFILE="$CERTDIR/CA.log";
@inetaddr=("0","0","0","0");

     use Socket;
     use Authen::Krb5::Simple;

     socket_setup();

     for (;;) {
         $SERIAL = `cat $CERTDIR/ca.db.serial`;
         chomp ($SERIAL);
	wait_for_and_rcv_request();

         $msg = "No msg yet\n";

	do_CA_stuff();

	printf("msg=%s\n",$msg);

        $logdate = `date`;
	$do_copy=0;
         if ($msg eq "Success\n") {
  	   $msg2 = `cat $cert_file`;
  	   $msg = "Success ".$msg2;
            `echo "$logdate" >> $LOGFILE`;
            `echo "$msg" >> $LOGFILE`;
	   $do_copy=1;
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

	if ($do_copy==1) {
	    copy_certs();
	}
     }


#
# Do the Certificate Authority processing, set msg to result
#
sub do_CA_stuff {

# decrypt (Note that having a password on the private key doesn't really
# make it much more secure (it is access to the key that is
# controlled), but what the heck...

     `$OSSL smime -decrypt -in $request_file -out $REQUEST_FILE_U -recip $CA_CERT -inkey $CA_KEY`;
     if ($? != 0) {
          $msg = "request decrypt failed\n";
	return;
     }

# check fields

     check_req_fields();
     if ($msg ne "No msg yet\n") {return;}

# check the user/passwd

     check_user_pw();

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

      `echo "y\ny\n" | $OSSL ca -config $CONF -in $REQUEST_FILE_U -out $cert_file -keyfile $CA_KEY -cert $CA_CERT 2> $error_file`;
#     `echo "y\ny\n" | $OSSL ca -config $CONF -in $REQUEST_FILE_U -out $cert_file -key $CP 2> $error_file`;
      if ($? != 0) {
	unlink $cert_file;  # clean up 0 length cert on error
	$msg2 = `cat $error_file`;
	$msg = "Signing failed:\n".$msg2;
	return;
      }
      chmod (0444, $cert_file);
      $msg = "Success\n";

}

#
# Check the user-entered password and verify the Common Name.  This is a little
# complicated because this information can be found in different locations
# depending on which machine is being checked.
#
sub check_user_pw {

     my $krb = Authen::Krb5::Simple->new();
   
     $USERID=`$OSSL req -config $CONF -text -in $REQUEST_FILE_U 2>$error_file | grep uniqueIdentifier`;
     if (!$USERID) {
	$msg=`cat $error_file`;
	return;
     }

     $USERID=substr($USERID,index($USERID,":")+1);
     chop($USERID);

     $PW=`$OSSL req -config $CONF -text -in $REQUEST_FILE_U 2>$error_file | grep challengePassword`;
     if (!$PW) {
	$msg=`cat $error_file`;
	return;
     }

     $PW=substr($PW,index($PW,":")+1);
     chop($PW);

     # Authenticate a user.
     #
     my $authen = $krb->authenticate($USERID, $PW);

     unless($authen) {
          $msg = "Kerberos authentication failed for $USERID: " . $krb->errstr();
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
	$msg=`cat $error_file`;
	return;
     }
     printf("DN=%s\n",$DN);
     if (index($DN,"C=$C")<0) {
         $msg="Not correct country field C=$C\n";
	return;
     }
     if (index($DN,"O=$O")<0) {
         $msg="Not correct organization O=$O\n";

	return;
     }
     $CN=substr($DN,index($DN,"CN=")+3);
     chomp($CN);
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
         print "Listening \n";
         ($addr = accept(NS,S)) || die $!;
         print "accept ok\n";

         ($af,$PORT,$inetaddr) = unpack($sockaddr,$addr);
         @inetaddr = unpack('C4',$inetaddr);
         print "$af $PORT @inetaddr\n";

         $date=`date +%y%m%d_%H%M%S`;
         chop($date);
	$base_name = $WORKDIR.$date;
	$request_file=$base_name.".req";
         $error_file=$base_name.".err";
	$cert_file=$base_name.".cert";


	open(F, ">".$request_file);

         $count=0;
	while (<NS>) {   # read NS (new socket) and put it in variable $_
	     last if $_ eq "All done\n";
              print F;
	     $count++;
         }
	close(F);

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
