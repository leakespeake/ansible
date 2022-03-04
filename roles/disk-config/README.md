# LVM Disk Management role

With LVM (Logical Volume Manager), we can create logical partitions that can span across one or more physical hard drives. It provides a more dynamic way to create, resize or delete logical volumes than the traditional method of partitioning a disk into one or more segments and formatting them with a filesystem. 

The purpose of this Ansible role is to leverage LVM2 to automate the partitioning and setup of any additional disks supplied to the VM via Terraform (additional to the root partition created from the Packer template). Common use cases for separately mounted partitions are for **/var** and **/home** as per below;

- **/**         root partition - minimum size 8 GB but 15 GB recommended (15 GB Packer template used) - ample if you utilize another disk / partition scheme

- **/var**      primarily for logging and docker related files (/var/lib/docker) but may also house other application data
- **/home**	    personal files that warrant recovery in the face of a corrupt OS

Many options are available with LVM, such as creating a new volume group with new logical volumes or adding to and extending existing ones.

![Screenshot](https://github.com/leakespeake/ansible/blob/master/LVM.jpg)

The skeleton directory structure for this role was created with Ansible Galaxy;

```
ansible-galaxy role init disk-config
```
The role has been fully tested on Ubuntu Server 20.04 LTS and uses the following Ansible modules to complete all disk configuration tasks;

- **parted** - create partitions from a block device
- **lvg** - create, remove or resize volume groups - also runs 'pvcreate' if required
- **lvol** - create, remove or resize logical volumes
- **filesystem** - create a filesystem (ext4)
- **mount** - control active and configured persistent mount points in /etc/fstab - ideally by UUID rather than block device path


## Examples

We can control which modules we utilize by the variables we pass via the playbook **disk-config.yml** - example configs include:

Extend then resize the current root partition;
```
  vars:
    parted:
    # creates /dev/sdb1 partition from /dev/sdb block device
      - device: /dev/sdb
        number: 1
        label: gpt
        flags: [ lvm ]
        state: present
    lvg:
    # add /dev/sdb1 partition to our volume group - in addition to /dev/sda3
      - vg: ubuntu-vg
        pvs:
          - /dev/sda3
          - /dev/sdb1
    lvol:
    # extend existing logical volume 'ubuntu-lv' using the size of all remaining space in the volume group, then resize the filesystem
      - vg: ubuntu-vg
        lv: ubuntu-lv
        shrink: no
        size: 100%VG
        resizefs: true
```
Create a new logical volume from the existing volume group, format, then mount it;
```
  vars:
    parted:
    # creates /dev/sdb1 partition from /dev/sdb block device
      - device: /dev/sdb
        number: 1
        label: gpt
        flags: [ lvm ]
        state: present
    lvg:
    # add /dev/sdb1 partition to our volume group, in addition to /dev/sda3
      - vg: ubuntu-vg
        pvs:
          - /dev/sda3
          - /dev/sdb1
    lvol:
    # create a new logical volume 'lv-data' using the size of all remaining space in the volume group
      - vg: ubuntu-vg
        lv: lv-data
        shrink: no
        size: 100%FREE
    filesystem:
    # format the logical volume with the ext4 filesystem
      - fstype: ext4
        dev: /dev/ubuntu-vg/lv-data
    mount:
    # create a persistent mount in /etc/fstab
      - path: /var
        src: /dev/ubuntu-vg/lv-data
        fstype: ext4
        opts: defaults
```

## Usage
Normally loaded from **site.yml** - otherwise use the following;
```
ssh-copy-id -i ~/.ssh/id_rsa.pub username@fqdn
ansible -i ~/ansible/inventory.ini ubuntu_20_04_prd -m ping
ansible-playbook -i ~/ansible/inventory.ini -u ubuntu --ask-become-pass disk-config.yml
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
