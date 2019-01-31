#!/bin/bash

#=====================================================================

function usage () {
    MSG=$1

    echo "${MSG}"
    echo
    echo "Usage: ./convert.sh --working-dir <working_dir>"
    echo "                    [--help]"
    echo "                    [--validate]"
    echo "                    [--no-rsync]"

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
DO_VALIDATION=no
DO_RSYNC=yes

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

    --validate)
        DO_VALIDATION=yes
        ;;

    --no-rsync)
        DO_RSYNC=no
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

# Check that some required tools are available, otherwise bail out
# early.

for tool in cvs-fast-export repotool
do
    if ! which $tool 2>/dev/null >/dev/null
    then
        error "couldn't find '$tool' in \$PATH"
    fi
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
GIT_DIR=${CONVERSION_DIR}/cgen-git

#=====================================================================

if [ x${DO_RSYNC} == "xyes" ]
then
    job_start "rsyncing from sourceware.org"

    if ! run_command rsync -avz \
         --exclude-from=${SCRIPT_DIR}/rsync-exclude-list \
         sourceware.org::src-cvs cgen-mirror
    then
        error "failed to rsync cgen from sourceware.org"
    fi

    job_done
fi

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

#=====================================================================

# Reposurgeon seems to add a .gitignore file into the repository.  Not
# entirely sure of the reasoning behind this, but removing it seems to still
# leave the repository in a good state, so lets do that.

job_start "remove .gitignore file"

pushd ${GIT_DIR} &>/dev/null

run_command git filter-branch --force --index-filter \
            "git rm --cached --ignore-unmatch $(find . -name .gitignore|xargs )"  \
            --prune-empty --tag-name-filter cat -- --all

popd &>/dev/null

job_done

#=====================================================================
#               Optional Stage: Validation

if [ x$DO_VALIDATION == xyes ]
then
    # In theory reposurgeon has support for checking branches and
    # tags, however, in my experience, this doesn't seem to work.  For
    # now I'm writing my own validation.

    job_start "tag validation"

    # A list of all the tags we plan to validate.
    VALIDATION_LIST=${CONVERSION_DIR}/version.list

    (cd ${GIT_DIR} && git checkout master) &>/dev/null
    (cd ${GIT_DIR} && git tag -l > ${VALIDATION_LIST}) &>/dev/null
    (cd ${GIT_DIR} && git branch -a --format="%(refname:short)" >> ${VALIDATION_LIST}) &>/dev/null

    # Remove a tag that we added to git during the conversion.
    sed -i -e '/^cgen-1-1$/d' ${VALIDATION_LIST}

    # A second log file to hold a more detailed view of the validation.
    VALIDATION_LOG=${CONVERSION_DIR}/tag-comparison
    echo "" > ${VALIDATION_LOG}

    ORIG_LOGFILE=${LOGFILE}
    LOGFILE=${VALIDATION_LOG}

    COMPARE_OK=yes

    for VER in `cat ${VALIDATION_LIST}`
    do
        # Record the tags in both log files.
        echo "Tag: ${VER}" >> ${VALIDATION_LOG}
        echo -n -e "Tag: ${VER}\t" >> ${ORIG_LOGFILE}

        # Checkout the branch or tag in git.
        pushd ${GIT_DIR} &>/dev/null
        run_command git checkout ${VER}
        popd &>/dev/null

        CVS_REVISION=""
        if [ "${VER}" != "master" ]
        then
            CVS_REVISION="-r ${VER}"
        fi

        CVS_CO_DIR=${CONVERSION_DIR}/cvs-checkout

        # Now checkout the same branch or tag from cvs.
        run_command cvs -Q -d:local:${CONVERSION_DIR}/cgen-mirror co \
                    -P -d ${CVS_CO_DIR} ${CVS_REVISION} \
                    -kb cgen

        # Now perform the comparison, ignoring some obvious things.
        run_command diff --exclude=CVS --exclude=.git \
                         -r ${GIT_DIR} ${CVS_CO_DIR}

        if [ $? == 0 ]
        then
            echo "OK" >> ${ORIG_LOGFILE}
        else
            echo "FAILED" >> ${ORIG_LOGFILE}
            COMPARE_OK=no
        fi

        # Delete the cvs checkout completely.
        run_command rm -fr ${CVS_CO_DIR}
    done

    LOGFILE=${ORIG_LOGFILE}

    if [ x${COMPARE_OK} != xyes ]
    then
        error "tag comparison failed"
    fi

    job_done
fi
