mkdir -p ~/.shortcuts/tasks

cp kill_wrapper.sh ~/.shortcuts
cp launch_git-sync.sh ~/.shortcuts
cp launch_git-sync.sh ~/.shortcuts/tasks
cp remove_notifs.sh ~/.shortcuts/tasks


termux-fix-shebang ../git-sync.sh
termux-fix-shebang ../wrapper.sh