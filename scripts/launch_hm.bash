#!/usr/bin/env bash

# Aim: launch the hierarchical model from output files of eqtlbma
# Author: Timothee Flutre
# Not copyrighted -- provided to the public domain

function help () {
    msg="\`${0##*/}' launches the hierarchical model from output files of eqtlbma.\n"
    msg+="\n"
    msg+="Usage: ${0##*/} [OPTIONS] ...\n"
    msg+="\n"
    msg+="Options:\n"
    msg+="  -h, --help\tdisplay the help and exit\n"
    msg+="  -V, --version\toutput version information and exit\n"
    msg+="  -v, --verbose\tverbosity level (0/default=1/2/3)\n"
    msg+="      --p2b\tpath to the binary 'hm'\n"
    msg+="      --inp\tgzipped files as a glob pattern (usually from 'eqtlbma')\n"
    msg+="      --inf\tinput file already formatted for '${0##*/}'\n"
    msg+="\t\tuse --inp or --inf, not both\n"
    msg+="      --nbC\tnumber of active configurations (eg. 7 if 3 subgroups)\n"
    msg+="      --nbG\tnumber of grid points\n"
    msg+="      --outp\tprefix for the output files\n"
    # msg+="      --init\tinitialisation file (for EM only, allows to fix pi0)\n"
    # msg+="      --dtss\tfile with distance to the TSS\n"
    msg+="\n"
    msg+="Examples:\n"
    msg+="  ${0##*/} --p2b ~/bin/hm --inp \"out_eqtlbma_[0-9][0-9][0-9]_l10abfs_raw.txt.gz\" --nbC 7 --nbG 10 --outp out_hm\n"
    echo -e "$msg"
}

function version () {
    msg="${0##*/} 1.1\n"
    msg+="\n"
    msg+="Written by Timothee Flutre.\n"
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

function parseArgs () {
    TEMP=`getopt -o hVv: -l help,version,verbose:,p2b:,inp:,inf:,nbC:,nbG:,outp:,init:,dtss: \
	-n "$0" -- "$@"`
    if [ $? != 0 ]; then echo "ERROR: getopt failed" >&2 ; exit 1 ; fi
    eval set -- "$TEMP"
    while true; do
	case "$1" in
            -h|--help) help; exit 0; shift;;
            -V|--version) version; exit 0; shift;;
            -v|--verbose) verbose=$2; shift 2;;
	    --p2b) pathToBin=$2; shift 2;;
    	    --inp) inFiles=$2; shift 2;;
    	    --inf) tmpFile=$2; shift 2;;
    	    --nbC) nbConfigs=$2; shift 2;;
    	    --nbG) nbGrids=$2; shift 2;;
    	    --outp) outPrefix=$2; shift 2;;
    	    --init) initFile=$2; shift 2;;
	    --dtss) dtssFile=$2; shift 2;;
            --) shift; break;;
            *) echo "ERROR: options parsing failed" >&2; exit 1;;
	esac
    done
    if [ -z "${pathToBin}" ]; then
	echo -e "ERROR: missing compulsory option --p2b\n"
	help
	exit 1
    fi
    if [ ! -f "${pathToBin}" ]; then
	echo -e "ERROR: can't find binary '${pathToBin}'\n"
	help
	exit 1
    fi
    if [ ! -x "${pathToBin}" ]; then
	echo -e "ERROR: can't execute '${pathToBin}'\n"
	help
	exit 1
    fi
    if [ -z "${inFiles}" -a -z "${tmpFile}" ]; then
	echo -e "ERROR: missing compulsory option --inp (or --inf)\n"
	help
	exit 1
    fi
    if [ ! -z "${tmpFile}" -a ! -f "${tmpFile}" ]; then
	echo -e "ERROR: can't find file ${tmpFile}\n"
	help
	exit 1
    fi
    if [ -z "${nbConfigs}" ]; then
	echo -e "ERROR: missing compulsory option --nbC\n"
	help
	exit 1
    fi
    if [ -z "${nbGrids}" ]; then
	echo -e "ERROR: missing compulsory option --nbG\n"
	help
	exit 1
    fi
    if [ -z "${outPrefix}" ]; then
	echo -e "ERROR: missing compulsory option --outp\n"
	help
	exit 1
    fi
}

verbose=1
pathToBin=""
inFiles=""
tmpFile=""
nbConfigs=""
nbGrids=""
outPrefix=""
initFile=""
dtssFile=""
parseArgs "$@"

if [ $verbose -gt "0" ]; then
    startTime=$(timer)
    msg="START ${0##*/} $(date +"%Y-%m-%d") $(date +"%H:%M:%S")"
    set -f
    msg+="\ncmd-line: $0 "$@
    echo -e $msg
    set +f
    uname -a
fi

#--------------------------------------
if [ -z "${tmpFile}" ]; then
if [ $verbose -gt "0" ]; then
    echo "decompress, concatenate and reformat all input files ..."
fi
startTime2=$(timer)
tmpFile="input_hm_"$$".txt"
rm -f $tmpFile
nbInFiles=0
nbPairs=0
for inFile in $inFiles; do
    let nbInFiles=nbInFiles+1
    let nbPairs=nbPairs+$(zcat $inFile | sed 1d | grep -c -v "gen")
    zcat $inFile \
	| awk -v g=${nbGrids} 'NR>1 {if(match($3,"gen")==0){printf "%s_%s %s", $2, $1, $3; for(i=4;i<=4+g-1;++i){printf " %s", $i}; printf "\n"}}' \
	>> $tmpFile
done
if [ $verbose -gt "0" ]; then
    msg="nb of input files: ${nbInFiles}\n"
    msg+="nb of gene-SNP pairs: ${nbPairs}\n"
    msg+="nb of Bayes Factors: "$(echo "${nbPairs} * ${nbConfigs} * ${nbGrids}" | bc)"\n"
    msg+="preprocessing time: $(timer startTime2)"
    echo -e $msg
fi
# else
# if [ $verbose -gt "0" ]; then
#     printf "nb of gene-SNP pairs: %s\n" $(wc -l < ${tmpFile})
# fi
fi

#--------------------------------------
if [ $verbose -gt "0" ]; then
    echo "run the hierarchical model ..."
fi
cmd="${pathToBin}"
cmd+=" -d ${tmpFile}"
cmd+=" -s ${nbConfigs}"
cmd+=" -g ${nbGrids}"
if [ "x${initFile}" != "x" ]; then cmd+=" -i ${initFile}"; fi
if [ "x${dtssFile}" != "x" ]; then cmd+=" -f ${dtssFile}"; fi
cmd+=" 1> ${outPrefix}_stdout.txt"
cmd+=" 2> ${outPrefix}_stderr.txt"
echo $cmd
eval $cmd
if [ $? != 0 ]; then
    echo "ERROR: 'hm' didn't finished successfully" >&2
    exit 1
fi

#--------------------------------------
if [ $verbose -gt "0" ]; then
    echo "compress the two output files ..."
fi
rm -f ${outPrefix}"_stdout.txt.gz" ${outPrefix}"_stderr.txt.gz"
gzip ${outPrefix}"_stdout.txt"
gzip ${outPrefix}"_stderr.txt"

if [ $verbose -gt "0" ]; then
    echo "remove temporary input file ..."
fi
rm -f $tmpFile

if [ $verbose -gt "0" ]; then
    msg="END ${0##*/} $(date +"%Y-%m-%d") $(date +"%H:%M:%S")"
    msg+=" ($(timer startTime))"
    echo $msg
fi
