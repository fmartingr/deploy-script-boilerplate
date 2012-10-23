#!/bin/bash

#
# Boilerplate deployment script for django apps
# with coffeescript/less compile and compression
# though nodejs apps
#
# Felipe "Pyronhell" Martín
# Mail:  me@fmartingr.com
# Twitter: @fmartingr
#

#
# Depends on:
# npm/node with coffee-script, less and uglify-js
# git
#

# Void for uncompleted functions
void() {
	echo -n ""
}

# Stylish (thanks to: https://wiki.archlinux.org/index.php/Color_Bash_Prompt)
COLOR_OFF='\e[0m'       	  # Text Reset
# Regular
COLOR_BLACK='\e[0;30m'        # Black
COLOR_RED='\e[0;31m'          # Red
COLOR_GREEN='\e[0;32m'        # Green
COLOR_YELLOW='\e[0;33m'       # Yellow
COLOR_BLUE='\e[0;34m'         # Blue
COLOR_PURPLE='\e[0;35m'       # Purple
COLOR_CYAN='\e[0;36m'         # Cyan
COLOR_WHITE='\e[0;37m'        # White

# Bold
BCOLOR_WHITE='\e[1;30m'       # Black
BCOLOR_RED='\e[1;31m'         # Red
BCOLOR_GREEN='\e[1;32m'       # Green
BCOLOR_YELLOW='\e[1;33m'      # Yellow
BCOLOR_BLUE='\e[1;34m'        # Blue
BCOLOR_PURPLE='\e[1;35m'      # Purple
BCOLOR_CYAN='\e[1;36m'        # Cyan
BCOLOR_WHITE='\e[1;37m'       # White

# $this
SCRIPT_NAME=$0
SCRIPT_PATH="$(dirname $SCRIPT_NAME)"

# $git
REPOSITORY_URL=""
REPOSITORY_CMD="git pull"
REPOSITORY_BRANCH="buffer"

# $commands
LESS_CMD="lessc"
LESS_PARAMS="-x" # compress css

COFFEE_CMD="coffee"
COFFEE_PARAMS="--compile --print" # compile and echo to STDOUT 

UGLIFY_CMD="uglifyjs"
UGLIFY_PARAMS="--overwrite" #

APP_NAME="django_app_name"

# $virtualenv
VENV_PATH="../"
VENV_ACTIVATE_PATH=$VENV_PATH"./bin/activate"
VENV_DEACTIVATE_PATH="deactivate >/dev/null 2>&1"

activate_venv() {
	echo -e "${COLOR_YELLOW}VirtualENV${COLOR_OFF} Activate"
	. $VENV_ACTIVATE_PATH
}

deactivate_venv() {
	echo -e "${COLOR_YELLOW}VirtualENV${COLOR_OFF} Deactivate"
	$VENV_DEACTIVATE_PATH
}

# Read config file
. ./deploy.cfg

# $revisions
DEPLOY_FILE=".last_deploy"
LAST_DEPLOY="$(tail -n 1 $DEPLOY_FILE)"
if [ "$LAST_DEPLOY" != "" ]; then
PREV_REVISION="$(echo $LAST_DEPLOY | awk -F : '{print $1}')"
ACTUAL_REVISON_CHECK="$(echo $LAST_DEPLOY | awk -F : '{print $2}')"
else
	echo -e "${COLOR_YELLOW}INFO${COLOR_OFF} This is your first deploy!"
fi

# (De)activate any active python virtualenv
#. $VENV_ACTIVATE_PATH
if [ -n "$VIRTUAL_ENV" ]; then
	echo -e "${COLOR_YELLOW}VirtualENV${COLOR_OFF} It seems that you have an active virtualenv, trying to deactivate..."
	deactivate_venv &> /dev/null
fi


#
# Get actual actual and remote revisions to use on the deploy system
#
get_revisions () {
	ACTUAL_REVISION="$(git rev-parse --verify HEAD)"
	NEXT_REVISION="$(git ls-remote --quiet | grep refs/heads/$REPOSITORY_BRANCH | awk '{print $1}')"
}

#
# Finish with custom error code
#
finish() {
	echo "Quitting..."
	exit $1
}

#
# Deploy the site
# Git pull the last commit from the selected branch, compile and minify the (less/coffe)->(css/js)
#
deploy() {
	echo "Starting the deploy..."
	get_revisions
	check_revisions
	# Let's check if the remote revision differs from ours
	# (don't use cpu for nothing, dattebayo!)

	# LOCAL-REMOTE REVISION HAI
	if [ "$ACTUAL_REVISION" != "$NEXT_REVISION" ]; then
		# Get last files from active branch
		echo -e "${BCOLOR_WHITE}${REPOSITORY_CMD}${COLOR_OFF} Retrieving last files..."
		$REPOSITORY_CMD #$REPOSITORY_URL

		update_deployfile

		compile_static
		move_to_static_folder

		migrate_database

		restart_app

		echo -n -e "${COLOR_WHITE}Deploy from${COLOR_OFF} $ACTUAL_REVISION "
		echo -n -e "${COLOR_WHITE}to${COLOR_OFF} $NEXT_REVISION: " 
		echo -e "${BCOLOR_GREEN}Finished!${COLOR_OFF}"

		exit 0
	else
		# We already have the last files!!
		echo -e "${COLOR_YELLOW}INFO${COLOR_OFF} Files up-to-date! "
		finish 2
	fi
	# LOCAL-REMOTE REVISION KTHXBYE
}

#
# Updates the $DEPLOY_FILE with new info
#
update_deployfile() {
	echo "$ACTUAL_REVISION:$NEXT_REVISION" >> $DEPLOY_FILE
}

#
# Checks if the actual revision is the same as the logged one
#
check_revisions() {
	if [ "$LAST_DEPLOY" != "" -a "$ACTUAL_REVISION" != "$ACTUAL_REVISON_CHECK" ]; then
		echo "--------------------------------------------------------------"
		echo -e "  ${COLOR_RED}WARN${COLOR_OFF}: The active revision is NOT the same as the logged one!"
		echo " This may cause problems with the revert option. Use with caution."
		echo "--------------------------------------------------------------"
	fi
}

#
# The compile static wrapper for less/css
#
compile_static() {
	compile_coffee
	compile_less
}

#
# Compile coffeescript using node "coffee"
#
compile_coffee() {
	echo -e "${BCOLOR_WHITE}CoffeeScript${COLOR_OFF}: Compile"
	i=0
	for folder in ${COFFEE_FOLDER[*]}
    do
    	for file in ${folder}/*.coffee
    	do
	    	file_name=$(echo "$file" | awk -F "/" '{print $NF}' | awk -F "." '{print $1}')
	    	file_destination_path=${COFFEE_DESTINATION_FOLDER[${i}]}
	    	file_destination="$file_destination_path/$file_name.js"
			if [ -f $file_path ]; then
	    		echo -e "${COLOR_WHITE}+${COLOR_OFF} $file -> $file_destination "
	    		$COFFEE_CMD $COFFEE_PARAMS $file > $file_destination
	    		echo "// Original file at: static/coffee" | cat - $file_destination > /tmp/out && mv /tmp/out $file_destination
				compress_javascript $file_destination
	    	fi
    	done
    	i=$i+1
    done
}

# 
# Compile lesscss using node "lessc"
#
compile_less() {
	echo -e "${BCOLOR_WHITE}LESS${COLOR_OFF}: Compile"
	i=0
	for folder in ${LESS_FOLDER[*]}
    do
        for file in ${LESS_FILES[*]}
        do
        	file_name=$(echo "$file" | awk -F "." '{print $1}')
        	file_path="$folder/$file"
        	file_destination_path=${LESS_DESTINATION_FOLDER[${i}]}
        	file_destination="$file_destination_path/$file_name.css"
        	if [ -f $file_path ]; then
        		echo -e "${COLOR_WHITE}+${COLOR_OFF} $file_path -> $file_destination"
        		$LESS_CMD $LESS_PARAMS $file_path > $file_destination
        	fi
		done
		i=$i+1
    done
}

#
# Compress javascript using node "uglifyjs"
#
compress_javascript() {
	echo "            compressing... $1"
	$UGLIFY_CMD $UGLIFY_PARAMS $1
}

#
# Organize django static files using symlinks
#
move_to_static_folder() {
	echo -e "${BCOLOR_WHITE}Django${COLOR_OFF} Link static files in django staticfiles folder... "
	activate_venv
	# -v 0 -> nonverbose
	# --clear -> remove old files
	# --link -> use symlinks instead of copies
	# --noinput -> dont prompt user, just do the stuff
	python manage.py collectstatic -v 0 --link --clear --noinput
	echo "done!"
	deactivate_venv
}

#
# Revert the repo to last deployed revision (in case something goes really bad :D)
# TODO Guess how to revert the database too -or im too lazy now to read the south docs-
#
revert() {
	# Revert to $PREV_REVISION
	void
}

#
# Restart supervisord
#
restart_app() {
	echo -e "${BCOLOR_WHITE}Restarting APP${COLOR_OFF}"
	echo -n -e "${COLOR_WHITE}-${COLOR_OFF} Removing *.pyc files... "
	find -name "*.pyc" -delete && echo "done!"
	echo -e "${COLOR_WHITE}-${COLOR_OFF} Restarting django APP $APP_NAME..."
	supervisorctl restart $APP_NAME
}

#
# Update database with south
#
migrate_database() {
	echo -e "${BCOLOR_WHITE}Django${COLOR_OFF} Migrating database"
	activate_venv
	echo -e "${COLOR_WHITE}-${COLOR_OFF} Performing syncdb"
	python manage.py syncdb
	echo -e "${COLOR_WHITE}-${COLOR_OFF} Performing south migrate"
	python manage.py migrate
	deactivate_venv
}

#
# Help echoes
#
halp() {
    echo "moar info"
	echo "halp goes here"
}

# Param control
echo "==============================="
case "$1" in
    deploy)
		echo -e "${BCOLOR_WHITE} === Deploy === ${COLOR_OFF}"
        deploy
        ;;
    revert)
		echo -e "${BCOLOR_WHITE}=== Revert === ${COLOR_OFF}"
		echo "NYI"
		exit 3
		;;
	compile)
		echo -e "${BCOLOR_WHITE}=== Compile === ${COLOR_OFF}"
		compile_static
		move_to_static_folder
		;;
	staticfiles)
		echo -e "${BCOLOR_WHITE}=== Move to static files === ${COLOR_OFF}"
		move_to_static_folder
		;;
	test)
		echo "test"
		;;
    *)
        echo "Usage: $SCRIPT_NAME {deploy|mindeploy|compile|staticfiles|revert|revertto}"
        echo "deploy: blah blah blah"
        echo "blah blah blah"
        halp
        exit 2
esac
