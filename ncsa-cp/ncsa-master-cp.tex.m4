define(m4comment)
m4comment(Change quotes to square brackets)
changequote([,])
m4comment(latex configuration, bracket to protect from m4)
[
\documentclass[10pt]{article}
\usepackage[margin=1in]{geometry}

\usepackage{times}
\usepackage{graphicx}
\usepackage{url}
\usepackage[pdftex,colorlinks=false]{hyperref}
\usepackage{epsfig}
\usepackage{changebar}
\usepackage{tocloft}

%\bibliographystyle{abbrv}
\bibliographystyle{plain}

\setlength{\parindent}{0pt}
\setlength{\parskip}{\baselineskip}

\begin{document}
]

m4comment(Define two macros for specifying CA or SLCS only stuff)
define([M4_CA_ONLY], [ifdef([M4_NCSA_CA], [$*])])
define([M4_SLCS_ONLY], [ifdef([M4_NCSA_SLCS], [$*])])

M4_CA_ONLY([
define(M4_DOC_TITLE, [Certificate Policy and Practice Statement for the NCSA CA])
define(M4_CA_NAME, [NCSA-CA])
define(M4_CA_DN, [C=US, O=National Center for Supercomputing Applications, OU=Certificate Authorities, CN=CACL])
define(M4_DOC_OID, [1.3.6.1.4.1.4670.100.1.1])
])
M4_SLCS_ONLY([
define(M4_DOC_TITLE, [Certificate Policy and Practice Statement for the NCSA MyProxy CA])
define(M4_CA_NAME, [NCSA-SLCS])
define(M4_CA_DN, [C=US, O=National Center for Supercomputing Applications, OU=Certificate Authorities, CN=MyProxy])
define(M4_DOC_OID, [1.3.6.1.4.1.4670.100.2.1])
])
define(M4_TIMESTAMP, [esyscmd(date)])
define(M4_DOC_VERSION, [1.0 DRAFT-5])
define(M4_DOC_DATE, [M4_TIMESTAMP])
define(M4_CA_URL, [http://security.ncsa.uiuc.edu/CA/])
define(M4_VERSION, [esyscmd(m4 --version)])

define(M4_CHANGEBAR_BEGIN, [\chgbarbegin])
define(M4_CHANGEBAR_END, [\chgbarend])

define(M4_ITALICS, [\textit{$*}])
define(M4_SLANTED, [\textsl{$*}])
define(M4_BOLD, [\textbf{$*}])

m4comment(For quoted terms)
define(M4_QUOTE, [\textbf{$*}])

\title{M4_DOC_TITLE}
\author{National Center for Supercomputing Applications (NCSA)}

\date{Version M4_DOC_VERSION (M4_DOC_DATE)}

\maketitle

\tableofcontents
\newpage

\section{INTRODUCTION}

\subsection{Overview}

This Certificate Policy and Practice Statement (herein referred to as
the "Policy") specifies minimum requirements for the issuance and
management of digital certificates that shall be used in
authenticating users accessing National Center for Supercomputing
Application at the University of Illinois (herein referred to as
"NCSA") resources and the resources of other entities (relying
parties) which accept those certificates. The Policy is issued and
administered under the authority of the NCSA Policy Management
Authority (herein referred to as the "PMA"; see Section 1.4.2 for
contact details).

The structure and content of that document was derived from the
Internet Engineering Task Force RFC 3647 (Internet X.509 Public Key
Infrastructure Certificate Policy and Certification Practices
Framework).

M4_CA_ONLY([

This document is compliant with the Profile for Traditional X.509
Public Key Certificate Authorities with secured infrastructure Version
4.0, authored by the EUGridPMA. See the appendix for discussion of
this compliance.

])

M4_SLCS_ONLY([

This document is compliant with the Profile for Short Lived Credential
Services X.509 Public Key Certification Authorities with secured
infrastructure Version 1.1, authored by The Americas Grid Policy
Management Authority. See the appendix for discussion of this
compliance.

])

NCSA runs two CAs. Each CA has it own key and
certificate and runs on its own computer system. It is expected
that relying parties will trust both CAs, though a relying party may
choose to trust only one CA or the other. These two CAs taken together
along with the associated software and repositories used to distribute
policies, CRLs and the like, are referred to as the "NCSA PKI".

One CA issues only short-lived credentials to users and is
henceforth referred to as the ``NCSA Short-lived Certificate Service''
or ``NCSA-SLCS''.

One CA is a traditional CA that issues long-lived certificates to
hosts, services and users requiring long-lived certificates. This CA
is henceforth referred to as the ``NCSA-CA''. It is expected that users
will use the NCSA-SLCS for user certificates unless they have some
need for a long-lived certificate.

This document covers the policy that applies to the M4_CA_NAME.

\subsection{Document name and identification}

Document title: M4_DOC_TITLE

This Policy is published at:
M4_CA_URL

Document version: M4_DOC_VERSION

Document date: M4_DOC_DATE

OID: M4_DOC_OID

\subsection{PKI participants}

\subsubsection{Certification authorities}

This policy is valid for the M4_CA_NAME. The M4_CA_NAME will only sign end
entity certificates. There are no subordinate CAs.

\subsubsection{Registration authorities}

NCSA maintains a user database of legitimate users of NCSA
computational systems. This user database is exposed through a
Kerberos domain, which serves the Registration Authority role and is
used by the M4_CA_NAME to authenticate certificate requests.

The same user database is used as an authentication service for
NCSA's users and staff to access NCSA high-performance computing
resources, NCSA's email services and other production services.

M4_CA_ONLY([
In the case of user certificates, the NCSA-CA will automatically issue
user certificates with a distinguished name based on the user's
authentication via Kerberos 5 as a user in NCSA's user database.

In the case of server and service certificate requests, NCSA maintains
a database of all NCSA hosts and their authorized system
administrator(s). This database will serve the RA function for
requests for service certificates. This will allow requests for
service certificates from a host's authorized administrator
(authenticated via NCSA's Kerberos 5 domain) to be automatically
processed. Requests for hosts that do not appear in this database
(e.g. services run by NCSA collaborators) will be manually vetted by
NCSA operations staff.
])

M4_SLCS_ONLY([

The NCSA-SLCS will automatically issue user certificates with a
distinguished name based on the user's authentication via Kerberos 5
as a user in NCSA's user database.

])


\subsubsection{Subscribers}

M4_CA_ONLY([

The NCSA-CA will serve the needs of the NCSA community by providing
users and services at NCSA with x509v3 digital certificates.  These
certificates may be used for the purpose of authentication,
encryption, and digital signing by those individuals to whom the
certificates have been issued.

The CA will also issue server and service certificates to computers
operating within the NCSA administrative domain and to computer
systems from other domains that are providing services in support of
NCSA projects.

Persons receiving certificates will be users of NCSA's computational
facilities or staff employed at NCSA.

])
M4_SLCS_ONLY([

The NCSA-SLCS will serve the needs of the NCSA community by providing
NCSA users and employees with x509v3 digital certificates.  These
certificates may be used for the purpose of authentication,
encryption, and digital signing by those individuals to whom the
certificates have been issued.

])

\subsubsection{Relying parties}

NCSA places no restrictions on who may accept certificates it issues.

\subsubsection{Other participants}

No stipulations.

\subsection{Certificate usage}

\subsubsection{Appropriate certificate uses}

One of the purposes of this policy is to promote a wide use of
public-key certificates in many different applications.  These
applications may include, but are not limited to, login
authentication, job submission authentication, encrypted e-mail, and
SSL/TLS encryption for applications capable of making use of these
technologies.

\subsubsection{Prohibited certificate uses}

Other uses of M4_CA_NAME certificates are not prohibited, but neither
are they supported.

\subsection{Policy administration}

\subsubsection{Organization administering the document}

This policy is administered by:

The National Center for Supercomputing Applications
at the University of Illinois
1205 W. Clark, Urbana IL 61801

\subsubsection{Contact person}

The point of contact for this Policy and other matters related to the
M4_CA_NAME is the Head of Security Operations for NCSA. Currently this is
Jim Barlow.

James J. Barlow

Head of Security Operations and Incident Response

Phone number: 217-244-6403

Postal address: 1205 W. Clark, Urbana IL 61801

E-mail address: jbarlow@ncsa.uiuc.edu

After hours contact information:

NCSA Security Operations and Incident Response: security@ncsa.uiuc.edu

NCSA 24x7 Operations: 217-244-0710

\subsubsection{Person determining CPS suitability for the policy}

The Head of Security Operations for NCSA leads the PMA for the CA and
is ultimately responsible for determining the suitability of the CPS.

\subsubsection{CPS approval procedures}

As determined by the Head of Security Operations for NCSA.

\subsection{Definitions and acronyms}

Certification Authority (CA) - An authority trusted by 
one or more users to create and assign public key 
certificates. Optionally the CA may create the user's 
keys. It is important to note that the CA is responsible 
for the public key certificates during their whole 
lifetime, not just for issuing them. 
 
CA-certificate - A certificate for one CA's public key
issued by another CA or self signed.  
 
Certificate policy (CP) - A named set of rules that 
indicates the applicability of a certificate to a 
particular community and/or class of application with 
common security requirements. For example, a particular 
certificate policy might indicate applicability of a 
type of certificate to the authentication of electronic 
data interchange transactions for the trading of goods 
within a given price range. 
 
Certification path - An ordered sequence of certificates 
which, together with the public key of the initial 
object in the path, can be processed to obtain that of 
the final object in the path. 

Certification Practice Statement (CPS) - A statement of the practices, 
which a certification authority employs in issuing certificates. 
 
Certificate revocation list (CRL) - A CRL is a time 
stamped list identifying revoked certificates, which is 
signed by a CA and made freely available in a public 
repository. 

Issuing certification authority (issuing CA) - In the context of a 
particular certificate, the issuing CA is the CA that issued the 
certificate (see also Subject certification authority). 
 
Public Key Certificate (PKC) - A data structure 
containing the public key of an end entity and some 
other information, which is digitally signed with the 
private key of the CA which issued it. 
 
Public Key Infrastructure (PKI) - The set of hardware, 
software, people, policies and procedures needed to 
create, manage, store, distribute, and revoke PKCs based 
on public-key cryptography. 
  
Registration authority (RA) - An entity that is 
responsible for identification and authentication of 
certificate subjects, but that does not sign or issue 
certificates (i.e., an RA is delegated certain tasks on 
behalf of a CA). [Note: The term Local Registration 
Authority (LRA) is used elsewhere for the same concept.] 
 
Relying party - A recipient of a certificate who acts in 
reliance on that certificate and/or digital signatures 
verified using that certificate. In this document, the 
terms "certificate user" and "relying party" are used 
interchangeably. 
 
Subject certification authority (subject CA) - In the 
context of a particular CA-certificate, the subject CA 
is the CA whose public key is certified in the certificate. 
 
IPR - Intellectual Property Rights 
 
\section{PUBLICATION AND REPOSITORY RESPONSIBILITIES}

\subsection{Repositories}

The NCSA PKI will maintain a repository at:

M4_CA_URL

\subsection{Publication of certification information}

This repository described in the previous section will contain:

\begin{itemize}

\item Self-signed, PEM-formatted certificates for all CAs in the NCSA PKI

M4_CA_ONLY([
\item PEM-formatted CRLs for the M4_CA_NAME
])

\item General information about the NCSA PKI

\item The most recent copies of all Certificate Policies for the NCSA PKI CAs

\end{itemize}

\subsection{Time or frequency of publication}

M4_CA_ONLY([

The CRL will be published immediately after a certificate has been
revoked as well as on a daily basis.
])

The Policy shall be published immediately following any update.

\subsection{Access controls on repositories}

There are no restrictions on access to the repositories.

Best effort will be provided to maintain their availability 24x7.

\section{IDENTIFICATION AND AUTHENTICATION}
\subsection{Naming}
\subsubsection{Types of names}

Subject distinguished names are X.500 names, with components varying
depending on the type of certificate.

\subsubsection{Need for names to be meaningful}

The common name (CN) component of the subject name in user
certificates has no semantic significance, but has a reasonable
association with the name of the user.

M4_CA_ONLY([

The CN component of the subject name in service certificates includes
the fully qualified DNS name of the service, which is usually that of
the host supporting the service. The structure of a service's CN is
designed to support SSL, TLS and Globus services.

])

\subsubsection{Anonymity or pseudonymity of subscribers}

Anonymity and pseudonymity are not supported.

\subsubsection{Rules for interpreting various name forms}

All subject distinguished names in certificates issued by the NCSA PKI
begin with C=US, O=National Center for Supercomputing
Applications. The next component will be one of:

\begin{itemize}

\item OU=Certificate Authorities :
for a CA's certificate. A CN component will follow the OU, naming the
CA. All CA certificates will be self-signed.

The distinguished name for the M4_CA_NAME is M4_CA_DN.

M4_CA_ONLY([

\item OU=Services :
for a service (including a host) certificate issued by the NCSA-CA. A
CN component will follow the OU, naming the service and the fully
qualified domain name (FQDN) at which the service can be contacted,
separated by a slash character. When the service is https, the service
name and separator will be absent.

])

\item CN=M4_ITALICS(User Name) :
for a user's certificate issued by the NCSA-CA or NCSA-SLCS.  The CN
component will contain the user's full name and, if needed,
a numeric value to disambiguate the name from other users with the
same name.

\end{itemize}

\subsubsection{Uniqueness of names}

Each subject name issued by the NCSA PKI will be issued to one and
only one individual. The NCSA-CA and NCSA-SLCS may issue certificates
with identical names, but only to the same individual.

All names will be prefixed with the relative DN form of C=US,
O=National Center for Supercomputing Applications to provide a
globally unique namespace.

For user certificates, a unique "common name" is assigned to each
user, which is based on their legal name. Conflicts with legal names
are resolved by appending a number to the name to create a unique
name. This common name along with the prefix create globally-unique
distinguished names used in certificates issued by the NCSA PKI to
users.

M4_CA_ONLY([

For service certificates, the combination of service name and fully
qualified domain name of the host on which the service resides serves
to disambiguate the name.

])

\subsubsection{Recognition, authentication, and role of trademarks}

No stipulation.

\subsection{Initial identity validation}

\subsubsection{Method to prove possession of private key}

No stipulation.

\subsubsection{Authentication of organization identity}

NCSA users are identified by their presence in the NCSA user database.

\subsubsection{Authentication of individual identity}

User identity will be authenticated through Kerberos 5
credentials, with the authenticated Kerberos 5 principal
name mapped to a unique "common name" via the NCSA user database.

\subsubsection{Non-verified subscriber information}

Subscriber name and postal address are verified by NCSA's account
creation process. Other gathered information is not verified.

\subsubsection{Validation of authority}


M4_CA_ONLY([

Requests for service certificates must come from a valid NCSA User and
will be checked against NCSA's database of registered system
administrators to ensure the user is a legitimate system administrator
for the service identified in the certificate subject name.

])

Users making requests for user certificates must be authenticated as
the user identified in the certificate.

\subsubsection{Criteria for interoperation}

The NCSA PKI is intended to interoperate with other CAs within
TeraGrid and the International Grid Trust Federation.

\subsection{Identification and authentication for re-key requests}

\subsubsection{Identification and authentication for routine re-key}

Every certificate request is treated as an initial registration.

\subsubsection{Identification and authentication for re-key after revocation}

If the compromise was limited to just the private key, the request for
re-key will be treated as an initial registration.

If the compromise involved a user's password from the NCSA database,
that password will be reset based on a postal mail to the user using
their known postal address.

\subsection{Identification and authentication for revocation request}

M4_CA_ONLY([
Requests for revocation of service certificates from NCSA computer
security personnel and from administrators of the systems hosting the
services in question will be honored.
])

CA Certificates will only be revoked at the instigation of NCSA
Operational Security personnel.

Users may request revocation by contacting NCSA Security
Operations. Requests will be handled as deemed appropriate by NCSA
Security Operations.

\section{CERTIFICATE LIFE-CYCLE OPERATIONAL REQUIREMENTS}

\subsection{Certificate Application}

\subsubsection{Who can submit a certificate application}

Any user who appears in NCSA's User Database may request a
certificate.

\subsubsection{Enrollment process and responsibilities}

To receive an entry in NCSA's user database, a user must satisfy
one of the following conditions:

\begin{itemize}

\item Be a NCSA employee;

\item Be a Principal Investigator (PI) with a allocation on NCSA
computational resources approved through an NSF-approved peer review
process (e.g. NRAC);

\item Have a ``project account'' requested on their behalf by an existing PI
using that PI's allocation;

\item Have a ``guest Account'' requested by NCSA management for key
collaborators of NCSA.

\end{itemize}

All vetting is done either in person (in the case of employees), by
peer review allocation (in the case of PIs), or by direct personal
contact of a PI or NCSA staff member (in the case of project or guest
accounts).

All initial user passwords are distributed by US postal mail. If a
user requires a new password (e.g. they have lost their password), it
will only be distributed via U.S. postal mail to their known address.

Each user is assigned a unique username used as their Kerberos
principal and Unix login name.

\subsection{Certificate application processing}

\subsubsection{Performing identification and authentication functions}

The M4_CA_NAME authenticates all certificate requests using the NCSA
Kerberos 5 domain.

\subsubsection{Approval or rejection of certificate applications}

M4_CA_ONLY([

Certificate applications will be approved if the applicant can be
authenticated using NCSA's Kerberos domain and, in the case of service
certificates, is validated as an authorized system administrator for
the host in question.

])
M4_SLCS_ONLY([

Certificate applications will be approved if the applicant can be
authenticated using NCSA's Kerberos domain.

])

\subsubsection{Time to process certificate applications}

M4_CA_ONLY([

Certificate applications are processed with best effort. It is
expected that certificates will be issued within one business day.

])
M4_SLCS_ONLY([
Certificate applications are processed in real time.
])

\subsection{Certificate issuance}

\subsubsection{CA actions during certificate issuance}

The application is processed and approved as described in the previous
section.

\subsubsection{Notification to subscriber by the CA of issuance of certificate}

User certificates are returned directly to the user through the
application they are using to apply for a certificate.

For other certificates, users will be contacted by email.

\subsection{Certificate acceptance}

\subsubsection{Conduct constituting certificate acceptance}

Certificate acceptance is assumed.

\subsubsection{Publication of the certificate by the CA}

End entity certificates are not published.

m4comment([
I cannot see where this is required. Here is the text that used to be here.

Certificates will be published as they are issued at
M4_CA_URL
])
\subsubsection{Notification of certificate issuance by the CA to other entities}

No notifications to other entities will be performed.

\subsection{Key pair and certificate usage}

\subsubsection{Subscriber private key and certificate usage}

Subscribers must:

\begin{itemize}

\item  Exercise all reasonable care in protecting the
private keys corresponding to their certificates, including but not
limited to never storing them on a networked file system or otherwise
transmitting them over a network and never sharing them between people.

M4_CA_ONLY([
\item  Ensure that the private keys corresponding to their issued service
certificates are stored in a manner that minimizes the risk of
exposure. 
])

\item  Observe restrictions on private key and certificate use. 

\item  Promptly notify the CA operators of any incident involving a
possibility of exposure of a private key. 

\end{itemize}

\subsubsection{Relying party public key and certificate usage}

Relying parties must 

\begin{itemize}

\item  Be cognizant of the provisions of this document. 

\item  Verify any self-signed certificates to their own satisfaction using
out-of-band means. 

M4_CA_ONLY([

\item  Accept responsibility for checking any relevant CRLs before
accepting the validity of a certificate. 

])

\item  Observe restrictions on private key and certificate use. 

\item  Not presume any authorization of an end entity based on possession
of a certificate from the NCSA PKI or its corresponding private key. 

\end{itemize}

\subsection{Certificate renewal}

Certificates in the NCSA PKI are not explicitly renewed. Instead the
original subscriber may request a new certificate, using the normal
certificate issuance process.

\subsection{Certificate re-key}

Certificates in the NCSA PKI are not explicitly re-keyed. Instead the
original subscriber may request a new certificate, using the normal
certificate issuance process.

\subsection{Certificate modification}

Certificates in the NCSA PKI are not modified. Instead new
certificates will be issued using the normal certificate issuance
process.

\subsection{Certificate revocation and suspension}

Certificates issued by the NCSA PKI will not be suspended.

\subsubsection{Circumstances for revocation}

M4_SLCS_ONLY([
User certificates, because of their short lifetimes, will not be
revoked.
])

M4_CA_ONLY([
Certificates issued by the NCSA-CA will be revoked in any of the
following circumstances:

\begin{itemize}

\item  The private key is suspected or reported to be lost or exposed. 

\item  The information in the certificate is believed to be, or has become
inaccurate.

\item  The certificate is reported to no longer be needed. 

\end{itemize}

])


\subsubsection{Who can request revocation}

M4_CA_ONLY([

NCSA Security Operations personnel may request revocation of any
certificate issued by the NCSA PKI.

The original subscriber for a certificate may request its revocation.

Entities other than the subscriber who suspect a certificate issued by
the NCSA PKI may be compromised should contact NCSA Security
Operations.

])
M4_SLCS_ONLY([Not applicable.])

\subsubsection{Procedure for revocation request}

M4_CA_ONLY([
Requests for revocation should be made by email to
security@ncsa.uiuc.edu or by phone to NCSA Operations 217-244-0710.
])
M4_SLCS_ONLY([Not applicable.])

\subsubsection{Revocation request grace period}

M4_CA_ONLY([
No constraints.
])
M4_SLCS_ONLY([Not applicable.])

\subsubsection{Time within which CA must process the revocation request}

M4_CA_ONLY([
Revocation requests will be processed with best effort as quickly as
possible.
])
M4_SLCS_ONLY([Not applicable.])

\subsubsection{Revocation checking requirement for relying parties}

M4_CA_ONLY([
Relying parties are advised to obtain and consult a valid CRL from
M4_CA_URL
])
M4_SLCS_ONLY([Not applicable.])

\subsubsection{CRL issuance frequency (if applicable)}

M4_CA_ONLY([
CRLs are issued when a certificate is revoked.

CRLs are issued daily.
])

M4_SLCS_ONLY([Not applicable.])

\subsubsection{Maximum latency for CRLs (if applicable)}

M4_CA_ONLY([
One day.
])

\subsubsection{On-line revocation/status checking availability}

M4_CA_ONLY([
Aside from the published CRL, no on-line certificate status checking
is available.
])
M4_SLCS_ONLY([None.])

\subsubsection{Other forms of revocation advertisements available}

None.

\subsubsection{Special requirements re key compromise}

None.

\subsection{Certificate status services}


M4_CA_ONLY([
Aside from the published CRL, no on-line certificate status checking
is available.
])
M4_SLCS_ONLY([None.])

\subsection{End of subscription}

M4_CA_ONLY([
Subscribers may end their subscription by requesting revocation of
their certificate.
])
M4_SLCS_ONLY([
Subscribers may end their subscription by allowing their certificate
to expire and not requesting a new one.
])

No key escrow is performed.

\section{FACILITY, MANAGEMENT, AND OPERATIONAL CONTROLS (11)}

\subsection{Physical controls}

\subsubsection{Site location and construction}

The M4_CA_NAME will be located in NCSA's machine room in the Advance
Computation Building (ACB) on the University of Illinois at
Urbana-Champaign campus.

\subsubsection{Physical access}

NCSA occupies all of ACB with the exception of space dedicated to
mechanical systems and custodians.  ACB entrances and computer rooms
are locked at all times and use a keycard system to gain entry.  Video
cameras are located at all entrances and are monitored by staff in the
control room.  An intercom and remote lock release system is used at
the main entrance to allow entry to authorized personnel who do not
have keycard access.  ACB is not open to the general public and is
staffed 24x7x365.

\subsubsection{Power and air conditioning}

No stipulation.

\subsubsection{Water exposures}

No stipulation.

\subsubsection{Fire prevention and protection}

No stipulation.

\subsubsection{Media storage}

No stipulation.

\subsubsection{Waste disposal}

No stipulation.

\subsubsection{Off-site backup}

No stipulation.

\subsection{Procedural controls}

All persons with access to the systems hosting the M4_CA_NAME will be
full-time NCSA employees. Personnel will be NCSA Operations staff,
NCSA Security Operations staff, and NCSA System administration staff.

When any person with access to the M4_CA_NAME systems leaves NCSA or
their administrative role, their access will be revoked and any
relevant passwords changed.

\subsubsection{Trusted roles}

No stipulation.

\subsubsection{Number of persons required per task}

No stipulation.

\subsubsection{Identification and authentication for each role}

No stipulation.

\subsubsection{Roles requiring separation of duties}

No stipulation.

\subsection{Personnel controls}

\subsubsection{Qualifications, experience, and clearance requirements}

Operators of the M4_CA_NAME will be qualified system administrators
and operators at NCSA.

\subsubsection{Background check procedures}

No stipulation.

\subsubsection{Training requirements}

No stipulation.

\subsubsection{Retraining frequency and requirements}

No stipulation.

\subsubsection{Job rotation frequency and sequence}

No stipulation.

\subsubsection{Sanctions for unauthorized actions}

No stipulation.

\subsubsection{Independent contractor requirements}

No stipulation.

\subsubsection{Documentation supplied to personnel}

No stipulation.

\subsection{Audit logging procedures}

\subsubsection{Types of events recorded}

The following items will be logged:

\begin{itemize}

\item  Certificate requests

\item  Certificate issuance

M4_CA_ONLY([
\item  Certificate revocations

\item  Issued CRLs
])

\item  Attempted and successful accesses to the systems hosting the NCSA
PKI, and reboots of those systems

\end{itemize}

The NCSA user database maintains contact information for all subscribers.

\subsubsection{Frequency of processing log}

No stipulation.

\subsubsection{Retention period for audit log}

Audit logs are maintain indefinitely on NCSA's mass storage system in ACB.

\subsubsection{Protection of audit log}

No stipulation.

\subsubsection{Audit log backup procedures}

Audit logs are archived weekly to a secondary storage facility at the
Beckman Institute on the University of Illinois at
Urbana-Champaign campus.

\subsubsection{Audit collection system (internal vs. external)}

No stipulation.

\subsubsection{Notification to event-causing subject}

No stipulation.

\subsubsection{Vulnerability assessments}

No stipulation.

\subsection{Records archival}

The CA records and archives all requests for certificates, along with all
the issued certificates, all the requests for revocation, all the issued
CRLs and the login/logout/reboot of the issuing machine. 

The CA keeps these records for at least three years.
These records will be be made available to external auditors in the
course of their work as auditor.

\subsection{Key changeover}

Best effort will be made to notify relying parties of any new public
key for the M4_CA_NAME, and it may then be obtained in the same manner
as the previous M4_CA_NAME certificates.

\subsection{Compromise and disaster recovery}

\subsubsection{Incident and compromise handling procedures}

All incidents will be handled by NCSA Security Operation and Incident
Response as they determine appropriate.

\subsubsection{Computing resources, software, and/or data are corrupted}

No stipulation.

\subsubsection{Entity private key compromise procedures}

M4_CA_ONLY([
Any private key compromise will result in revocation of the associated
certificate.
])
M4_SLCS_ONLY([

Any private key compromised will be handled by NCSA Security
Operations on a case-by-case basis. In general an attempt will be made
to identiify any effected parties and notify those parties.

])

\subsubsection{Business continuity capabilities after a disaster}

No stipulation.

\subsection{CA or RA termination}

No stipulation.

\section{TECHNICAL SECURITY CONTROLS}

\subsection{Key pair generation and installation}
\subsubsection{Key pair generation}

The M4_CA_NAME does not generate any private keys but its own.

User private keys will be generated by client software on the host
where they will be stored.  They will be stored on non-networked
filesystems.

M4_SLCS_ONLY([
Private keys will normally be stored unencrypted, but the
lifetime of the associated public-key certificate is limited to 
no more than one week.
])

M4_CA_ONLY([
System and service administrators will generate private keys for their
services, on the service hosts themselves if at all possible.
])

\subsubsection{Private key delivery to subscriber}

Not necessary.

\subsubsection{Public key delivery to certificate issuer}

Public keys are delivered under Kerberos authentication and integrity
protection.

\subsubsection{CA public key delivery to relying parties}

The public keys of NCSA PKI CAs are available at
M4_CA_URL

\subsubsection{Key sizes}

The CA private key will be 2048 bits in length.
Public RSA keys shorter than 1024 bits will not be signed.

\subsubsection{Public key parameters generation and quality checking}

No stipulation.

\subsubsection{Key usage purposes (as per X.509 v3 key usage field)}

The M4_CA_NAME does not enforce key usage restrictions by any means
beyond the X.509v3 extensions in the certificates it issues. In User
and Service certificates, those extensions will mark the associated
keys as valid for Digital Signature and Key Encipherment. CA
certificates will have the Key Usage extension set to allow Digital
Signature, Certificate Signing, and CRL Signing.

\subsection{Private Key Protection and Cryptographic Module Engineering Controls}
\subsubsection{Cryptographic module standards and controls}

The M4_CA_NAME will use a FIPS 140-2 level 3 Hardware Security Module
(SafeNet Luna PCI)
for storage of its private key.

\subsubsection{Private key (n out of m) multi-person control}

There is no multi-person control of the private key.

\subsubsection{Private key escrow}

M4_CA_NAME private keys are not escrowed.

\subsubsection{Private key backup}

M4_CA_NAME private key is replicated on two identical cryptographic
modules on two identical hosts in the NCSA machine room to provide for
failure protection. If a system hosting one CA should fail, that CA
will temporarily be hosted on the other system until such time as a
replacement system can be arranged.

\subsubsection{Private key archival}

M4_CA_NAME private keys are not archived.

\subsubsection{Private key transfer into or from a cryptographic module}

M4_CA_NAME private keys will initially be replicated on two identical
cryptographic storage modules in a secure manner. After that point
they will not be exported from the cryptographic modules.

\subsubsection{Private key storage on cryptographic module}

M4_CA_NAME private keys are stored on cryptographic modules meeting
FIPS 140-2 level 3.

\subsubsection{Method of activating private key}

No stipulation.

\subsubsection{Method of deactivating private key}

No stipulation.

\subsubsection{Method of destroying private key}

No stipulation.

\subsubsection{Cryptographic Module Rating}

Hardware security modules will meet or exceed FIPS 140-2 level 3.

\subsection{Other aspects of key pair management}

\subsubsection{Public key archival}

No stipulation.

\subsubsection{Certificate operational periods and key pair usage periods}

The certificate for M4_CA_NAME will have a lifetime of 10 years.

M4_CA_ONLY([
NCSA-CA User and Service certificates will have a lifetime of not more
than one year.
])
M4_SLCS_ONLY([
NCSA-SLCS certificates will have a lifetime of not more than 1 week.
])

\subsection{Activation data}
\subsubsection{Activation data generation and installation}

No stipulation.

\subsubsection{Activation data protection}

No stipulation.

\subsubsection{Other aspects of activation data}

No stipulation.

\subsection{Computer security controls}
\subsubsection{Specific computer security technical requirements}

The M4_CA_NAME software runs on a dedicated machine, running no other
services than those needed for the CA operations.
The server's network is protected by a dedicated hardware firewall,
and the server itself runs an operating system firewall.
The server is monitored via both host-based and network-based
intrusion detection systems.
Login access is subject to hardware-based one-time password
authentication using hardware tokens and permitted only for
administrative personnel that require access to the system for its
operation.

\subsubsection{Computer security rating}

No stipulation.

\subsection{Life cycle technical controls}
\subsubsection{System development controls}

No stipulation.

\subsubsection{Security management controls}

No stipulation.

\subsubsection{Life cycle security controls}

No stipulation.

\subsection{Network security controls}

Other than the access needed to request and obtain certificates, no
network access to the hosts housing the NCSA PKI will be permitted
from outside of NCSA's network.

\subsection{Time-stamping}

No stipulation.

\section{CERTIFICATE, CRL, AND OCSP PROFILES}
\subsection{Certificate profile}

End-entity certificates will be in X509v3 format,
compliant with RFC 3280.

\subsubsection{Version number(s)}

The version number will have a value of 2 indicating a Version 3 certificate.

\subsubsection{Certificate extensions}

For the CA certificate:

\begin{itemize}

\item keyUsage (critical): Digital Signature, Certificate Sign, CRL Sign

\item basicConstraints (critical): CA:true

\item X509v3 Subject Key Identifier 
\item X509v3 Authority Key Identifier 

M4_CA_ONLY([
\item CRLDistributionPoints:
URI:http://ca.ncsa.uiuc.edu/4a6cd8b1.r0
])

\end{itemize}

For user and service certificates:

\begin{itemize}

\item Basic Constraints (critical): 
CA:false 

\item X509v3 Subject Key Identifier 
\item X509v3 Authority Key Identifier 

\item X509v3 Certificate Policies:
OID: M4_DOC_OID

\item Key Usage (critical): 
Digital Signature, Non Repudiation, Key Encipherment, Data Encipherment

\item Netscape Cert Type: 
SSL Client, SSL Server, Object Signing 

\item Netscape CA Policy URL:
M4_CA_ONLY([ 
http://security.ncsa.uiuc.edu/CA/ncsa-ca-policy.pdf
])
M4_SLCS_ONLY([
http://security.ncsa.uiuc.edu/CA/ncsa-slcs-policy.pdf
])

M4_CA_ONLY([
\item CRLDistributionPoints:
URI:http://ca.ncsa.uiuc.edu/4a6cd8b1.r0
])

\item SubjectAltName:

For user certificates, the NCSA email address and Kerberos principal
name of the subscriber responsible for the certificate.

M4_CA_ONLY([
For service certificates, the 
dnsName of the service and
the NCSA email address and Kerberos principal name of the
responsible system administer.
])

\end{itemize}

\subsubsection{Algorithm object identifiers}

\begin{itemize}

\item Hash Function:  id-sha1 1.3.14.3.2.26
\item RSA Encryption: rsaEncryption 1.2.840.113549.1.1.1
\item Signature Algorithm: sha1WithRSAEncryption 1.2.840.113549.1.1.5

\end{itemize}

\subsubsection{Name forms}

M4_CA_ONLY([
All certificates will have one of the following name forms:

\begin{itemize}

\item C=US, O=National Center for Supercomputing Applications, OU=Services,
              CN=M4_QUOTE(svcname)/M4_QUOTE(FQDN)

\item C=US, O=National Center for Supercomputing Applications, OU=Services,
              CN=M4_QUOTE(FQDN)

\item C=US, O=National Center for Supercomputing Applications,
      	      CN=M4_QUOTE(user name)

\item C=US, O=National Center for Supercomputing Applications,
              OU=Certificate Authorities, CN=M4_QUOTE(CA name)

\end{itemize}

Where:

\begin{itemize}

\item  M4_QUOTE(svcname) is ``host'' or an identifier of the service the
  certificate is associated with.

\item M4_QUOTE(FQDN) is the fully qualified domain name of the host on which the
 service the certificate is associated with is homed.

\item  M4_QUOTE(user name) is a unique name for the subscriber, which may have
 appended digits to disambiguate.

\item  M4_QUOTE(ca name) is the name of a CA.

\end{itemize}
])
M4_SLCS_ONLY([
All certificates will have the following name form:

C=US, O=National Center for Supercomputing Applications, CN=M4_QUOTE(user name)

Where:

 M4_QUOTE(user name) is a unique name for the subscriber, which may have
 appended digits to disambiguate.
])

\subsubsection{Name constraints}

All certificates issued by the NCSA PKI will have names with the
following prefix:

``C=US, O=National Center for Supercomputing Applications''

\subsubsection{Certificate policy object identifier}

M4_DOC_OID

\subsubsection{Usage of Policy Constraints extension}

No stipulation.

\subsubsection{Policy qualifiers syntax and semantics}

No stipulation.

\subsubsection{Processing semantics for the critical Certificate Policies extension}

No critical extensions are in use at this time.


\subsection{CRL profile}

M4_SLCS_ONLY([
The NCSA-SLCS does not issue CRLs.
])

\subsubsection{Version number(s)}

M4_CA_ONLY([

The version number will be 0 indicating a version 1 CRL.
])
M4_SLCS_ONLY([
Not applicable.
])

\subsubsection{CRL and CRL entry extensions}

No stipulation.

\subsection{OCSP profile}

OCSP is not supported.

\section{COMPLIANCE AUDIT AND OTHER ASSESSMENTS}

M4_CA_NAME will accept being audited by other IGTF accredited CAs to
verify compliance with the rules and procedures specified in this
document.

\subsection{Frequency or circumstances of assessment}

No stipulation.

\subsection{Identity/qualifications of assessor}

No stipulation.

\subsection{Assessor's relationship to assessed entity}

No stipulation.

\subsection{Topics covered by assessment}

No stipulation.

\subsection{Actions taken as a result of deficiency}

No stipulation.

\subsection{Communication of results}

No stipulation.

\section{OTHER BUSINESS AND LEGAL MATTERS}
\subsection{Fees}

No fees will be charged by the M4_CA_NAME nor any refunds given.

\subsection{Financial responsibility}

No financial responsibility is accepted. 

\subsubsection{Insurance coverage}

No stipulation.

\subsubsection{Other assets}

No stipulation.

\subsubsection{Insurance or warranty coverage for end-entities}

No stipulation.

\subsection{Confidentiality of business information}
\subsubsection{Scope of confidential information}

No stipulation.

\subsubsection{Information not within the scope of confidential information}

No stipulation.

\subsubsection{Responsibility to protect confidential information}

No stipulation.

\subsection{Privacy of personal information}

\subsubsection{Privacy plan}

No stipulation.

\subsubsection{Information treated as private}

No private information is collected by the M4_CA_NAME.

\subsubsection{Information not deemed private}

No private information is collected by the M4_CA_NAME.

\subsubsection{Responsibility to protect private information}

No stipulation.

\subsubsection{Notice and consent to use private information}

No stipulation.

\subsubsection{Disclosure pursuant to judicial or administrative
  process}

No stipulation.

\subsubsection{Other information disclosure circumstances}

No stipulation.

\subsection{Intellectual property rights}

The M4_CA_NAME asserts no ownership rights in certificates issued to
subscribers. 

Acknowledgment is hereby given to the Fermilab PKI, the DOE Science
Grid and to the CERN Certification Authority for inspiration of parts
of this document.

\subsection{Representations and warranties}

The M4_CA_NAME and its agents make no guarantee about the security or
suitability of a service that is identified by a NCSA certificate. The
M4_CA_NAME is run with a reasonable level of security, but it is
provided on a best effort only basis. It does not warrant its
procedures and it will take no responsibility for problems arising
from its operation, or for the use made of the certificates it
provides.

\subsection{Disclaimers of warranties}

The M4_CA_NAME denies any financial or any other kind of responsibility
for damages or impairments resulting from its operation.

\subsection{Limitations of liability}

The M4_CA_NAME is operated substantially in accordance with NCSA's
own risk analysis. No liability, explicit or implicit, is accepted.

\subsection{Indemnities}

No stipulation.

\subsection{Term and termination}
\subsubsection{Term}

This policy becomes effective on its posting to
M4_CA_URL.

\subsubsection{Termination}

This policy may be terminated at any time without warning.

\subsubsection{Effect of termination and survival}

No stipulation.

\subsection{Individual notices and communications with participants}

No stipulation.

\subsection{Amendments}
\subsubsection{Procedure for amendment}

Changes to this document will be presented to the TAGPMA for approval
before taking effect.

Changes will go into effect on the publishing of this document to
M4_CA_NAME.

\subsubsection{Notification mechanism and period}

Best effort notification of all relying parties will be made with as
much advance notice as possible.

\subsubsection{Circumstances under which OID must be changed}

Any substantial change of policy will incur a change of OID.

\subsection{Dispute resolution provisions}

NCSA Security Operations will resolve all disputes regarding this
policy.

\subsection{Governing law}

Interpretation of this policy is according to the laws of the United
States of America and the State of Illinois, where the conforming CA
is established.

\subsection{Compliance with applicable law}

No stipulation.

\subsection{Miscellaneous provisions}
\subsubsection{Entire agreement}

No stipulation.

\subsubsection{Assignment}

No stipulation.

\subsubsection{Severability}

No stipulation.

\subsubsection{Enforcement (attorneys' fees and waiver of rights)}

No stipulation.

\subsubsection{Force Majeure}

No stipulation.

\subsection{Other provisions}

No stipulation.

\appendix

M4_CA_ONLY([
include(ncsa-ca-appendix.tex.m4)
])

M4_SLCS_ONLY([
include(ncsa-slcs-appendix.tex.m4)
])

\newpage
\section{DOCUMENT SOURCE} 

This source for this document can be found in the CVSROOT of
:ext:cvs.ncsa.uiuc.edu:/CVS/ncsa-ca in the ncsa-cp repository.

The CVS version of the source for this document is $Revision$. Changes in
the version of this source could be due to minor editorial changes and
do not by themselves imply a change of policy.

This document was generated from source on M4_TIMESTAMP using M4_VERSION.

%\bibliography{biblio}

\end{document}
