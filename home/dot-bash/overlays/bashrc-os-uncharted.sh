SCRIPT_DIR=$(dirname "$(readlink --canonicalize-existing "${0}" 2>/dev/null)")
readonly SCRIPT="${0##*/}"
readonly SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT}"
echo "${SCRIPT_PATH} - We're in uncharted territory"
