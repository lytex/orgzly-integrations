mkdir -p ~/.shortcuts/tasks

cp kill_wrapper.sh ~/.shortcuts
cp launch_git-sync.sh ~/.shortcuts
cp launch_clock-goto.sh ~/.shortcuts
# cp launch_git-sync.sh ~/.shortcuts/tasks # Disabled, not working
cp remove_notifs.sh ~/.shortcuts/tasks
cp tail_log.sh ~/.shortcuts
cp sync_now.sh ~/.shortcuts


termux-fix-shebang ../git-sync.sh
termux-fix-shebang ../wrapper.sh
