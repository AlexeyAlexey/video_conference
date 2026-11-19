#!/bin/bash

# chmod +x ./switch_to_release.sh
# ./switch_to_release.sh remote_user remote_host release

ssh "$1@$2" "ln -sf /home/stream_server/$3/app /home/stream_server"

ssh "$1@$2" "systemctl restart stream_server"
