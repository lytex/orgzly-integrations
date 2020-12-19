# Installation on Android

* Have a repo (preferably ssh)
* Copy your ssh credentials and config to your Android device
  * For example, this credentials will be at `/storage/emulated/0` and will be `myrepo`, `myrepo.pub`, `config`
* Install termux and termux-api
* Copy your config `mkdir ~/.ssh && cp myrepo ~/.ssh && cp myrepo.pub ~/.ssh && cp config ~/.ssh`
* If you use orgzly in a sd card, install XInternalSD for example, **and set the termux root directory to sd card before first opening it**
* Open termux
  * Install [termux-setup-storage](https://wiki.termux.com/wiki/Termux-setup-storage) with `pkg update && pkg upgrade && termux-setup-storage`
  * Install [termux-api](https://wiki.termux.com/wiki/Termux:API) with `pkg install termux-api`
  * Install all necessary dependencies `pkg install openssh git inotify-tools python`
* Clone this repo in your home directory for example: `cd ~ && git clone https://github.com/lytex/orgzly-integrations && cd orgzly-integrations`
* Install the python requirements`pip3 install -r requirements.in || pip3 install -r requirements.txt`
* Copy .env and edit as needed `cp .env.example .env && nano .env`
* ORG_DIRECTORY should be something like `data/data/com.termux/files/home/storage/shared/orgzly` if orgzly is installed in the Internal Storage
* ORGZLY_FILE_INDEX should be a file inside ORG_DIRECTORY (I choose 0.org since orgzly notebooks are sorted alphanumerically so that it will be always at the top)
* Clone your repo. For example you can use the ORG_DIRECTORY variable you have just defined (make sure orgzly is empty, otherwise the repository won't be cloned) `source .env && git clone <path to your .org repo> $ORG_DIRECTORY`
* Launch wrapper.sh

# Autostart
## termux
* Run `cd termux && install.sh`
## KDE
* Run `kde/install.sh`

