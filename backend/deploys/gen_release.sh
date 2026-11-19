#!/bin/bash

# chmod +x ./gen_release.sh
# ./gen_release.sh local_machine_release_dir remote_server_release_dir

echo "Started"

rel_name="$(date +"%Y%m%d_%H%M%S")"

rel_dir_path="$1/$rel_name"

echo "destination: $rel_dir_path"

# mkdir -p temp-video_conference:/app $rel_dir_path
mkdir -p $rel_dir_path

docker build -t video_conference .

docker create --name temp-video_conference video_conference

docker cp temp-video_conference:/app "$rel_dir_path"

docker rm temp-video_conference

cd "$rel_dir_path"

tar -czvf "app.tar.gz" "./app"

echo "tar -czvf app.tar.gz /app"

echo "release was created: $rel_name"

echo "Finished"