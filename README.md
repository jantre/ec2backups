ec2backups
==========

Take a snapshot of ONLY the volumes attached to the instance this script is executed on.
This script will also remove snapshots older than the RETENTION_DAYS value.
Unfortunately the ec2-create-snapshot script does not take in a name parameter so we set the description to the defined hostname, instance ID, Volume ID, and timestamp.

NOTE: If you detach a volume from an instance, this script does not know about it so you should handle what you want to do with the snapshots of that volume manually.
