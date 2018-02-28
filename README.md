> Why pay for server management when you can use this…

# Anstead

Ansible playbooks for setting up a LEMP stack with Redis for Laravel.

- Local development environment with Vagrant
- High-performance production servers
- One-command provisioning
- One-command deployments

## It's still in development

Anstead is a fork of [Trellis](https://roots.io/trellis) but for Laravel instead of WordPress. 

I've used it in production for over a year however it's only ever had one person use it.

I'm uploading it to show how I changed Trellis to work with Laravel.

I would love to have it merged back into Trellis <span role="img" aria-label="heart">💚</span>

Major changes from Trellis:

- Laravel apps **instead of** WordPress sites
- separate server for the database
- adds Redis
- splits out the web user to a new role as it's only used on the app server
- splits out the MariaDB and app setup roles into client/code and server/database roles
- adds bash aliases to the Vagrant box
- re-adds the `provision.sh` script 
- handlers are now in their own role that other roles have as a dependency - this is because handlers *are* shared between roles **but not** shared between plays and this gets around that
- other than the MariaDB PPA it hasn't been synced with Trellis for a while

TODO:

- [ ] rollbacks
- [ ] xdebug
- [ ] laravel.log file still stored in storage and not managed by logrotate

## Demo

An example project is available at https://github.com/ptibbetts/anstead-example-project

## What's included

This playbook configures the following and more:

* Ubuntu 16.04 Xenial LTS
* Nginx
* PHP 7.1
* MariaDB
* Redis
* Supervisor
* SSL support (scores an A+ on the [Qualys SSL Labs Test](https://www.ssllabs.com/ssltest/))
* Let's Encrypt integration for free SSL certificates
* HTTP/2 support (requires SSL)
* Composer
* sSMTP (mail delivery)
* MailHog
* Fail2ban
* ferm

## Requirements

Ensure all dependencies have been installed before moving on:

* [Ansible](http://docs.ansible.com/ansible/intro_installation.html#latest-releases-via-pip) 2.0.2
* [Virtualbox](https://www.virtualbox.org/wiki/Downloads) >= 4.3.10
* [Vagrant](http://www.vagrantup.com/downloads.html) >= 1.5.4
* [vagrant-bindfs](https://github.com/gael-ian/vagrant-bindfs#installation) >= 0.3.1
* [vagrant-hostmanager](https://github.com/smdahlen/vagrant-hostmanager#installation)

## Installation

```shell
# → Root folder
├── anstead/      # → Ansible / Vagrant folder
└── laravel/      # → Laravel app
```

All Ansible commands should be ran from the `/anstead` directory

```shell
cd anstead
```

## Servers

This playbook has been designed to have three servers in production:

- a web server consisting of application code, PHP & Nginx
- a database server with MariaDB installed
- a separate server for Redis

however it is possible to use only the one server, which is how the staging and development environments are setup.

## Development environment

Vagrant calls the Ansible script to provision a virtual machine for local development.

```shell
vagrant up # start Vagrant
cd /srv/www/example.com/current # all Artisan & Composer commands to be ran here
```

### Aliases

The Vagrant box comes with the following bash aliases:

- `art` is an alias of `php artisan`
- `tinker` is an alias of `php artisan tinker`
- `phpspec` is an alias of `/vendor/bin/phpspec`
- `phpunit` is an alias of `/vendor/bin/phpunit`
- `jsonprettify` is an alias of `python -mjson.tool`

You can customise these aliases and add your own by editing the `/aliases` file.

## Remote server setup (staging/production)

At least one base `Ubuntu 16.04` server is required for setting up remote servers.

### _I want all services on the same server_

This is how the staging environment is setup by default.

To change the production environment you'll need to add the IP address of the server to the `/hosts/production` file under `[production]` and each of the services.

### _I want a separate server for each service_

This is the how the production environment is setup by default but you will still need to configure it to get it to work.

You must make sure each server has private networking (internal IP addresses) enabled so that communication between the servers is both faster and cheaper - you don't usually have to pay for bandwidth on the internal network.

You need to add the domain of the web server and the **external** IP addresses of the database and Redis servers to the `/hosts/production` file. Then you need to add the **private/internal** IP address of each server under the `env` section in the `/group_vars/production/laravel_apps.yml` file.

This is so that you can connect to the servers with Ansible using the external IP but each server can communicate with each other using the internal network.

The database and Redis servers, by default, will only open the SSH port. If you separate the services to their own server then they will also open the port for their respective service.

You also need to SSH into each server once as Ansible seems to struggle accepting multiple new servers at the same time - this would be a good time to run `apt update && apt upgrade -y` before provisioning them.

### Provisioning

Ensure `hosts/{staging,production}` contains the IP address(es) of the server(s) you wish to provision and that
`group_vars/{staging,production}/{laravel_apps, vault}.yml` have been configured, then you can use the provision command to call Ansible:

```shell
bin/provision.sh <environment>
```

## Deployments

Could not be easier:

```shell
bin/deploy.sh <environment> <app name>
```

## Extras

### Installing extra PHP packages

Add the package to the `php_extensions_custom` array in `roles/php/defaults/main.yml` and re-provision the app server by running `ansible-playbook server.yml -e env=production --tags=php`.

### Installing extra software packages

Add the package to the `apt_packages_custom` array in `roles/common/defaults/main.yml` and run the provisioning script again - `htop` is a an example of something I'd add here.

### Laravel Horizon

If you'd like to use [Laravel Horizon]() to manage the queue workers then you need to make the following changes to Anstead:

`anstead/roles/deploy/hooks/finalize-after.yml`

```diff
- - name: Restart all queue workers
-  shell: /usr/bin/php artisan queue:restart chdir={{ deploy_helper.new_release_path }}
+ - name: Restart Horizon
+  shell: /usr/bin/php artisan horizon:terminate chdir={{ deploy_helper.new_release_path }}
```

`anstead/roles/supervisor/templates/laravel-workers.j2`

```diff
- [program:{{ item.key }}-worker]
+ [program:{{ item.key }}-horizon-worker]
- process_name=%(process_num)02d
+ process_name=%(program_name)s
- command=php {{ www_root }}/{{ item.key }}/{{ item.value.current_path | default('current') }}/artisan queue:work --queue=default --tries=2
+ command=php {{ www_root }}/{{ item.key }}/{{ item.value.current_path | default('current') }}/artisan horizon
autostart=true
autorestart=true
user={{ web_user }}
- numprocs=2
+ numprocs=1
redirect_stderr=true
- stdout_logfile={{ www_root }}/{{ item.key }}/logs/worker.log
+ stdout_logfile={{ www_root }}/{{ item.key }}/logs/horizon.log
```

`config/horizon.php`

Change the `local` environment to `development`.