# LVM Disk Management role

With LVM (Logical Volume Manager), we can create logical partitions that can span across one or more physical hard drives. It provides a more dynamic way to create, resize or delete logical volumes than the traditional method of partitioning a disk into one or more segments and formatting them with a filesystem. 

The purpose of this Ansible role is to leverage LVM2 to automate the partitioning and setup of the additional disk supplied to the VM via Terraform (additional to the root partition created from the Packer template). This extra disk will be be mounted to /var to complete our disk usage as follows;

- **/**         root partition - minimum size is 8 GB but 15 GB recommended (15 GB Packer template used) - this is ample if you utilize another disk / partition scheme
- **/var**      dedicated primarily for logging and docker related files (/var/lib/docker) but may also house other application data - size set within Terraform      

NOTE: **/home**	is not partitioned off as these vms are not for personal use.

Many options are available with LVM, such as creating a new volume group with new logical volumes, however in this instance I have decided on the method below;

- add /dev/sdb1 partition (created by parted) to the existing 'ubuntu-vg' volume group - then create a new logical volume to mount to /var
- then have the option to add additional physical disks to this volume group later (if needed) to then either create a new logical volume (for another new mount point) - or - extend the space of a current logical volume (in this case either the one serving **/** or the one serving **/var**)

![Screenshot](https://github.com/leakespeake/ansible/blob/master/LVM.jpg)

The skeleton directory structure for this role was created with Ansible Galaxy;

```
ansible-galaxy role init disk-config
```
The role has been fully tested on Ubuntu Server 20.04 LTS and uses the following Ansible modules to complete all disk configuration tasks;

- **parted** - create partitions from a block device
- **lvg** - create, remove or resize volume groups
- **lvol** - create, remove or resize logical volumes
- **filesystem** - create a filesystem (ext4)
- **mount** - control active and configured mount points in /etc/fstab for persistent mounts


## Usage
```
ssh-copy-id -i ~/.ssh/id_rsa.pub username@fqdn
ansible -i $HOME/ansible/inventory.ini ubuntu_20_04_prd -m ping
ansible-playbook -i $HOME/ansible/inventory.ini -u ubuntu --ask-become-pass disk-config.yml
```

## Troubleshooting
```
ansible-playbook -i $HOME/ansible/inventory.ini -u ubuntu --ask-become-pass disk-config.yml -vvvv

df -h
parted -l
lsblk -x KNAME -o KNAME,SIZE,TRAN,SUBSYSTEMS,FSTYPE,UUID,LABEL,MODEL,SERIAL
ls -ltr /dev/disk/by-id/
ls /dev
pvs -o+pv_used ; vgs ; lvs
mount | grep ^/dev
blkid
cat /etc/fstab
mount -a
```
If a physical disk has been added to a production VM that we cannot afford to reboot - we can run the following to tell the kernel to rescan the SCSI bus;
```
ARRAY1=$(find /sys -type f -iname "scan" -exec bash -c 'echo {} | grep host' \;) ; for i in $ARRAY1 ; do echo "- - -" > $i ; done
```
