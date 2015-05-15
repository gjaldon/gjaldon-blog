---
title: Deploying Phoenix with Git
date: 2015-05-14 12:34 UTC
tags: phoenix, deployment
---

## Introduction

I have always enjoyed the experience of doing Heroku-like `git push` deploys and just
recently set up deployment for my Phoenix application. It turns out, setting this
up doesn't take too much time and immediately pays dividends. In this article
I'll show you how to set up your server so that it automatically does the
following:

  1. Deploy the app to the server
  2. Install all dependencies
  3. Build production assets
  4. Run all Ecto migrations

Throughout this tutorial we will assume a VPS that uses Ubuntu.


## Configure Server for the Application

Since we are not building a [release](https://github.com/bitwalker/exrm), we will need
to install the dependencies so that Phoenix can run its mix tasks and build its assets.
A default Phoenix app will need the following installed:

~~~

wget http://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && sudo dpkg -i erlang-solutions_1.0_all.deb
sudo apt-get update
sudo apt-get install elixir nodes-legacy npm postgresql postgresql-contrib
npm install -g brunch
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
~~~

We need `node`, `npm` and `brunch` since they come as the default build tool for Phoenix.
We also redirect connections from `port 80` to `port 8080` since we will have the
app listen to `port 8080`.


## Server as Remote Git Repository

For us to be able to push our code to the server, we will need to configure it as a
remote repository. To do this, you will need to do the following from your VPS:

~~~

cd /var
mkdir repo && cd repo
mkdir app.git && cd app.git
git init --bare
~~~

From our local machine, we could push code to the server by doing:

~~~

git remote add production ssh://user@yourserver/var/repo/app.git
git push production master
~~~

Inspecting your VPS's `/var/repo/app.git` directory, you will see that there are no source
files there from your app. This is due to the `--bare` option we passed earlier. Remote
repositories are usually bare repositories since they are meant to accept code pushes
from different collaborators. Having a working directory of your app in the bare repo will
just lead to conflicts.

So how do we deploy the app when we don't have its source available after a `git push`?


## The Post-Receive Hook

Git provides [hooks](http://git-scm.com/book/en/Customizing-Git-Git-Hooks) that get run after
certain actions. The hook we want is the `post-receive` hook since it gets triggered every
time your server receives a push.

In the VPS, we do the following:

~~~

mkdir -p /var/www/app.com
cd /var/repo/app.git/hooks
vim post-receive
~~~

Feel free to use whatever editor you like. From the editor, type:

~~~

#!/bin/sh
git --work-tree=/var/www/app.com --git-dir=/var/repo/site.git checkout -f
(cd /var/www/app.com &&
  npm install &&
  bower install &&
  brunch build --production &&
  mix phoenix.digest &&
  MIX_ENV=prod PORT=8888 mix do deps.get, deps.compile, ecto.migrate &&
  MIX_ENV=prod PORT=8080 elixir --detached -S mix phoenix.server)
~~~

The `git` line checks out the source files of our app to the `/var/www/app.com` directory.
We can then serve our app from that directory later on.

The last line starts our app on `port 8080` in detached mode if it hasn't started yet. You
may change port you want your app to listen on.

The other commands will install all of our app's dependencies, build all its assets, and
run all the Ecto migrations every time we `git push` to the repo.

One last thing:

~~~

chmod +x /hooks/post-receive
~~~

The above command makes sure we can execute the `post-receive` file.


## Configure the Database

We need to create the production database for our app and configure it in Phoenix
so Ecto can access it.

~~~

sudo -u postgres createuser --superuser $USER
sudo -u postgres psql
~~~

Using the postgres role, we created a new role with the same name as your login name.
We then access psql as the postgres user to set the password for the new role. Take
note of the login name and the new password since we will use this later for configuring
Ecto.

~~~

postgres=# \password $USER
~~~

Then we can create the production database.

~~~

createdb app
~~~

Next, we configure Ecto so it can access our production database.

~~~

vim /var/www/app.com/config/prod.secret.exs
~~~

The file will look like:

~~~elixir

config :app, App.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "your_login_name",
  password: "your_password",
  database: "app",
  size: 20
~~~

Replace the `username`, `password` and `database` options with new ones we created earlier
through `psql`.


## Test and Deploy

Congratulations! You can now do `git push` deploys to your server with:

~~~

git push production master
~~~

You should be able to see all the installs, builds and migration commands running after
the `git push`.

If you have no new code to push yet and want to test if your `post-receive` hook works,
you can do below from your VPS:

~~~

cd /var/repo/app.git
git log -2 --format=oneline --reverse
~~~

Get the sha for the 2 commits and replace them with `$SHA1` and `$SHA2` below:

~~~

echo "$FROM_ID $TO_ID master" | ./hooks/post-receive
~~~

Voila! You get to test if your `post-receive` hook works without pushing any code!

I found this deployment strategy to be simple to set up and wrap my head around. It
made it easy to ship code to production without the overhead of learning another tool.

Feel free to share your deployment strategy and let me know if you have any questions
or feedback. Looking forward to hearing from you!


##### References:

  - <a href="https://www.digitalocean.com/community/tutorials/how-to-set-up-automatic-deployment-with-git-with-a-vps" target="_blank">How To Set Up Automatic Deployment with Git with a VPS</a>
  - <a href="http://www.phoenixframework.org/v0.12.0/docs/advanced-deployment" target="_blank">Phoenix Advanced Deployment</a>
  - <a href="http://git-scm.com/book/ca/v1/Git-on-the-Server" target="_blank">Git on the Server</a>
  - <a href="http://krisjordan.com/essays/setting-up-push-to-deploy-with-git" target="_blank">Setting up Push-to-Deploy with git</a>
