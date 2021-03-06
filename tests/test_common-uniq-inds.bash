#!/usr/bin/env bash

# Aim: launch a functional test for eqtlbma_bf when some individuals 
#      are unique to each subgroup
# Author: Timothée Flutre
# Not copyrighted -- provided to the public domain

progVersion="1.0"

#------------------------------------------------------------------------------

# Display the help on stdout.
# The format complies with help2man (http://www.gnu.org/s/help2man)
function help () {
    msg="\`${0##*/}' launches a functional test for eqtlbma_bf when some individuals are unique to each subgroup.\n"
    msg+="\n"
    msg+="Usage: ${0##*/} [OPTIONS] ...\n"
    msg+="\n"
    msg+="Options:\n"
    msg+="  -h, --help\tdisplay the help and exit\n"
    msg+="  -V, --version\toutput version information and exit\n"
    msg+="  -v, --verbose\tverbosity level (0/default=1/2/3)\n"
    msg+="  -e, --p2e\tabsolute path to the 'eqtlbma_bf' binary\n"
    msg+="  -R, --p2R\tabsolute path to the 'functional_tests.R' script\n"
    msg+="  -n, --noclean\tkeep temporary directory with all files\n"
    msg+="\n"
    msg+="Report bugs to <eqtlbma-users@googlegroups.com>."
    echo -e "$msg"
}

# Display version and license information on stdout.
function version () {
    msg="${0##*/} ${progVersion}\n"
    msg+="\n"
    msg+="Written by Timothée Flutre.\n"
    msg+="\n"
    msg+="Not copyrighted -- provided to the public domain\n"
    echo -e "$msg"
}

# http://www.linuxjournal.com/content/use-date-command-measure-elapsed-time
function timer () {
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s')
    else
        local startRawTime=$1
        endRawTime=$(date '+%s')
        if [[ -z "$startRawTime" ]]; then startRawTime=$endRawTime; fi
        elapsed=$((endRawTime - startRawTime)) # in sec
        nbDays=$((elapsed / 86400))
        nbHours=$(((elapsed / 3600) % 24))
        nbMins=$(((elapsed / 60) % 60))
        nbSecs=$((elapsed % 60))
        printf "%01dd %01dh %01dm %01ds" $nbDays $nbHours $nbMins $nbSecs
    fi
}

# Parse the command-line arguments.
# http://stackoverflow.com/a/4300224/597069
function parseCmdLine () {
    getopt -T > /dev/null # portability check (say, Linux or Mac OS?)
    if [ $? -eq 4 ]; then # GNU enhanced getopt is available
	TEMP=`getopt -o hVv:e:R:n -l help,version,verbose:,p2e:,p2R:,noclean \
        -n "$0" -- "$@"`
    else # original getopt is available (no long options, whitespace, sorting)
	TEMP=`getopt hVv:e:R:n "$@"`
    fi
    if [ $? -ne 0 ]; then
	echo "ERROR: "$(which getopt)" failed"
	getopt -T > /dev/null
	if [ $? -ne 4 ]; then
	    echo "did you use long options? they are not handled \
on your system, use -h for help"
	fi
	exit 2
    fi
    eval set -- "$TEMP"
    while [ $# -gt 0 ]; do
        case "$1" in
            -h | --help) help; exit 0; shift;;
            -V | --version) version; exit 0; shift;;
            -v | --verbose) verbose=$2; shift 2;;
            -e | --p2e) pathToBf=$2; shift 2;;
	    -R | --p2R) pathToRscript=$2; shift 2;;
	    -n | --noclean) clean=false; shift;;
            --) shift; break;;
            *) echo "ERROR: options parsing failed, use -h for help"; exit 1;;
        esac
    done
    if [ ! -f "${pathToBf}" ]; then
	echo -e "ERROR: can't find path to 'eqtlbma_bf' -> '${pathToBf}'\n" 1>&2
	help
	exit 1
    fi
    if [ ! -f "${pathToRscript}" ]; then
	echo -e "ERROR: can't find path to 'functional_tests.R' -> '${pathToRscript}'\n" 1>&2
	help
	exit 1
    fi
}

#------------------------------------------------------------------------------

function simul_data_and_calc_exp_res () {
    if [ $verbose -gt "0" ]; then
	echo "simulate data and calculate expected results ..."
    fi
    ${pathToRscript} --verbose 1 --dir $(pwd) --ris --mvlr >& stdout_simul_exp
}

function calc_obs_res () {
    if [ $verbose -gt "0" ]; then
	echo "analyze data to get observed results ..."
    fi
    $pathToBf --geno list_genotypes.txt --scoord snp_coords.bed.gz \
	--exp list_phenotypes.txt --gcoord gene_coords.bed.gz --cis 5 \
	--out obs_bf --outss --outw --analys join --bfs all \
	--gridL grid_phi2_oma2_general.txt.gz \
	--gridS grid_phi2_oma2_with-configs.txt.gz \
	--error hybrid --fiterr 0.0 \
	-v 1 >& stdout_bf
}

function comp_obs_vs_exp () {
    if [ $verbose -gt "0" ]; then
	echo "compare obs vs exp results ..."
    fi
    
    for i in {1..3}; do
    # nbDiffs=$(diff <(zcat obs_bf_sumstats_s${i}.txt.gz) <(zcat exp_bf_sumstats_s${i}.txt.gz) | wc -l)
	# if [ ! $nbDiffs -eq 0 ]; then
	gunzip obs_bf_sumstats_s${i}.txt.gz
	gunzip exp_bf_sumstats_s${i}.txt.gz
	if ! cmp -s obs_bf_sumstats_s${i}.txt exp_bf_sumstats_s${i}.txt; then
	    echo "file 'obs_bf_sumstats_s${i}.txt' has differences with exp"
	    exit 1
	fi
	gzip obs_bf_sumstats_s${i}.txt
	gzip exp_bf_sumstats_s${i}.txt
    done

    gunzip obs_bf_l10abfs_raw.txt.gz
    gunzip exp_bf_l10abfs_raw.txt.gz
    if ! cmp -s obs_bf_l10abfs_raw.txt exp_bf_l10abfs_raw.txt; then
    	echo "file 'obs_bf_l10abfs_raw.txt' has differences with exp"
  	    exit 1
    fi
    gzip obs_bf_l10abfs_raw.txt
    gzip exp_bf_l10abfs_raw.txt

    gunzip obs_bf_l10abfs_avg-grids.txt.gz
    gunzip exp_bf_l10abfs_avg-grids.txt.gz
    if ! cmp -s obs_bf_l10abfs_avg-grids.txt exp_bf_l10abfs_avg-grids.txt; then
    	echo "file 'obs_bf_l10abfs_avg-grids.txt' has differences with exp"
		exit 1
    fi
    gzip obs_bf_l10abfs_avg-grids.txt
    gzip exp_bf_l10abfs_avg-grids.txt
    
    if [ $verbose -gt "0" ]; then
	echo "all tests passed successfully!"
    fi
}

#------------------------------------------------------------------------------

verbose=1
pathToBf=$bf_abspath
pathToRscript=$Rscript_abspath
clean=true
parseCmdLine "$@"

if [ $verbose -gt "0" ]; then
    startTime=$(timer)
    msg="START ${0##*/} $(date +"%Y-%m-%d") $(date +"%H:%M:%S")"
    msg+="\ncmd-line: $0 "$@
    echo -e $msg
fi

cwd=$(pwd)

uniqId=$$ # process ID
testDir=tmp_test_${uniqId}
rm -rf ${testDir}
mkdir ${testDir}
cd ${testDir}
if [ $verbose -gt "0" ]; then echo "temp dir: "$(pwd); fi

simul_data_and_calc_exp_res

calc_obs_res

comp_obs_vs_exp

cd ${cwd}
if $clean; then rm -rf ${testDir}; fi

if [ $verbose -gt "0" ]; then
    msg="END ${0##*/} $(date +"%Y-%m-%d") $(date +"%H:%M:%S")"
    msg+=" ($(timer startTime))"
    echo $msg
fi
