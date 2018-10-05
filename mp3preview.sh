#!/bin/bash

# Best settings like in mixcloud.com
SETT_PART_COUNT=5
SETT_PART_DURATION=5
SETT_CROSSFADE=1
SETT_FORMAT="mp3"

# Get system utilites with full path
UTIL_FFMPEG=`whereis ffmpeg | awk {'print $2'}`
UTIL_CUT=`whereis cut | awk {'print $2'}`
UTIL_ECHO=`whereis echo | awk {'print $2'}`
UTIL_EXPR=`whereis expr | awk {'print $2'}`
UTIL_RM=`whereis rm | awk {'print $2'}`
UTIL_MV=`whereis mv | awk {'print $2'}`

# Get current process ID
UNIQ_STR="$$"

# Input and output files
INPUT_FILE="$1"
OUTPUT_FILE="$2"

# Temp dir, RAM disk is the best place
TEMP_DIR="$3"

# Set default temp dir if not set
if [ "$TEMP_DIR" != "" ]; then
	TEMP_DIR=${3%/}
	
else
	TEMP_DIR="/tmp"
fi

# Check if temp dir is exists
if [ ! -d "$TEMP_DIR" ]; then
	$UTIL_ECHO " ✗ Temporary directory ($TEMP_DIR) is not available"
	exit 1
fi

# Checks, if all system utilites are present
if [ "$UTIL_FFMPEG" = "" ] || [ "$UTIL_CUT" = "" ] || [ "$UTIL_ECHO" = "" ] || [ "$UTIL_EXPR" = "" ] || [ "$UTIL_RM" = "" ] || [ "$UTIL_MV" = "" ]; then
	$UTIL_ECHO " ✗ Some utility, what needed for work is not present in system"
	exit 1
fi

# Check if input file is set
if [ "$INPUT_FILE" = "" ]; then
	$UTIL_ECHO " ✗ Please set source file name"
	exit 1
fi

# Check if output file is set
if [ "$OUTPUT_FILE" = "" ]; then
	$UTIL_ECHO " ✗ Please set output file name"
	exit 1
fi

# Check if input file is exist
if [ ! -f "$INPUT_FILE" ]; then
	$UTIL_ECHO " ✗ Source file is not exist"
	exit 1
fi

# Perfomance check
PROC_START=`date +%s`

# Extract file length
INPUT_LEN_STR=`$UTIL_FFMPEG -i $INPUT_FILE 2>&1 | awk '/Duration/ { print substr($2,0,length($2)-1) }' | $UTIL_CUT -d. -f1`
if [ "$INPUT_LEN_STR" = "" ]; then
	$UTIL_ECHO " ✗ Can't get file duration"
	exit 1
fi

# Convert length to integer
INPUT_LEN_HOURS=`$UTIL_ECHO $INPUT_LEN_STR | $UTIL_CUT -d: -f1`
INPUT_LEN_MINUTES=`$UTIL_ECHO $INPUT_LEN_STR | $UTIL_CUT -d: -f2`
INPUT_LEN_SECONDS=`$UTIL_ECHO $INPUT_LEN_STR | $UTIL_CUT -d: -f3`
INPUT_LEN_HOURS=`$UTIL_EXPR $INPUT_LEN_HOURS + 0`
INPUT_LEN_MINUTES=`$UTIL_EXPR $INPUT_LEN_MINUTES + 0`
INPUT_LEN_SECONDS=`$UTIL_EXPR $INPUT_LEN_SECONDS + 0`

# Convert length to seconds
INPUT_LENGTH=$((INPUT_LEN_HOURS * 60 * 60))
INPUT_LENGTH=$((INPUT_LENGTH + INPUT_LEN_MINUTES * 60))
INPUT_LENGTH=$((INPUT_LENGTH + INPUT_LEN_SECONDS))

# Some temp vars
TMP_STEP=$((INPUT_LENGTH / SETT_PART_COUNT))

# Check for minimum length
INPUT_LEN_MINIMUM=$((SETT_PART_COUNT * SETT_PART_DURATION + SETT_CROSSFADE * SETT_PART_DURATION))
if (( INPUT_LENGTH < INPUT_LEN_MINIMUM )); then
	$UTIL_ECHO " ✗ File length is too small"
	exit 1
fi

# Some temp vars
TMP_LEN=$((SETT_PART_DURATION + SETT_CROSSFADE))
TMP_CMD_FILES=""
TMP_CMD_FILTERS=""
TMP_CMD_CROSSFADE=""
TMP_CMD_LAST=""

# Split file to parts and generate filters
for ((i = 1; i <= SETT_PART_COUNT; i++)); do
	TMP_S=$((i * TMP_STEP - TMP_STEP))
	TMP_E=$((i * TMP_STEP - TMP_STEP))
	TMP_E=$((TMP_E + SETT_PART_DURATION + SETT_CROSSFADE))
	TMP_CMD="$UTIL_FFMPEG -i $INPUT_FILE -ss $TMP_S -to $TMP_E -c copy -y $TEMP_DIR/$UNIQ_STR_$i.$SETT_FORMAT"
	TMP_OUTPUT=`$TMP_CMD 2>&1`
	k=$((i - 1))
	TMP_CMD_FILES="$TMP_CMD_FILES -i $TEMP_DIR/$UNIQ_STR_$i.$SETT_FORMAT"
	TMP_CMD_FILTERS="$TMP_CMD_FILTERS[$k]atrim=0:$TMP_LEN[a$i];"
	if (( i >= 2 )); then
		if (( i == 2 )); then
			TMP_CMD_CROSSFADE="$TMP_CMD_CROSSFADE[a$k][a$i]acrossfade=d=$SETT_CROSSFADE[r$k];"
			TMP_CMD_LAST="r$k"
		else
			r=$((k - 1))
			if (( i >= SETT_PART_COUNT )); then
				TMP_CMD_CROSSFADE="$TMP_CMD_CROSSFADE[r$r][a$i]acrossfade=d=$SETT_CROSSFADE[r$k]"
			else
				TMP_CMD_CROSSFADE="$TMP_CMD_CROSSFADE[r$r][a$i]acrossfade=d=$SETT_CROSSFADE[r$k];"
			fi
			TMP_CMD_LAST="r$k"
		fi
	fi
done
$UTIL_ECHO " ✓ Particles created ($SETT_PART_COUNT)"

# Connect all parts with crosfade effect
TMP_OUTPUT=`$UTIL_FFMPEG $TMP_CMD_FILES -filter_complex "$TMP_CMD_FILTERS$TMP_CMD_CROSSFADE" -map [$TMP_CMD_LAST] -y $OUTPUT_FILE 2>&1`
$UTIL_ECHO " ✓ Particles connected together"

# Make fade-in at start and fade-out at the end
TMP_OUTPUT=`$UTIL_FFMPEG -i $OUTPUT_FILE -af 'afade=t=in:ss=0:d=0.8,afade=t=out:st=25:d=0.8' -y tmp.$OUTPUT_FILE 2>&1`
$UTIL_RM $OUTPUT_FILE
$UTIL_MV tmp.$OUTPUT_FILE $OUTPUT_FILE
$UTIL_ECHO " ✓ FadeIn/FadeOut created"

# Delete temp parts
for ((i = 1; i <= SETT_PART_COUNT; i++)); do
	$UTIL_RM $TEMP_DIR/$UNIQ_STR_$i.$SETT_FORMAT
done

# Perfomance check
PROC_END=`date +%s`
PROC_ALL=$((PROC_END - PROC_START))
$UTIL_ECHO " ✓ Particle files deleted"

# Done
$UTIL_ECHO " ✓ Done in $PROC_ALL second(s)"
exit 0
