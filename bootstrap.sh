#!/bin/bash -e

# https://github.blog/open-source/git/bring-your-monorepo-down-to-size-with-sparse-checkout/

SCRIPTNAME=$0
die() {
	echo "$SCRIPTNAME: $1"
	exit 1
}

TEAM=$1

case $TEAM in
"backend")
	FOLDERS="backend"
	;;
"frontend")
	FOLDERS="frontend"
	;;
"stream_server")
	FOLDERS="stream_server"
	;;
*)
	die "please specify a valid app"
	;;
esac

echo "Running 'git sparse-checkout init --cone'"
git sparse-checkout init --cone

echo "Running 'git sparse-checkout set $FOLDERS'"
git sparse-checkout set $FOLDERS