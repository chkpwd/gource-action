#!/bin/bash

# Loading animation
function spinner() {
  local pid=$!
  local spin='⣾⣽⣻⢿⡿⣟⣯⣷'

  local i=0
  local t="\t\t\t\t\t\t\t\t\t\t\t\t\t"

  while kill -0 $pid 2>/dev/null
  do
    i=$(( (i+1) %${#spin} ))
    printf "\r$t${spin:$i:1}\t"
    sleep .15
  done

  printf "\r$t✔\n"
}

ls -al

# Start Xvfb
printf "> Starting Xvfb "
Xvfb :99 -ac -screen 0 $XVFB_WHD -nolisten tcp &> ./logs/Xvfb.log & spinner &
xvfb_pid="$!"

# possible race condition waiting for Xvfb.
sleep 5
printf "\r\t\t\t\t\t\t\t\t\t\t\t\t\t✔\n"

# clean up .gitkeep files
rm /gource/avatars/.gitkeep
rm /gource/git_repo/.gitkeep
rm /gource/git_repos/.gitkeep

# Check if git repo exist, else download it from GIT_URL
printf "\n>\n> Repository check \n"
if [ -z "$(ls -A /gource/git_repos)" ]; then
    printf "> \tUsing single repo \n"

	# Check if git repo needs to be cloned
    if [ -z "$(ls -A /gource/git_repo)" ]; then
	    # Check if git repo need token
        if [ "${GIT_TOKEN}" == "" ]; then
            printf "> \tCloning from public: ${GIT_URL}"
            timeout 25s git clone ${GIT_URL} /gource/git_repo >/dev/null 2>&1 & spinner
        else
            printf "> \tCloning from private: ${GIT_URL}"
            # Add git token to access private repository
            timeout 25s git clone $(sed "s/git/${GIT_TOKEN}\@&/g" <<< ${GIT_URL}) /gource/git_repo >/dev/null 2>&1 & spinner
        fi
	fi


    if [ -z "$(ls -A /gource/git_repo)" ]; then
        # // TODO: Add multi repo support
        printf "\nERROR: No Git repository found"
        exit 2
    fi

	printf "> \tUsing volume mounted git repo"
	gource --output-custom-log /gource/development.log /gource/git_repo >/dev/null 2>&1 & spinner
else
    # // TODO: Add multi repo support
	printf "\nERROR: Currently multiple repos are not supported"
    exit 1
fi


# Set proper env variables if we have a logo.
printf ">\n> Logo check \n"
if [ "${LOGO_URL}" != "" ]; then
    printf "> \tDownloading logo"
	wget -O /gource/logo.image ${LOGO_URL} >/dev/null 2>&1 & spinner
    convert -geometry x160 /gource/logo.image /gource/logo.image

    printf "> \tUsing logo from: ${LOGO_URL} \n"
    export LOGO=" -i /gource/logo.image "
    export LOGO_FILTER_GRAPH=";[with_date][2:v]overlay=main_w-overlay_w-40:main_h-overlay_h-40[with_logo]"
    export FILTER_GRAPH_MAP=" -map [with_logo] "
else
    printf "> \tNo logo provided, skipping logo setup\n"
    export FILTER_GRAPH_MAP=" -map [with_date] "
fi

# Run the visualization
printf ">\n> Starting gource script\n"
/usr/local/bin/gource.sh
printf "> Gource script completed"

# Copy logs and output file to mounted directory
printf "\n>\n> Copy data into mounted directory \n"
printf "> \tCopy generated mp4"
cp /gource/output/gource.mp4 /github/workspace/gource.mp4 & spinner
printf "> \tCopy log files"
cp -r /gource/logs/ /github/workspace/ & spinner

# Exit
printf ">\n> Done.\n>"
exit 0
