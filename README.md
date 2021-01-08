# Purpose of this integrations
This is mostly a set of small tools I built to scratch some itches I have with orgzly.
Some of them work quite OK, but some of them are more flimsy. Tested on Linux only.

* I run some scripts each day at night on a Raspberry Pi (`create_journal.py`, `link_translation.py`)
and each 30 minutes (`make_index.py`)
* `git-sync.sh` is meant to be the core of synchronization across all devices, which is itself launched as a service by `wrapper.sh`. Works
* `clock-goto.sh` is used to create a persistent nofitication which jumps to the currently clocked task on Android

## Environment variables
* These are defined at a `.env` in this repo (which is convenintly gitignored). Copy `.env.example` to `.env` to get started
* `ORG_DIRECTORY` should be something like `/data/data/com.termux/files/home/storage/shared/orgzly` if orgzly is installed in the Internal Storage or `/home/user/org` in a desktop environment
* `ORGZLY_FILE_INDEX` (Android only) should be a file inside ORG_DIRECTORY (I choose 0.org since orgzly notebooks are sorted alphanumerically so that it will be always at the top) `/data/data/com.termux/files/home/storage/shared/orgzly/0.org` in this case
* `SYNC_HOST` is the name of your ssh host, defined in `~/.ssh/config`

ORG_DIRECTORY="/home/user/org"
ORGZLY_FILE_INDEX="/home/user/org/0.org"
SYNC_HOST="my_ssh_host" # Name of your ssh host defined in ~/.ssh/config

## link_translation.py

### Stripping away the directory part of the links (workaround)
Since orgzly has no directory structure, links with a folder before the actual `.org` filename get interpreted as relative to `/storage/emulated/0` (by default on Android).

Check out [Add two settings to configure relative path for file links.](https://github.com/orgzly/orgzly-android/pull/773) which may solve this issue.
This PR is merged but orgzly hasn't released yet, so in order to use it one would have to build orgzly from source.

`[[file:projects/python/scrapping.org]]` will get converted to `[[file:projects/python/scrapping.org]] [[file:scrapping.org]]` (notice the original link has been replaced).
By using backreferences, it is guaranteed that the same link won't be added twice (`[[file:projects/python/scrapping.org]] [[file:scrapping.org]] [[file:scrapping.org]]`).

Then in orgzly you would add your `projects/python` folder to the repositories and the link will work as in desktop emacs.

By doing that, we get a first link which can be used on emacs (with all the folder structure) and a second "flattened" link than can be used on orgzly.

### Convert custom_id links to ID links
While on the go, making links by ID can be difficult and time consuming, while custom_id links are way easier to make.
This converts all custom_id links to ID links for the sake of standarization.

## Managing many files and directory structure with orgzly (make_index.py)
orgzly has a left bar to open a notebook (.org file). However with many .org files, this becomes unwiedly.
* `make_index.py` creates an index mimicking the directory structure of your folder with an org-mode tree, with links to each note.
* I name it `0.org` (zero) so that it stays at the top of that left bar, easily accessible
* As a feature, you can also search by filename using a [search expression](http://www.orgzly.com/help#search) like this: `b.0 <filename>`.

## Jump to currently clocked heading (workaround) (clock-goto.sh)
Check out the status of [Add Clocking / Time capture implementation](https://github.com/orgzly/orgzly-android/pull/691).
Gets the currently clocked item and opens a orgzly search for that note so you can clock-out or cancel clocking.

## Create a empty journal entry of today (create_journal.py)
WARNING: Overwrites a previously existing journal
Creates a new .org file (overwriting previously existing journals) with Spanish locales ("Europe/Madrid" sets the timezone and "es_ES.utf8" sets the day of week naming). Modify accordingly to your needs.

# Installation on Android
* Have an existing repo (preferably ssh) with all your org files 
* Copy your ssh credentials and config to your Android device
  * For example, this credentials will be at `/storage/emulated/0` and will be `myrepo`, `myrepo.pub`, `config`
* Install termux and termux-api
* Copy your config `mkdir ~/.ssh && cp myrepo ~/.ssh && cp myrepo.pub ~/.ssh && cp config ~/.ssh`
* If you use orgzly in a sd card (needs root), install XInternalSD for example, **and set the termux root directory to sd card before first opening it**
* Open termux
  * Install [termux-setup-storage](https://wiki.termux.com/wiki/Termux-setup-storage) with `pkg update && pkg upgrade && termux-setup-storage`
  * Install [termux-api](https://wiki.termux.com/wiki/Termux:API) with `pkg install termux-api`
  * Install all necessary dependencies `pkg install openssh git inotify-tools python`
* Clone this repo in your home directory for example: `cd ~ && git clone https://github.com/lytex/orgzly-integrations && cd orgzly-integrations`
* Install the python requirements`pip3 install -r requirements.in || pip3 install -r requirements.txt`
* Copy .env and edit as needed `cp .env.example .env && nano .env`
* Clone your repo. For example you can use the ORG_DIRECTORY variable you have just defined (make sure orgzly is empty, otherwise the repository won't be cloned) `source .env && git clone <path to your .org repo> $ORG_DIRECTORY`
* Install [termux-widgets](https://wiki.termux.com/wiki/Termux:Widget)
* Run `cd termux && install.sh`
* Start the `launch_git-sync.sh` from the termux-widget

# Autostart
## termux
* Run `cd termux && install.sh`
## KDE
* Run `kde/install.sh`

# Android Usage
* `kill_wrapper.sh` kills `git-sync` and its wrapper (stops all synchronization services)
* `launch_clock-goto.sh` creates a persistent notification to go to the currently clocked heading
* `launch_git-sync.sh`  launches git-sync service
* `remove_notifs.sh` removes all notifications created by `launch_git-sync.sh`
  * Run in terminal `termux-notification-remove current_clock` to remove current-clock notification
* `tail_log.sh` See the git-sync log in terminal

## Android 10
* [Since Android 10](https://github.com/termux/TermuxAm/issues/4) apps cannot launch activities from the background. Giving Termux permission to Draw over other apps makes it work, at least on my phone

