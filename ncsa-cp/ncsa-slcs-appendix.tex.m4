\newpage
\section{COMPLIANCE WITH PROFILE FOR SHORT LIVED CREDENTIAL SERVICES X.509 PUBLIC KEY CERTIFICATION AUTHORITIES}

This document is compliant with the Profile for Short Lived Credential
Services X.509 Public Key Certification Authorities with secured
infrastructure Version 1.1, authored by The Americas Grid Policy
Management Authority (henceforth referred to as the ``SLCS Profile'').

http://www.tagpma.org/files/IGTF-AP-SLCS-20051115-1-1.pdf

This appendix describes how this policy meets or exceeds the
requirements of the SLCS Profile. Each subsection of this appendix
corresponds that matching secion in the SLCS Profile.

\subsection{About this document}

No requirements specified.

\subsection{General Architecture}

This section describes requirements in general terms. These
requirements are specifically address in the following sections.

NCSA is committing to operating the NCSA PKI for the foreseeable future.

\subsection{Identity}

The naming scheme described in section 3.1 ensures that a
Distinguished Name will only ever refer to one entity.

\subsubsection{Identity translation rules}

Section 4.1 describes NCSA process for vetting its users based on
employment at NCSA, peer review by NSF allocation processes, or direct
contact with NCSA management or PIs.

Section 1.3.2 describes how all certificate requests are authenticated
using NCSA's Kerberos 5 domain.

Section 5.4 describes NCSA's audit procedures.

Section 6.1.3 describes NCSA's use of Kerberos authentication and
integrity protection to deliver public keys to the CA.

\subsubsection{Removal of an authority from the authentication profile accreditation}

No requirement specified.

\subsection{Operational Requirements}

Section 5.1 describes how the hosts operating NCSA's PKI are housed in
NCSA's access-controlled machine room.

Section 6.2 describes NCSA's use of a FIPS 140-2 level 3 Hardware
Security Module to secure the private keys of its CA.

Section 6.5 describes the computer security controls used to limited
network access to the NCSA PKI.

Section 6.3.2 provides lifetime information on certificates in the
NCSA PKI.

NCSA's use of a Hardware Security Module replaces the use of a pass
phrase on the CA private key.

\subsubsection{Certificate Policy and Practice Statement Identification}

Section 1.2 provides an identifying OID for this policy.

Section 9.12 describes the change process for this policy, including
re-accredidation and change of OID.

\subsubsection{Certificate and CRL profile}

Section 7.2 provides the certificate profile for certificates issued
by the NCSA PKI.

Section 6.1 describes the procedures for private key generation and
delivery to the CA under Kerberos 5 protection. 

Section 6.1.5 states that keys must be at least 1024 bits long.

Section 6.3.2 states that end entity certificates will have a lifetime
of not more than one week.

Section 3.1 provides the scheme used by the NCSA PKI to generate
unique common names using representation of actual end entity names.

\subsubsection{Revocation}

The NCSA-SLCS does not support revocation.

\subsubsection{CA key changeover}

Section 5.6 describes the key changeover process.

\subsection{Site Security}

Section 6.2 describes NCSA's use of a FIPS 140-2 level 3 Hardware
Security Module to secure the private keys of its CA.

\subsection {Publication and Repository responsibilities}

Section 2 provides information a URL for an online repository
maintained by NCSA for the NCSA PKI, intended to be continuously
available.

Section 1.5.2 provides both electronic and physical addresses at NCSA
to contact regarding the NCSA PKI.

This policy and all information in the NCSA PKI repository may be
freely distributed.

\subsection{Audits}

Section 5.4 describes NCSA's audit procedures.

Section 5.2 provides the list of NCSA employees with access to the
NCSA PKI.

\subsection{Privacy and confidentiality}

The NCSA PKI collects no private information.

\subsection{Compromise and disaster recovery}

The NCSA PKI is housed in NCSA's main machine room and makes use of
NCSA's general disaster recovery procedures.

The NCSA PKI maintains two identical machines with identical Hardware
Security Module to protect against the failure of a single piece of
hardware.

\subsubsection{Due dilligence for subscribe induced compromises}

User documentation provided for the current NCSA CA can be viewed at
the URL below. Similar documentation will be produced for the new NCSA
PKI.

http://www.ncsa.uiuc.edu/UserInfo/Grid/Security/GetUserCert.html
