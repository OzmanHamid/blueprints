﻿Param(
  [Parameter(Mandatory=$True)]
  [string]$AdminUser,

  [Parameter(Mandatory=$True)]
  [string]$AdminPassword,

  [Parameter(Mandatory=$True)]
  [string]$NetBiosDomainName,

   [Parameter(Mandatory=$True)]
  [string]$FqDomainName,

  [Parameter(Mandatory=$True)]
  [string]$GmsaName,

  [Parameter(Mandatory=$True)]
  [string]$FederationName,

  [Parameter(Mandatory=$True)]
  [string]$DescriptionAdfs
)

###############################################
# If you don't have a public signed certificate (e.g.adfs.contoso.com.pfx) by VerifSign, Go Daddy, DigiCert, and etc.
# Here are manual steps to create a self singed test certificate adfs.contoso.com.pfx

# 1. Log on your developer machine

# 2. Download certutil.exe to 
#       C:/temp/certutil.exe 

# 3. Create my fake root certificate authority
#       makecert -sky exchange -pe -a sha256 -n "CN=MyFakeRootCertificateAuthority" -r -sv MyFakeRootCertificateAuthority.pvk MyFakeRootCertificateAuthority.cer -len 2048
#    Verify that the foloiwng files are created
#	    C:/temp/MyFakeRootCertificateAuthority.cer
#	    C:/temp/MyFakeRootCertificateAuthority.pvk

# 4. Run command prompt as admin to use my fake root certificate authority to generate a certificate for adfs.contoso.com
#      makecert -sk pkey -iv MyFakeRootCertificateAuthority.pvk -a sha256 -n "CN=adfs.contoso.com , CN=enterpriseregistration.contoso.com" -ic MyFakeRootCertificateAuthority.cer -sr localmachine -ss my -sky exchange -pe

# 5. Start MMC certificates console 
#	 Expand to /Certificates (Local Computer)/Personal/Certificate/adfs.contoso.com 
#	 Export the certificate with the private key to 
#       C:/temp/adfs.contoso.com.pfx

# 6. Make sure you have the following files in the C:\temp
#	    MyFakeRootCertificateAuthority.cer
#       MyFakeRootCertificateAuthority.pvk
#       adfs.contoso.com.pfx

###############################################
# Manual step for install certificate to the ADFS VMs:

# 1. Make sure you have a certificate (e.g. adfs.contoso.com.pfx) either self created or signed by VerifSign, Go Daddy, DigiCert, and etc.

# 2. RDP to the each ADFS VM (adfs1-vm, adfs2-vm, ...)

# 3. Copy to c:\temp the following file
#		c:\temp\certutil.exe
#		c:\temp\adfs.contoso.com.pfx 

# 4. Run the following command prompt as admin:
#    	certutil.exe -privatekey -importPFX my C:\temp\contoso.com.pfx NoExport


# 5. Start MMC, Add Certificates Console, and verify that the following certificate is installed:
#      \Certificates (Local Computer)\Personal\Certificates\adfs.contoso.com

###############################################

# $AdminUser = "adminUser"
# $AdminPassword = "adminP@ssw0rd"
# $NetBiosDomainName = "CONTOSO"
# $FqDomainName = "contoso.com"
# $GmsaName = "adfsgmsa"
# $FederationName = "adfs.contoso.com"
# $DescriptionAdfs = "Contoso Corporation"

###############################################
# get credential of the domain admin
$secAdminPassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ("$NetBiosDomainName\$AdminUser", $secAdminPassword)

###############################################
# Create global management service accoutn
Add-KdsRootKey –EffectiveTime (Get-Date).AddHours(-10) 
#New-ADServiceAccount adfsgmsa -DNSHostName adfs.contoso.com -AccountExpirationDate $null -ServicePrincipalNames host/adfs.contoso.com -Credential $credential
New-ADServiceAccount $GmsaName -DNSHostName $FederationName -AccountExpirationDate $null -ServicePrincipalNames "host/$FederationName" -Credential $credential

# retrieve the the thumbnail of certificate
$thumbprint=(Get-ChildItem -DnsName $FederationName -Path cert:\LocalMachine\My).Thumbprint
Write-Host $thumbprint

# Install ADFS feature
Install-WindowsFeature -IncludeManagementTools -Name ADFS-Federation
Import-Module ADFS
Add-KdsRootKey –EffectiveTime (Get-Date).AddHours(-10) 
Install-AdfsFarm -CertificateThumbprint $thumbprint -FederationServiceDisplayName $DescriptionAdfs -FederationServiceName $FederationName -GroupServiceAccountIdentifier "$NetBiosDomainName\$GmsaName`$" -Credential $credential -OverwriteConfiguration

# device registration service for workplace join 
Initialize-ADDeviceRegistration -ServiceAccountName "$NetBiosDomainName\$GmsaName`$" -DeviceLocation $FqDomainName -RegistrationQuota 10 -MaximumRegistrationInactivityPeriod 90 -Credential $Credential -Force
Enable-AdfsDeviceRegistration -Credential $Credential -Force

# Create a dns entry for 

# https://adfs.contoso.com/adfs/ls/idpinitiatedsignon.htm