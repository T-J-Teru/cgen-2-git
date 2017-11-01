#!/bin/bash

#=====================================================================

function usage () {
    MSG=$1

    echo "${MSG}"
    echo
    echo "Usage: ./convert.sh --working-dir <working_dir>"
    echo "                    [--help]"

    exit 1
}

function error ()
{
    if [ -z "${LOGFILE}" ]
    then
        echo "!! $1"
    else
        echo "!! $1" | tee -a ${LOGFILE}
        echo ""
        echo "See ${LOGFILE} for more details"
    fi

    exit 1
}

function run_command ()
{
    echo "" >> ${LOGFILE}
    echo "Current directory: ${PWD}" >> ${LOGFILE}
    echo -n "Running: " >> ${LOGFILE}
    for P in "$@"
    do
        V=`echo ${P} | sed -e 's/"/\\\\"/g'`
        echo -n "\"${V}\" " >> ${LOGFILE}
    done
    echo "" >> ${LOGFILE}
    echo "" >> ${LOGFILE}

    "$@" >> ${LOGFILE} 2>&1
    return $?
}

function job_start ()
{
    JOB_TITLE=$1
    JOB_START_TIME=`date +%s`
    echo "Starting: ${JOB_TITLE}" >> ${LOGFILE}
    echo -n ${JOB_TITLE}"..."
}

function job_done ()
{
    if [ -z "${JOB_START_TIME}" ]; then
        echo "Attempt to end a job which has not been started"
        exit 1
    fi

    local JOB_END_TIME=`date +%s`
    local TIME_STR=`times_to_time_string ${JOB_START_TIME} ${JOB_END_TIME}`

    echo "Finished ${TIME_STR}." >> ${LOGFILE}
    echo -e "\r${JOB_TITLE} completed ${TIME_STR}."

    JOB_TITLE=""
    JOB_START_TIME=
}

function all_finished ()
{
    SCRIPT_END_TIME=`date +%s`
    TIME_STR=`times_to_time_string ${SCRIPT_START_TIME} ${SCRIPT_END_TIME}`

    echo "All finished ${TIME_STR}." | tee -a ${LOGFILE}
}

function times_to_time_string ()
{
    local START=$1
    local END=$2

    local TIME_TAKEN=$((END - START))
    local TIME_STR=""

    if [ ${TIME_TAKEN} -gt 0 ]
    then
	local MINS=$((TIME_TAKEN / 60))
	local SECS=$((TIME_TAKEN - (60 * MINS)))
	local MIN_STR=""
	local SEC_STR=""
	if [ ${MINS} -gt 1 ]
	then
	    MIN_STR=" ${MINS} minutes"
	elif [ ${MINS} -eq 1 ]
	then
	    MIN_STR=" ${MINS} minute"
	fi
	if [ ${SECS} -gt 1 ]
	then
	    SEC_STR=" ${SECS} seconds"
	elif [ ${SECS} -eq 1 ]
	then
	    SEC_STR=" ${SECS} second"
	fi

	TIME_STR="in${MIN_STR}${SEC_STR}"
    else
	TIME_STR="instantly"
    fi

    echo "${TIME_STR}"
}

#=====================================================================

SCRIPT_DIR=$(cd "`dirname \"$0\"`"; pwd)
LOGFILE=
WORKING_DIR=

#=====================================================================

# Parse options
until
opt=$1
case ${opt} in

    --working-dir)
        shift
        WORKING_DIR=$1
        ;;

    --help)
        usage
        ;;

    ?*)
        usage "Unknown argument $1"
        ;;

    *)
        ;;
esac
[ "x${opt}" = "x" ]
do
    shift
done

#=====================================================================

if [ -z "${WORKING_DIR}" ]
then
    usage "No working directory specified"
fi

mkdir -p ${WORKING_DIR} \
    || error "couldn't create directory '${WORKING_DIR}'"

cd ${WORKING_DIR} \
    || error "couldn't enter '${WORKING_DIR}'"
WORKING_DIR=$(pwd)

LOGDIR=${WORKING_DIR}/logs
mkdir -p ${LOGDIR} \
    || error "couldn't create log directory '${LOGDIR}'"

#=====================================================================

DATE_STRING=$(date +%F-%H%M)
LOGFILE=${LOGDIR}/conversion-${DATE_STRING}.log
CONVERSION_TAR_FILE=${WORKING_DIR}/conversion-mirror-${DATE_STRING}.tar.xz
CONVERSION_DIR=${WORKING_DIR}/conversion-${DATE_STRING}

#=====================================================================

job_start "rsyncing from sourceware.org"

if ! run_command rsync -avz \
                 --exclude-from=${SCRIPT_DIR}/rsync-exclude-list \
                 sourceware.org::src-cvs cgen-mirror
then
    error "failed to rsync cgen from sourceware.org"
fi

job_done

#=====================================================================

job_start "creating copy of mirror"

TEMP_DIR=`mktemp -d -p ${WORKING_DIR}`

if ! run_command cp -r cgen-mirror ${TEMP_DIR}
then
    error "failed to copy mirror to temporary directory"
fi

if ! run_command rm -fr ${TEMP_DIR}/cgen-mirror/Attic
then
    error "failed to restructure copy of cgen mirror - step 1"
fi

if ! run_command rm -fr ${TEMP_DIR}/cgen-mirror/CVS
then
    error "failed to restructure copy of cgen mirror - step 2"
fi

if ! run_command mv ${TEMP_DIR}/cgen-mirror/src/cgen ${TEMP_DIR}/cgen-mirror/
then
    error "failed to restructure copy of cgen mirror - step 3"
fi

if ! run_command rm -fr ${TEMP_DIR}/cgen-mirror/src
then
    error "failed to restructure copy of cgen mirror - step 4"
fi

if ! run_command rm -fr ${TEMP_DIR}/cgen-mirror/CVSROOT/modules
then
    error "failed to remove modules file from CVSROOT"
fi

if ! run_command sed -i -e 's/^LockDir=/# LockDir=/' ${TEMP_DIR}/cgen-mirror/CVSROOT/config
then
    error "failed to comment out LockDir from CVSROOT/config file"
fi

if ! run_command cd ${TEMP_DIR}
then
    echo "failed to enter ${TEMP_DIR}"
fi

if ! run_command tar -cJvf ${CONVERSION_TAR_FILE} cgen-mirror/
then
    error "failed to create tar file"
fi

if ! run_command cd ${WORKING_DIR}
then
    echo "failed to enter ${WORKING_DIR}"
fi

if ! run_command rm -fr ${TEMP_DIR}
then
    error "failed to clean up temporary directory '${TEMP_DIR}'"
fi

job_done

#=====================================================================

job_start "setting up reposurgeon directory"

if ! run_command mkdir ${CONVERSION_DIR}
then
    error "failed to create '${CONVERSION_DIR}"
fi

if ! run_command cd ${CONVERSION_DIR}
then
    error "failed to enter ${CONVERSION_DIR}"
fi

if ! run_command repotool initialize cgen cvs git
then
    error "failed to initialize reposurgeon directory"
fi

if ! run_command sed -i -e "s#repotool mirror \$(REMOTE_URL) cgen-mirror#tar -xf ${CONVERSION_TAR_FILE}#" Makefile
then
    error "failed to update Makefile for creating local mirror"
fi

if ! run_command make stubmap
then
    error "failed to generate stubmap file"
fi

if ! run_command sed -f ${SCRIPT_DIR}/fix-map-script -i cgen.map
then
    error "failed to update cgen.map file"
fi

if ! run_command sed -i -e 's# DOT #.#' -e 's# AT #@#' cgen.map
then
    error "failed to fixup email addresses in cgen.map"
fi

if ! run_command cp ${SCRIPT_DIR}/cgen.lift ${CONVERSION_DIR}/cgen.lift
then
    error "failed to copy cgen.lift file into place"
fi

job_done

#=====================================================================

cd ${CONVERSION_DIR}

job_start "converting cvs to git"

if ! run_command make
then
    error "failed convert cvs repository to git"
fi

job_done

job_start "generating dot file for repository"

if ! run_command reposurgeon "read<cgen.fi" "graph>cgen.dot"
then
    error "failed to generate cgen.dot file"
fi

job_done
