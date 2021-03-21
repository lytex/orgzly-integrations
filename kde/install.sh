#!/bin/bash

cat wrapper.sh | sed 's|\#\!/bin/bash|#!/bin/bash\n'"GIT_SYNC_DIRECTORY=$(pwd)|" > ${XDG_CONFIG_HOME:-$HOME/.config}/autostart-scripts/git-sync.sh
chmod +x ${XDG_CONFIG_HOME:-$HOME/.config}/autostart-scripts/git-sync.sh

echo "#!/bin/bash\nkillall wrapper.sh\nkillall git-sync.sh" > ${XDG_CONFIG_HOME:-$HOME/.config}/plasma-workspace/shutdown/exit-git-sync.sh
chmod +x ${XDG_CONFIG_HOME:-$HOME/.config}/plasma-workspace/shutdown/exit-git-sync.sh