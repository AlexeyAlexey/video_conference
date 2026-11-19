#!/bin/bash

# chmod +x ./switch_to_release.sh
# ./switch_to_release.sh remote_user remote_host release

ssh "$1@$2" "ln -sf /home/video_conference/$3/app /home/video_conference"


# ssh "$1@$2" "export \$(env xargs < /home/env/video_conference) && /home/video_conference/app/bin/video_conference eval \"VideoConference.Release.migrate\""

ssh "$1@$2"  "set -a && source /home/env/video_conference && set +a && /home/video_conference/app/bin/video_conference eval \"VideoConference.Release.migrate\""
ssh "$1@$2" "systemctl restart video_conference"


# 