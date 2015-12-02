#!/bin/bash

# required vars: timeline_id timeline_suffix

parse_urls_from_php() {
extension=$1
working_folder=$2
code=$(cat <<EOF
<?php
\$url =
    "http://tools.voanews.com/utilities/timeline-editor/publish.php?" .
    "timeline=${timeline_id}&preview&format=bare${timeline_suffix}";

function get_assets(\$string, \$url, \$ext) {
    \$r = preg_match_all(
		"/http:\/\/tools.voanews.com\/utilities\/timeline-editor\/(.*?)\.{\$ext}/im",
		\$string,
		\$m
	);    
    return( array_unique(\$m[0]) );
}

\$destination_url = "${timeline_url}";
\$html = file_get_contents(\$url);
\$transformed_html = \$html;
\$all_files = array(
    array(
        "extension" => "jpg",
        "folder" => "img",
        "files" => get_assets(\$html, "${timeline_url}", "jpg")
    ),
    array(
        "extension" => "png",
        "folder" => "img",
        "files" => get_assets(\$html, "${timeline_url}", "png")
    ),
    array(
        "extension" => "gif",
        "folder" => "img",
        "files" => get_assets(\$html, "${timeline_url}", "gif")
    ),
    array(
        "extension" => "css",
        "folder" => "css", 
        "files" => get_assets(\$html, "${timeline_url}", "css")
    ),
    array(
        "extension" => "js",
        "folder" => "js",
        "files" => get_assets(\$html, "${timeline_url}", "js")
    )
);

\$files = get_assets(\$html, "${timeline_url}", "${extension}");

foreach( \$all_files as \$count_1 => \$data ) {
    foreach( \$data["files"] as \$count_2 => \$filename ) {
        \$new_name = sprintf(
            "%02d-%s",
            \$count_2, strtolower(basename(\$filename))
        );
        \$new_url = sprintf(
            "%s%s/%s",
            \$destination_url,
            \$data["folder"],
            \$new_name
        );
    
        if( "${extension}" == "original_document" ) {
            // html!
            \$transformed_html = str_replace( \$filename, \$new_url, \$transformed_html );
        } else {
            // files only, and only ones we want
            
            if( "${extension}" == \$data["extension"] ) {
                echo "{\$filename},{\$new_name}\n";
            }
        }
    }
}

if( "${extension}" == "original_document" ) {
    echo \$transformed_html;
}

EOF
)

echo -n "${code}" | /usr/bin/php

}

# test here
#source ".timeline-editor"
#timeline_id=$(get_timeline_id)
#timeline_suffix=$(get_timeline_suffix)
#parse_urls_from_php ${timeline_id} ${timeline_suffix}
#exit


# =======================================================
# given a list of urls,files it fetches assets and saves
# =======================================================
fetch_assets() {

	save_folder=$1
	shift 1
	to_download=$@

	for file in ${to_download};
	do
		
        # php sends us url,newfilename (new filename is serialized, transformed)
        url=`echo "${file}" | cut -f1 -d','`
		save_as=`echo "${file}" | cut -f2 -d','`

		wget -nv "${url}" -O "${save_folder}${save_as}"
	done
}

# =======================================================
# save transformed HTML
# =======================================================
fetch_html() {
    html=$(parse_urls_from_php "original_document")
    echo "${html}" > "index.php"
    du -sh "index.php"
    exit
}

# =======================================================
# makes sure img / css folders exist
# =======================================================
create_folder() {
    if [ ! -d "${1}" ]
    then
        mkdir "${1}"
        echo "Creating folder ${1}"
    else
        echo "Folder ${1} exists, skipping"
    fi
}

setup_folders() {
    folder=$1
    
    create_folder "${folder}/img"
    create_folder "${folder}/css"
    create_folder "${folder}/js"
}

# =======================================================
# this takes awhile, so separated as an option
# =======================================================
do_setup() {
    if [ ! -f ".timeline-editor" ]
    then
        folder=`pwd`

        if( whiptail \
            --title "Timeline-Editor setup" \
            --yesno \
"This project/folder is not setup for timeline-editor syncing. Are these the correct HTML / JS / CSS / IMG folders to initialize?

${folder}/
${folder}/js/
${folder}/css/
${folder}/img/

" \
            20 70
        ) then
            setup_folders ${folder}
            timeline_id=$(
                whiptail \
                    --title "timeline ID?" \
                    --inputbox "What's the timeline ID number? (ex:20789)" \
                    10 60 \
                    3>&1 1>&2 2>&3
                )

            if [ -z ${timeline_id} ]
            then
                printf "\nSorry, need a timeline ID number to set this up\n\n"
                exit
            fi

            timeline_suffix=$(
                whiptail \
                    --title "timeline url suffix?" \
                    --inputbox "Anything to add to preview URL? (ex &format=xml)" \
                    10 60 \
                    3>&1 1>&2 2>&3
                )
            
            timeline_url=$(
                whiptail \
                    --title "Live URL for project?" \
                    --inputbox "ex: http://projects.voanews.com/test/ (need trailing slash)" \
                    10 60 \
                    3>&1 1>&2 2>&3
                )
            
echo \
"# generated by sync.sh setup

get_timeline_id() {
    echo \"${timeline_id}\"
}

get_timeline_suffix() {
    echo \"${timeline_suffix}\"
}

get_timeline_url() {
    echo \"${timeline_url}\"
}

export -f get_timeline_id
export -f get_timeline_suffix
export -f get_timeline_url

" > ".timeline-editor"

            echo "------------------------------------------------"
            echo "Done setting up -- created .timeline-editor file"
            echo "------------------------------------------------"
            exit

        else
            printf "
Sorry, for this sync to work, we need the right HTML/CSS/IMG folders
in this structure:

[current folder]        - html index
     |
     +------- /img/     - rewritten images (tools -> new home)
     |
     +------- /css/     - rewritten CSS files (tools -> new home)
     
"
        fi
    else
        printf "\nThere's already a .timeline-editor file in this folder.\n"
        printf "If you'd like to redo the setup process, remove the file\n\n"
    fi
}

# =======================================================
# this takes awhile, so separated as an option
# =======================================================
batch_img() {

    #                           ext   working folder
    urls=$(parse_urls_from_php "jpg" "img")
	fetch_assets "${folder}/img/" ${urls}

    urls=$(parse_urls_from_php "png" "img")
	fetch_assets "${folder}/img/" ${urls}

    urls=$(parse_urls_from_php "gif" "img")
	fetch_assets "${folder}/img/" ${urls}
}

# =======================================================
# sometimes only a css file is altered
# =======================================================
batch_css() {
    urls=$(parse_urls_from_php "css" "css")
	fetch_assets "${folder}/css/" ${urls}
}

# =======================================================
# hopefully JS files are parked somewhere else
# =======================================================
batch_js() {
    urls=$(parse_urls_from_php "js" "js")
	fetch_assets "${folder}/js/" ${urls}
}

# =======================================================
# for the lazy
# =======================================================
batch_all() {
	batch_img
	batch_css
    batch_js
	fetch_html
}

# =======================================================
# first, are we setup?  if so, get the timeline id #
# =======================================================
check_config_file() {

    if [ ! -f ".timeline-editor" ]
    then
        printf "\nERROR: .timeline-editor file is missing.\n"
        printf "Try running ${0} setup\n\n";
        exit
    fi

}

# =======================================================
# issue a specific command to make anything happen
# =======================================================
if [ "${1}" == "setup" ]
then
    do_setup
    exit
fi

check_config_file
source ".timeline-editor"
timeline_id=$(get_timeline_id)
timeline_suffix=$(get_timeline_suffix)
timeline_url=$(get_timeline_url)
folder=`pwd`

#echo "timeline-editor id is \"${timeline_id}\""
# echo "timeline-editor suffix is \"${timeline_suffix}\""

case "${1}" in
	"all")
		batch_all
		;;
	"img")
		batch_img
		;;
	"css")
		batch_css
		;;
	"js")
		batch_js
		;;
	"html")
		fetch_html
		;;
	*)
		echo "";
		echo "ERROR: need a target; ex:";
		echo "";
		echo "${0} setup   (configure a new project, from its working folder)"
		echo "${0} all     (do everything below)"
		echo "${0} img     (fetch only images)"
		echo "${0} css     (fetch only css files)"
		echo "${0} js      (fetch only js files)"
		echo "${0} html    (fetch only html files)"
		echo ""

		;;
esac


