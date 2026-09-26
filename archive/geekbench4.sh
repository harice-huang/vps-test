#!/bin/bash
# by https://github.com/spiritLHLS/ecs
# by spiritlhls
# 2023.01.17
MY_GEEKBENCH_DOWNLOAD_URL="https://cdn.geekbench.com/Geekbench-4.4.4-Linux.tar.gz"
MY_DIR="$HOME/gb4"
MY_GITHUB_API_TOKEN=""
MY_GITHUB_API_JSON="$MY_DIR/github-gist.json"
MY_GITHUB_API_LOG="$MY_DIR/github-gist.log"
MY_OUTPUT="$MY_DIR/output.html"
MY_GEEKBENCH_EMAIL=""
MY_GEEKBENCH_KEY=""
RUN_TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/geekbench4.XXXXXX") || exit 1
ARCHIVE_FILE="$RUN_TMP_DIR/geekbench.tar.gz"
EXTRACT_DIR="$RUN_TMP_DIR/extracted"
cleanup_temp_dir() { rm -rf -- "$RUN_TMP_DIR"; }
trap cleanup_temp_dir EXIT
#####################################################################
#### END Configuration Section
#####################################################################

ME=$(basename "$0")
MY_DATE_TIME=$(date -u "+%Y-%m-%d %H:%M:%S")
MY_DATE_TIME+=" UTC"
MY_TIMESTAMP_START=$(date "+%s")
MY_GEEKBENCH_NO_UPLOAD=""

#####################################################################
# Terminal output helpers
#####################################################################

function usage {
	returnCode="$1"
	echo
	echo -e "Usage: 
	$ME [-e <EMAIL>] [-k <KEY>] [-n] [-h]"
	echo -e "Options:
	[-e <EMAIL>]\\t unlock Geekbench using EMAIL and KEY (default: $MY_GEEKBENCH_EMAIL)
	[-k <KEY>]\\t unlock Geekbench using EMAIL and KEY (default: $MY_GEEKBENCH_KEY)
	[-n]\\t\\t do not upload results to the Geekbench Browser (only if unlocked)
	[-g <TOKEN>]\\t GitHub API personal access token, create new gist with results (default: $MY_GEEKBENCH_KEY)
	[-h]\\t\\t displays help (this message)"
	echo
	exit "$returnCode"
}

#####################################################################
# MAIN
#####################################################################

# echo_equals() outputs a line with =
function echo_equals() {
	COUNTER=0
	while [ $COUNTER -lt "$1" ]; do
		printf '='
		((COUNTER = COUNTER + 1))
	done
}

# echo_line() outputs a line with 70 =
function echo_line() {
	echo_equals "90"
	echo
}

# exit_with_failure() outputs a message before exiting the script.
function exit_with_failure() {
	echo
	echo "FAILURE: $1"
	echo
	exit 9
}

# echo_title() outputs a title to stdout and MY_OUTPUT
function echo_title() {
	echo "> $1"
	echo "<h1>$1</h1>" >>"$MY_OUTPUT"
}

# echo_step() outputs a step to stdout and MY_OUTPUT
function echo_step() {
	echo "    > $1"
	echo "<h2>$1</h2>" >>"$MY_OUTPUT"
}

# echo_sub_step() outputs a step to stdout and MY_OUTPUT
function echo_sub_step() {
	echo "      > $1"
	echo "<h3>$1</h3>" >>"$MY_OUTPUT"
}

if [[ -L "$MY_DIR" ]]; then
	exit 9
elif [[ ! -d "$MY_DIR" ]]; then
	mkdir "$MY_DIR" || exit_with_failure "Could not create folder '$MY_DIR'"
fi
UNSAFE_TARGET=$(find "$MY_DIR" \( -type l -o \( -type f -links +1 \) \) -print -quit 2>/dev/null) || exit 9
[[ -n "$UNSAFE_TARGET" ]] && exit 9
unset UNSAFE_TARGET
rm -f -- "$MY_OUTPUT"

echo_line

while getopts "ne:k:g:h" opt; do
	case $opt in
	n)
		MY_GEEKBENCH_NO_UPLOAD="1"
		;;
	e)
		MY_GEEKBENCH_EMAIL="$OPTARG"
		;;
	k)
		MY_GEEKBENCH_KEY="$OPTARG"
		;;
	*)
		usage 1
		;;
	esac
done

# Download Geekbench 4
echo "    > Download Geekbench 4"
if curl --fail --location --proto '=https' --proto-redir '=https' "$MY_GEEKBENCH_DOWNLOAD_URL" -o "$ARCHIVE_FILE" 2>/dev/null; then
	mkdir "$EXTRACT_DIR" || exit_with_failure "Could not unpack geekbench.tar.gz"
	if ! tar tzf "$ARCHIVE_FILE" | grep -Eq '(^|/)\.\.(/|$)|^/' &&
		! tar tvzf "$ARCHIVE_FILE" 2>/dev/null | grep -Eq '^[^d-]' &&
		tar xvfz "$ARCHIVE_FILE" -C "$EXTRACT_DIR" --strip-components=1 >/dev/null 2>&1 &&
		cp -a "$EXTRACT_DIR"/. "$MY_DIR"/; then
		if [[ -f "$MY_DIR/geekbench4" && ! -L "$MY_DIR/geekbench4" && -x "$MY_DIR/geekbench4" ]]; then
			echo "        > Geekbench successfully downloaded"
		else
			exit_with_failure "Could not find '$MY_DIR/geekbench4'"
		fi
	else
		exit_with_failure "Could not unpack geekbench.tar.gz"
	fi
else
	exit_with_failure "Could not download Geekbench '$MY_GEEKBENCH_DOWNLOAD_URL'"
fi

# Unlock Geekbench 4
if [[ $MY_GEEKBENCH_EMAIL && $MY_GEEKBENCH_KEY ]]; then
	if "$MY_DIR/geekbench4" --unlock "$MY_GEEKBENCH_EMAIL" "$MY_GEEKBENCH_KEY" >/dev/null 2>&1; then
		echo "        > Geekbench successfully unlocked"
	else
		exit_with_failure "Could not unlock Geekbench"
	fi
else
	echo "        > Geekbench is in tryout mode"
fi

#####################################################################
# Run Geekbench 4
#####################################################################
clear
echo_line
echo "Now let's run Geekbench 4. This takes a little longer."
echo_line

echo_title "Geekbench 4"
if [[ $MY_GEEKBENCH_NO_UPLOAD ]]; then
	"$MY_DIR/geekbench4" --no-upload >>"$MY_OUTPUT" 2>&1 || exit_with_failure "Could not run Geekbench"
else
	"$MY_DIR/geekbench4" --upload >>"$MY_OUTPUT" 2>&1 || exit_with_failure "Could not run Geekbench"
fi
# cat "$MY_OUTPUT"
GEEKBENCH_URL=$(grep -o 'https://browser.geekbench.com/v4/cpu/[0-9]\+' "$MY_OUTPUT" | head -n1)
if [[ -z $MY_GEEKBENCH_NO_UPLOAD && -z $GEEKBENCH_URL ]]; then
	exit_with_failure "Could not find Geekbench result URL"
fi
GEEKBENCH_PAGE=""
if [[ -n $GEEKBENCH_URL ]]; then
	GEEKBENCH_PAGE=$(curl --fail --silent --location --max-time 15 --max-filesize 1048576 --proto '=https' --proto-redir '=https' "$GEEKBENCH_URL" 2>/dev/null) || GEEKBENCH_PAGE=""
fi
GEEKBENCH_SCORES=$(printf '%s' "$GEEKBENCH_PAGE" | grep "div class='score'") ||
	GEEKBENCH_SCORES=$(printf '%s' "$GEEKBENCH_PAGE" | grep "span class='score'")
GEEKBENCH_SCORES_SINGLE=$(printf '%s\n' "$GEEKBENCH_SCORES" | awk -v FS="(>|<)" '{ print $3 }')
GEEKBENCH_SCORES_MULTI=$(printf '%s\n' "$GEEKBENCH_SCORES" | awk -v FS="(>|<)" '{ print $7 }')
[[ "$GEEKBENCH_SCORES_SINGLE" =~ ^[0-9]+$ ]] || GEEKBENCH_SCORES_SINGLE=""
[[ "$GEEKBENCH_SCORES_MULTI" =~ ^[0-9]+$ ]] || GEEKBENCH_SCORES_MULTI=""
echo -en "\r\033[0K"
echo -e "Geekbench $VERSION Benchmark Test:"
printf "%-15s | %-30s\n" "Test" "Value"
printf "%-15s | %-30s\n"
printf "%-15s | %-30s\n" "Single Core" "$GEEKBENCH_SCORES_SINGLE"
printf "%-15s | %-30s\n" "Multi Core" "$GEEKBENCH_SCORES_MULTI"
printf "%-15s | %-30s\n" "Full Test" "$GEEKBENCH_URL"
rm -f -- "$MY_OUTPUT" "$ARCHIVE_FILE"
echo_line
