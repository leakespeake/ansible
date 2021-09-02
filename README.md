![ansible](https://user-images.githubusercontent.com/45919758/85199649-18b72000-b2e9-11ea-8725-df85186a6a57.png)

Various Ansible deployments against vSphere, AWS and GCP.

---

# Ansible Best Practices
General best practices on how to organise, develop and deploy your ansible playbooks and roles - IN PROGRESS. 

## 1. DRY (Don't Repeat Yourself)
Ansible has different mechanisms to help you be DRY but it requires that you plan your code in advance. So as an overarching principal when writing your code think how you can make it reusable;
   * import_playbook
   * include/import_role
   * include/import_tasks   

## 2. Playbook Organisation

### Playbook Directory Structure
Common playbook structure includes some playbooks, an inventory, directories for roles and directories for variables:

```bash
├── ansible.cfg
├── group_vars
│   └── all
├── inventory.ini
├── playbook1.yml
├── playbook2.yml
└── roles
    ├── role1
    │   └── tasks
    │       └── main.yml
    ├── role2
    │   └── tasks
    │       └── main.yml
    └── roles.yml
```

### Imports
You can add import_tasks directives like so:
```yaml
handlers:
  - import_tasks: handlers/apache.yml
  
tasks:
  - import_tasks: tasks/apache.yml
```

### Includes
If you use import_tasks, Ansible statically imports the task file as if it were part of the main playbook, once, before the Ansible play is executed. If you need to have included tasks that are dynamic - that is, they need to do different things depending on how the rest of the playbook runs, then you can use `include_tasks` rather than import_tasks.

### Playbook imports
Playbooks can be included in other playbooks, using the same import syntax in the top level of your playbook. For example, if you have two playbooks, one to set up your webservers (web.yml), and one to set up your database servers (db.yml), you could use the following playbook to run both at the same time:

```yaml
- hosts: all 
  remote_user: root
  tasks: 
    [...]
- import_playbook: web.yml
- import_playbook: db.yml
```

### Speed up Playbooks
Set these 3 environment variables or place them in your `ansible.cfg` file:
```bash
export ANSIBLE_FORKS=15
export ANSIBLE_PIPELINING=true
export ANSIBLE_USE_PERSISTENT_CONNECTIONS=true
```
Docs for the settings:
[ANSIBLE_FORKS](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#default-forks), 
[ANSIBLE_PIPELINING](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#ansible-pipelining), 
[ANSIBLE_USE_PERSISTENT_CONNECTIONS](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#use-persistent-connections)

Note - There is a caveat with ANSIBLE_PIPELINING in that it could have issues with playbooks/roles/tasks that use `become` or `become_true`. The usual way to get around this is to disable `requiretty` on host machines before ansible is run on them, but most OS images in the cloud ship with this already disabled we have found.

---
## 3. Roles
Ansible roles provide a way for you to make it easier to reuse Ansible code generically. You can package, in a standardised directory structure, then reuse that role in multple projects with ansible-galaxy. 

  * When developing a role keep them loosely-coupled - limit hard dependencies on other roles or external variables.
  * Do not copy roles into your playbook use ansible-galaxy to install your roles and use files (i.e. requirements.yml) to manifest your project roles. 
  * Always declare a specific version such as a tag or commit.


### Creating a role template
   * Use `ansible-galaxy` to create the skeleton directory structure for a ansible role:

```bash
ansible-galaxy role init <role_name>
```

This give you a template structure like below:

```bash
$ tree test-role
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
├── tests
│   ├── inventory
│   └── test.yml
└── vars
    └── main.yml
```
You must include at least one of these directories in a role. You can omit any directories the role does not use.

### Variables and Defaults
Define a specific variable in either `vars/main.yml` or `defaults/main.yml`. 

   * defaults/ are easy to override and most commonly used to modify behavior, e.g. port number or default user.  Use for variables that can be used in a play to configure the role or customize its behavior.
   * vars/ are used by the role and not likely to be changed, e.g. a list of packages, They have a high precedence and can only be overwritten by passing them on the command line or in the specific task. The intent of these variables is that they are used by the internal functioning of the role. 

### Roles in Playbooks
With roles you can have clean playbooks, e.g.
```yaml
---
- hosts: appservers 
  roles:
    - yum-repo 
    - firewall
    - app-deploy
```

### Controlling Order of Execution
1. When you use a roles section to import roles into a play, the roles will run first, before any tasks that you define for that play.
2. The play tasks execute as ordered in the tasks list. 
3. After all tasks execute, any notified handlers are executed. Note, role handlers are added to the handlers list first, followed by any handlers defined in the handlers section of the play.
4. In certain scenarios, it may be necessary to execute some play tasks before the roles. In this case configure a play with a `pre_tasks` section. Any task listed in this section executes before any roles are executed. If any of these tasks notify a handler, those handler tasks execute before the roles or normal tasks.

### Name plays, blocks and tasks
Always name your plays and tasks. Adding name with a human meaningful description helps document the intent to users when running a play.

## 4. Tasks
### Modules
Always use Ansible modules, ie. use available tasks rather than “command” or “shell”. Modules are idempotent out of the box usig command and shell is usually not. 
Sometimes you can’t avoid doing things without running a command in a separate shell, but for the most part Ansible will have the module for you.

### Booleans
   * Use `true` and `false`.

Booleans can also be expressed in many ways, you might see “yes” instead of “true”. Both are syntactically correct, but you should stick to one for clarity. Use `true` and `false`. 

### 	Use become for root access on Tasks
   * Try and set `become` explicitly on each task that requires it. 

It's clearer, it documents the tasks that require root access, doesn’t make the user use --become on the command line or a more global become in the playbooks.

### Don’t Expose Sensitive Data in Ansible Output
Do not expose sensitive data in the Ansible output or out to logs. Mark tasks that expose them with the `no_log: True` attribute. However, the no_log attribute does not affect debugging output, so be careful if debugging playbooks in a production environment. 
You can also use ansible-vault to hide sensitive data in playbooks and roles. 

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

## 5. Ansible Galaxy
Getting external roles from Galaxy::
```bash
ansible-galaxy role install geerlingguy.apache
```

### roles.yml
To include roles in a playbook pass the ansible-galaxy command a `roles.yml` file with the -r option to automatically download all dependencies. Eg:
```yaml
---
roles:
  # From Ansible Galaxy, latest version.
  - name: geerlingguy.firewall
  
  # From Ansible Galaxy, specifying the version.
  - name: geerlingguy.php 
    version: 4.3.1
  
  # From an internal repo.
  - src: git@github.com:sky-uk/disco-ansible-role-var-sky-mount.git
    name: var-sky-mount
    version: v0.1.0
    scm: git
```

Then to install these roles:
```bash
rm -rf roles/*
This conversation was marked as resolved by PreeyanP
ansible-galaxy install -r roles.yml
```

To display a list of installed roles, with version numbers:

```bash
ansible-galaxy role list 
```

To remove an installed role:
```bash
 ansible-galaxy role remove <role>
```

You can configure the default path where Ansible roles will be downloaded in `ansible.cfg` and setting a `roles_path` in the [defaults] section.

---
## 6. Inventory
To dump the configured inventory as Ansible sees it:
```bash
ansible-inventory -i inv --list
```

---
## 7. Secrets
All secrets should be stored in Vault. 

  * To read or write secrets to Vault use the ansbile role `vault-password-generation`. This role reads to check if a secret exists.
If it exists it set the secret vaule to a fact which can be used in your play, if it doesnt then it generates and writes the secret to vault.
This conversation was marked as resolved by PreeyanP

TODO - vault-password-generation will be moved to its own repo with molecule tests and should be added via ansible-galalxy to your role/playbook.

## 8. Misc Tips

### Handlers
Handlers will only be run if a task notifies the handler and will run once at the END of a play. If you need to  run handlers in the middle of a playbook, you can use the meta module to do so:

	   - meta: flush_handlers

If you want to always run handlers, even after the playbook has failed use the command line flag `--force-handlers` when running the playbook.

### Ansible Facts
To get a list of every gathered fact available use setup module:

```bash
$ ansible -i inventory host -m setup
```

This can be handy to debug your playbook as it shows you what ansible sees.


## 9. Testing
Test your playbooks and roles with `Molecule`.