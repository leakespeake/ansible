![ansible](https://user-images.githubusercontent.com/45919758/85199649-18b72000-b2e9-11ea-8725-df85186a6a57.png)

Various Ansible roles and ad-hoc playbooks - mainly intended for fresh VM deployments via Terraform - then ran via **site.yml** 
```
ansible-playbook -i ~/ansible/inventory.ini -u ubuntu --ask-become-pass site.yml
```
---

# Best Practices
General best practices on how to organise, develop and deploy your Ansible playbooks and roles. 

## Ansible Control Node - communications
Assuming a new install of Ansible via `pip3 install ansible` we'll want to generate an SSH authentication key pair for Ansible use, to avoid passwords for client connections;
```
ssh-keygen -t rsa
```
*Enter file in which to save the key (/home/ubuntu/.ssh/id_rsa):* /home/ubuntu/.ssh/ansible_id_rsa

DO NOT ADD A PASSPHRASE FOR THE PRIVATE KEY

Once created, add the alias ‘keys’ to **~/.bashrc** to start the ssh-agent then load the private key for use;
```
# to list all private keys with directory location use; ssh-add -l
alias keys='eval `ssh-agent` ; ssh-add /home/ubuntu/.ssh/ansible_id_rsa'
```
Ensure your Packer templates either have a dedicated 'ansible' user baked in, or use the initial user account (here we are using 'ubuntu') - either way, ensure this account is a member of sudoers so that Ansible can use it with sudo and no password on the remote VM - as per **become: true**

Once a VM is deployed via Terraform, we should prep the comms from the Ansible Control Node by; 

- [1] amending **inventory.ini** the reflect the IP(s) of the new VM(s)
- [2] using the **ssh-copy-id** utility to copy your public ssh key to the new VM(s) - the .pub contents should then be visible on the target host(s) in **/home/ubuntu/.ssh/authorized_keys** - note that since we've copied our public key to the ‘ubuntu’ user directory on the target, we must specify this same account as a variable in our inventory via **ansible_user=ubuntu**
- [3] test the connection to the new VM(s) with the **ping module** using the inventory group name(s)
- [4] test sudo group membership for our **ansible_user** account - run **tail -f /var/log/auth.log** in parallel on the remote host and you should see similar to - *Accepted publickey for ubuntu from {source IP) port {source port} ssh2*
- [5] test the VM(s) remote docker daemon connection with **docker -H**
```
[1] nano ~/ansible/inventory.ini
[2] ssh-copy-id -i ~/.ssh/ansible_id_rsa.pub ubuntu@10.10.10.10
[3] ansible -i ~/ansible/inventory.ini ubuntu_group_name -m ping
[4] ssh ubuntu@10.10.10.10 sudo ls /etc
[5] docker -H 10.10.10.10:2376 ps -a
```
Note its safer to ensure only the dedicated Ansible user account can read and write to the inventory.ini file.

---
## Playbook Organisation
A common playbook structure includes some playbooks, an inventory, a directory for roles and others for variables - example below;

```bash
├── ansible.cfg
├── group_vars
│   └── all
├── host_vars
│   └── all
├── inventory.ini
├── playbook1.yml
├── playbook2.yml
├── playbook3.yml
├── site.yml
└── roles
    ├── role1
    │   ├── README.md
    │   ├── defaults
    │   │   └── main.yml
    │   ├── files
    │   │   └── httpd.conf    
    │   ├── handlers
    │   │   └── main.yml
    │   ├── meta
    │   │   └── main.yml
    │   ├── tasks
    │   │   └── main.yml
    │   ├── templates
    │   │   └── webserver.j2
    │   │   └── database.j2
    │   └── vars
    │       └── main.yml
    ├── role2
    └── role3
```
When loading a single role from a playbook, I recommend matching the playbook name to the role name for clarity - i.e. **node-exporter.yml** and **/roles/node-exporter** 

When you have a more complex, single playbook - maybe a large number of tasks and plays, with the YAML exceeding 100 lines - you should divide them into separate playbooks. These can then be loaded via the master playbook (site.yaml) with either an **import_** (static) or an **include_** (dynamic) statement. Both statements allow you to refactor large lists of tasks into smaller logical groupings, aiding clarity, organization and the overarching **DRY** principal in making code reusable.

### Site.yml
This is the top-level, master playbook that is intended to be used across the entire server estate, or "site". Through a clever use of roles and clear, concise playbooks - we can employ the use of **import_** or **include_** statements to load and run them in the desired order - all from one playbook file!

### Import Playbook
Playbooks can be included in other playbooks using the **import_playbook** directive - to run all named Ansible playbooks sequentially and back-to-back. Must be added in the top level of the playbook as you cannot use this action inside a play itself - i.e. place outside the **tasks:** section.
```yaml
- hosts: all 
  remote_user: root
  tasks: 
    [...]
- import_playbook: web.yml
- import_playbook: db.yml
- import_playbook: 04-firewall.yml
```

### Import Tasks and Import Role
The `import_tasks` directive, imports a list of tasks to be added to the current playbook for subsequent execution - example below;
```yaml
tasks:
  - import_tasks: tasks/apache.yml
handlers:
  - import_tasks: handlers/apache.yml  
```
It's recommended to utilize **import_role** over the older `roles:` to load a role from the playbook, as it allows you to control when the role tasks run, in between other tasks of the play.
```yaml
  tasks:
    - name: load the node exporter role
      import_role:
        name: node-exporter
```        
All `import_` statements are pre-processed at the time playbooks are parsed - i.e. Ansible statically imports the task file as if it were part of the main playbook, BEFORE the Ansible play is executed. The alternative approach is to use `include_` statements. 

### Include Tasks
Include statements are processed as they are encountered DURING the execution of the playbook. If you need to have tasks that are dynamic - i.e. they need to do different things depending on how the rest of the playbook runs, then you can use **include_tasks** rather than the static `import_tasks` statement.

A common use case for `include_tasks` is to run different tasks depending on the OS of the host - consider the following;
```yaml
  tasks:
    - name: "import ubuntu tasks"
      include_tasks: "ubuntu.yaml"
      when: ansible_distribution == Ubuntu 
    - name: "import centos tasks"
      include_tasks: "centos.yaml"
      when: ansible_distribution == CentOS
```
The dymanic nature means the task options will only apply to the dynamic task as it is evaluated - i.e. if our inventory.ini only contains Ubuntu hosts, the CentOS portion will be skipped and only Ubuntu tasks applied. If we used an `import_` statement here instead, all the CentOS tasks would be imported anyway - reducing performance and cluttering terminal output. 

Note - the **when** keyword is covered next.

---
## Ansible Facts and Running Tasks Conditionally
By default, Ansible gathers facts at the beginning of each play. Ansible facts contain information about the remote system to be managed - these are returned back to the Control Node and stored in an **ansible_facts** variable. To access them ad-hoc from the Control Node we use the **setup** module to either dump all gathered facts into the terminal (too verbose) - or use a filter;
```
ansible -i ~/ansible/inventory.ini all -m setup
ansible -i ~/ansible/inventory.ini all -m setup -a "filter=ansible_distribution"
ansible -i ~/ansible/inventory.ini all -m setup -a "filter=ansible_os_family"
```
This can be useful to debug your playbook as it shows you what Ansible sees.

To access this variable data from within the playbook itself, we need to use the actual name without the ansible keyword - such as
```yaml
{{ ansible_facts['distribution'] }}
{{ ansible_facts['os_family'] }}
```
We can leverage this data to control when paticular tasks are ran. Consider the following - the playbook run fails when it’s not a Ubuntu system;
```yaml
- name: Stop if remote OS is not supported
  assert:
    that:
      - ansible_facts['distribution'] == "Ubuntu"
    fail_msg: "This playbook doesn't support the target system."
```
Other times we may want specific tasks to execute when a certain condition is met, without exiting from the playbook run. To do this, add a conditional at the end of a particular task via the **when** keyword - this will provide the conditions for when to process the task;
```yaml
- name: copy jinja template to /home/ubuntu
  template:
    src: template.j2
    dest: /home/ubuntu
    owner: root
    group: root
    mode: '644'
  when: ansible_facts['distribution'] == 'Ubuntu'
```
This is a basic conditional but they have the scope to become a lot more complex.

---
## Roles
As we did with the `import_` and `export_` statements above, we can further refactor a playbook via the use of Ansible roles. 

Roles provide a way for you to make it easier to reuse Ansible code generically. They let you automatically load related vars, files, tasks, handlers, etc based on a known file structure. After you group your content in roles, you can easily reuse and share them by loading them from within a playbook. They are well suited to similar tasks (say - managing user accounts) that might be spread across many playbooks. 

If you find such tasks that operate independently then they can be broken out into their own Ansible role - you can work on extracting those tasks and related handlers, variables, and templates. Abstracting these tasks into Ansible roles means you can maintain one set of tasks to be used among many playbooks, with variables to give flexibility where needed. Nice.

- use a `requirements.yml` file to define role dependencies and define specific versions for the roles so you can choose when to upgrade your dependencies
- when developing a role keep them loosely-coupled - limit hard dependencies on other roles or external variables
- always declare a specific version such as a tag or commit

Ansible roles can also be contributed back to the community via Ansible Galaxy if you're able to make them generic and provide the code with an open source license.

### Create a role directory
First use `ansible-galaxy` to create the skeleton directory structure for a ansible role;

```bash
ansible-galaxy role init roles/<role_name>
```
Assuming a role name of 'test-role', we can `tree test-role` to view a template structure like below;

```bash
test-role
├── README.md
├── defaults
│   └── main.yml
├── files
├── handlers
│   └── main.yml
├── meta
│   └── main.yml
├── tasks
│   └── main.yml
├── templates
│   └── webserver.j2
│   └── database.j2
└── vars
    └── main.yml
```
You must include at least one of these directories in a role. You can omit any directories the role does not use.

### Tasks
Always `name:` your plays and tasks. Adding a meaningful description helps document the intent to users when running a play.

### Handlers
Handlers are special tasks that only get executed when triggered by another task via the `notify` directive. They are executed just once, at the END of the play, once all tasks are finished. If you want to force handlers to run immediately, without waiting for the end of the play, add a `meta: flush_handlers` task;
```yaml
tasks:
  - name: "Some task"
    command: ...

  - name: "Flush handlers"
    meta: flush_handlers

  - name: "Some other task"
    command: ...
```
Also, if you want to always run handlers, even after the playbook has failed use the command line flag `--force-handlers` when running the playbook.

---
## Controlling Order of Execution with pre_tasks and post_tasks
A playbook will run in an order of execution;

- when you use `import_roles:` to load roles from the playbook, they will run first (in order), before any tasks that you define for that play.
- the play tasks execute as ordered in the tasks list. 
- after all tasks execute, any notified handlers are executed. Role handlers are added to the handlers list first, followed by any handlers defined in the handlers section of the play.

However, you can add additional flexibility to your playbooks by executing tasks at different points during a playbook run. In certain scenarios it may be necessary to execute some play tasks BEFORE all other tasks, including roles. In this case, configure a play with a `pre_tasks:` section. Any tasks listed here execute before any roles are executed. If any of these tasks notify a handler, those handler tasks execute before the roles or normal tasks.

Likewise, `post_tasks` will run after all others, including any handlers defined by other tasks. 

This functionality can be useful for anything from silencing hosts in monitoring to sending alerts to your internal chat tools on successful playbook runs.

---
### Using become for root access
Try and set `become` explicitly on each task that requires it, rather than at a global level of the playbook. It's clearer and it documents those tasks that require root access.

### Modules
Always use Ansible modules, ie. use available tasks rather than “command” or “shell”. Modules are **idempotent** out-of-the-box whereas command and shell usually isn't. 
Sometimes you can’t avoid doing things without running a command in a separate shell, but for the most part Ansible will have the module for you!

### Booleans
Consistently use `true` and `false` - or - `yes` and `no` in lower case to indicate a boolean value. Booleans can also be expressed in many ways, you might see “yes” instead of “true”. Both are syntactically correct, but you should stick to one for clarity.

### Don’t Expose Sensitive Data in Ansible Output
Do not expose sensitive data in the Ansible output or out to logs. Mark tasks that expose them with the `no_log: True` attribute. 

However, this attribute does not affect debugging output, so be careful if debugging playbooks in a production environment. You can also use ansible-vault to hide sensitive data in playbooks and roles. 

### Secrets
All secrets should be stored in Vault. To read or write secrets to Vault use the Ansible role `vault-password-generation`. This role reads to check if a secret exists.
If it does, it sets the secret value to a fact which can be used in your play. If it doesnt exist, then it generates and writes the secret to vault. This process will also aid additional automation you might setup with CI/CD systems such Jenkins.

### Dont clutter output with Debug
Debugging tasks can clutter the output, apply some housekeeping with the `verbosity` parameter: 

```yaml
- name: Output debug message
  debug:
  msg: "This always displays"
- name: Output debug message
  debug:
  msg: "This only displays with ansible-playbook -vv"
  verbosity: 2
```
You can also define these settings in `[defaults]` section in **ansible.cfg** to enable debug in Ansible and set the level of verbosity.

Remember - the debug output can also include secret information despite `no_log` settings being enabled, which means debug mode should not be used in production.

---
## Variables and Defaults
Support DRY principals and define your own specific variables. Only use lower case letters, numbers and underscores for the naming convention - e.g. `web_port_01` etc and avoid duplicating names of the predefined "magic" variables.

Ansible variables can be specified in multiple locations and have an order of precedence that should be considered when creating playbooks and roles - i.e. define a variable based on the kind of control you might want over values. My general approach is the following (note the order from the top (highest precedence) to bottom (lowest);

- **--extra-vars** - pass this flag with `ansible-playbook` at runtime to supersede everything! Useful to test a new value for a variable that is widely stated throughout the play, that you don't want to amend yet elsewhere. Or last minute ad-hoc cases.

- **inventory.ini** - only state connection specific "magic" variables here to influence how the Ansible Control Node will connect and execute tasks on a target system - such as `ansible_user` and `ansible_connection`

- **roles/vars/main.yml** - not intended to be modified - static role variables such as a set list of packages. The intent of these variables is that they are used by the internal functioning of the role. 

- **roles/defaults/main.yml** - intended to be customized if required - easily overriden role variables, most commonly used to modify behavior (port number or default user). Use for variables that can be used in a play to configure the role or customize its behavior.

- **host_vars/host1.example.com.yml** - applies to individual hosts stated in inventory.ini - superceeds anything set in group_vars (below).

- **group_vars/group_example1.yml** - applies to individual groups stated in inventory.ini - you may want common variables set within `ubuntu.yml` for the `[ubuntu]` group and `centos.yml` for the `[centos]` group. You can also use `all.yml` to set variables used for every host that Ansible is ran against - use only for very common defaults.

We use Jinja2 syntax (double curly braces) to reference variables within the playbook - YAML requires quotes to parse the whole expression - such as;
```yaml
app_path: "{{ base_path }}/app-v1"
```
Ansible variables also form a powerful combination with the Jinja2 templating engine.

## Jinja Templates
A Jinja2 template file is a text file that contains variables that get evaluated and replaced by actual values upon runtime. Ansible uses Jinja2 templating to enable dynamic expressions and access to variables and facts. In most cases, Jinja2 template files are used for creating bespoke files or replacing configuration files on servers. For instance, your `templates/index.html.j2` file might contain;
```
<center><h1> The Apache webserver is running on {{ ansible_hostname }} </h1>
```
The built-in variable `ansible_hostname` would then be parsed and baked into the resulting landing page (index.html) as per the example below;
```yaml
tasks:
  - name: Replace index.html for Apache
    template:
      src: /templates/index.html.j2
      dest: /var/www/html/index.html
      mode: 0775
```
Templating offers an efficient and flexible solution to create or alter configuration file with ease - recommended whenever applicable. Also note you can explore Jinja2 filtering to manipulate the data in the playbook (much like many of the Terraform functions can manipulate data).

---
## Speeding up Playbooks
You can tweak the performance of Ansible via its configuration file - run **ansible --version** to locate the one in use - normally *config file = /etc/ansible/ansible.cfg*

1. It's a good idea to benchmark the length of a play first to cross compare later - this can be done via callback plugins - add the following lines in `[defaults]`;
```
# Enable timing information
callback_whitelist = timer, profile_tasks
```
When a play finishes, the final line will read: *Playbook run took 0 days, 0 hours, x minutes, x seconds*

2. By default Ansible has “fork” set to 5, meaning it can run as much as 5 parallel executions. If running a playbook on more than 5 hosts, it will only execute on portions of 5 hosts at a time (in parallel), becoming a potential bottleneck when running much larger host numbers. Amend as needed by adding the following line in `[defaults]`;
```
forks = 20
```
Caveat - this will require more CPU resource on the Ansible Control Node whilst it runs.

3. Pipelining is the Ansible method of speeding up your SSH connections across the network to the managed hosts. It reduces the number of SSH operations required to execute a module by executing many Ansible modules without an actual file transfer.

```
[ssh_connection]
pipelining = True
```
Caveat - need to make sure that requiretty is disabled in /etc/sudoers on the remote hosts or `become:` won’t work with pipelining enabled.

4. I prefer Ansible to gather all facts from the hosts (default behaviour) but if you're doing a large deployment that doesn't depend on it - you can turn it off within the playbook;
```
- hosts: all
  gather_facts: no
```  
It's also possible to gather partial facts that you specify - this can be a good intermediate option.

---
## Ansible Galaxy
Ansible Galaxy hosts Ansible roles and collections created by the community. Instead of writing them from scratch, you can install them locally using the `ansible-galaxy` command line and use them on your playbooks. Browse the role and collections on offer here https://galaxy.ansible.com/ or use `ansible-galaxy search <role>` - either way, pay attention to the quality score, download number etc and OS/version for suitability.

First, check the default path where Ansible roles will be downloaded in `ansible.cfg` and amend `roles_path` in the `[defaults]` section if required.

To install and use an Ansible Galaxy role (example);
```bash
ansible-galaxy role install geerlingguy.apache
```
Then we create our playbook one directory up (in the main Ansible directory) - `touch apache.yaml` to call our new role;
```yaml
  roles:
    # From Ansible Galaxy - latest version
    - role: geerlingguy.apache
    # version: 3.2.0
```
Check the role README for the variables you can override - this should be `defaults/main.yml`

Other useful ansible-galaxy commands;
```bash
ansible-galaxy role list
ansible-galaxy role remove <role> 
```
---

## Ansible Pull
Ansible-pull inverts the default push architecture of Ansible into a pull architecture. I personally avoid using **ansible-pull** as I believe it introduces oddities and prefer to run everything from the centralized Control Node. I also don't like the idea of installing Ansible on every node as it seems to align more to an agent-like approach. However, if you wanted to incorporate it into your bootstrap scripts, the following would download your Ansible repo and run the playbooks locally on the node;

```
sudo apt update
sudo apt install ansible -y
sudo ansible-pull -U https://github.com/leakespeake/ansible.git
```
---
## Troubleshooting
You can perform the following to run additional pre-flight checks or produce verbose output when encountering playbook failures;

```
ansible-inventory -i ~/ansible/inventory.ini --list
ansible -i ~/ansible/inventory.ini all -m setup -a "filter=ansible_distribution"

ansible-playbook -i ~/ansible/inventory.ini -u ubuntu --ask-become-pass my-playbook.yml --syntax-check
ansible-playbook -i ~/ansible/inventory.ini -u ubuntu --ask-become-pass my-playbook.yml --check
ansible-playbook -i ~/ansible/inventory.ini -u ubuntu --ask-become-pass my-playbook.yml --vvvv
```