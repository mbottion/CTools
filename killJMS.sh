VERSION=0.1
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#
#   Appelé par l'option -T, permet de tester des parties de script
#
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
testUnit()
{
  startStep "Test de fonctionnalites"


  endStep
}
getsessions()
{
  exec_sql "/ as sysdba" "
col ora_session         format a15
col os_pid              format a10
col ora_username        format a10
col idle_since_hours    format 999D99
col secs_from_last_call format 999G999G999
col source_socket       format a50
set colsep ';'

alter session set nls_territory=FRANCE ;

with sess as (
    select 
       (floor(last_call_et/900)*900)/3600                                   idle_since_hours
      ,to_char(prev_exec_start,'dd/mm/yyyy hh24')                           prev_exec_start_hour
      ,to_char(logon_time,'dd/mm/yyyy hh24')                                logon_hour
      ,(sysdate - logon_time)*24*3600                                       secs_from_login
      ,to_number(last_call_et)                                              secs_from_last_call
      ,logon_time
      ,inst_id                                                             
      ,sid
      ,serial#
      ,username                                                             ora_username
      ,machine
      ,port
      ,paddr
    from 
      gv\$session s
    where
          inst_id=(select instance_number from v\$instance)
      and upper(substr(machine,4,3)) = '$sessClient' and username in ('$sessUserName')
    order by 1 desc)
select 
   s.sid || ',' || s.serial# || ',@'|| s.inst_id                           ora_session
  ,p.spid                                                                  os_pid
  ,s.ora_username                                                          ora_username
  ,s.idle_since_hours                                                      
  ,secs_from_last_call
  ,s.machine || ':' || s.port                                              source_socket
  ,case 
    when idle_since_hours > $inactiveSince then 'Y'
    else 'N'
  end                                                                      KILLABLE
from 
  sess s
left join gv\$process p on (s.inst_id=p.inst_id and s.paddr = p.addr )
where s.idle_since_hours > ($inactiveSince - 2)
order by idle_since_hours ASC
/
  "
}
listSessions()
{
  startRun "$mode des sessions avec plus de $inactiveSince heures" "d'inactivite sur $(hostname -s)" "Base : $ORACLE_SID"
  m=${1^^}
  t="-------------------------------------------------------------------------------------"
  printf "+-%-25.25s-+-%-10.10s-+-%-10.10s-+-%-20.20s-+-%-10.10s-+" "$t" "$t" "$t" "$t" "$t" ; echo
  printf "| %-25.25s | %-10.10s | %-10.10s | %-20.20s | %-10.10s |" "Session" "OS Pid" "User Oracle" "Duree d'inactivite" "A tuer" ; echo
  printf "+-%-25.25s-+-%-10.10s-+-%-10.10s-+-%-20.20s-+-%-10.10s-+" "$t" "$t" "$t" "$t" "$t" ; echo
  sessionsListees=0
  sessionsToKill=0
  IFS=$'\n'
  for line in $(getsessions | sed -e "s/ *; */;/g")
  do
          sess=$(echo $line | cut -f1 -d";")
           pid=$(echo $line | cut -f2 -d";")
           usr=$(echo $line | cut -f3 -d";")
    hours_idle=$(echo $line | cut -f4 -d";")
     secs_idle=$(echo $line | cut -f5 -d";")
        socket=$(echo $line | cut -f6 -d";")
       to_kill=$(echo $line | cut -f7 -d";")
    sessionsListees=$(($sessionsListees + 1))
    printf "| %-25.25s | %-10.10s | %-10.10s | %-20.20s | %-10.10s |" "$sess" "$pid" "$usr" "${hours_idle}h ($secs_idle s)" "$to_kill"
    if [ "$to_kill" = "Y" ]
    then
      sessionsToKill=$(($sessionsToKill + 1))
      echo
      printf "| %-87.87s |\n" "           |"
      printf "| %-87.87s |\n" "           +------> Source    : $socket"
      ps -p $pid >/dev/null 2>&1 && pHere="Existe" || pHere="Absent"
      printf "| %-87.87s |\n" "           +------> PID       : $pid ($pHere)"
      if [ "$pHere" = "Existe" ]
      then
        if [ "$mode" = "KILL" ]
        then
          kill -15 $pid >/dev/null 2>&1 && pStatus="Tue" || pStatus="Non Tue"
          printf "| %-87.87s |\n" "                     +------> ($pStatus)"
        else
          printf "| %-87.87s |\n" "                     +------> (Liste Seule)"
        fi
      fi
    else
      echo
    fi
  done || die "err"
  unset IFS
  printf "+-%-25.25s-+-%-10.10s-+-%-10.10s-+-%-20.20s-+-%-10.10s-+" "$t" "$t" "$t" "$t" "$t" ; echo
  echo
  echo "     Serveur          : $(hostname -f)"
  echo "     Sessions listees : $sessionsListees"
  if [ "$mode" = "LIST" ]
  then
    echo "      Sessions a tuer : $sessionsToKill"
  else
    echo "       Sessions tuees : $sessionsToKill"
  fi
  endRun
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
startRun()
{
  START_INTERM_EPOCH=$(date +%s)
  echo   "========================================================================================" 
  echo   " Demarrage de l'execution"
  echo   "========================================================================================" 
  echo   "  - $1"
  [ "$2" != "" ] && echo   "  - $2"
  [ "$3" != "" ] && echo   "  - $3"
  echo   "  - Demarrage a    : $(date)"
  echo   "========================================================================================" 
  echo
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
endRun()
{
  END_INTERM_EPOCH=$(date +%s)
  all_secs2=$(expr $END_INTERM_EPOCH - $START_INTERM_EPOCH)
  mins2=$(expr $all_secs2 / 60)
  secs2=$(expr $all_secs2 % 60 | awk '{printf("%02d",$0)}')
  echo
  echo   "========================================================================================" 
  echo   "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
  echo   "  - Fin a         : $(date)" 
  echo   "  - Duree         : ${mins2}:${secs2}"
  echo   "========================================================================================" 
  echo   "Script LOG in : $LOG_FILE"
  echo   "========================================================================================" 
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
startStep()
{
  STEP="$1"
  STEP_START_EPOCH=$(date +%s)
  echo
  echo "       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
  echo "       - Debut Etape   : $STEP"
  echo "       - Demarrage a   : $(date)" 
  echo "       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
  echo
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Trace
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
endStep()
{
  STEP_END_EPOCH=$(date +%s)
  all_secs2=$(expr $STEP_END_EPOCH - $STEP_START_EPOCH)
  mins2=$(expr $all_secs2 / 60)
  secs2=$(expr $all_secs2 % 60 | awk '{printf("%02d",$0)}')
  echo
  echo "       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
  echo "       - Fin Etape     : $STEP"
  echo "       - Terminee a    : $(date)" 
  echo "       - Duree         : ${mins2}:${secs2}"
  echo "       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Abort du programme
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
die() 
{
  echo "
ERROR :
  $*"
  exit 1
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#      Exécute du SQL avec contrôle d'erreur et de format
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exec_sql()
{
#
#  Don't forget to use : set -o pipefail un the main program to have error managempent
#
  local VERBOSE=N
  local SILENT=N
  if [ "$1" = "-silent" ]
  then 
    SILENT=Y
    shift
  fi
  if [ "$1" = "-no_error" ]
  then
    err_mgmt="whenever sqlerror continue"
    shift
  else
    err_mgmt="whenever sqlerror exit failure"
  fi
  if [ "$1" = "-verbose" ]
  then
    VERBOSE=Y
    shift
  fi
  local login="$1"
  local stmt="$2"
  local lib="$3"
  local bloc_sql="$err_mgmt
set recsep off
set head off 
set feed off
set pages 0
set lines 2000
set tab off
connect ${login}
$stmt"
  REDIR_FILE=""
  REDIR_FILE=$(mktemp)
  if [ "$lib" != "" ] 
  then
     printf "%-75s : " "$lib";
     sqlplus -s /nolog >$REDIR_FILE 2>&1 <<%EOF%
$bloc_sql
%EOF%
    status=$?
  else
     sqlplus -s /nolog <<%EOF% | tee $REDIR_FILE  
$bloc_sql
%EOF%
    status=$?
  fi
  if [ $status -eq 0 -a "$(egrep "SP2-" $REDIR_FILE)" != "" ]
  then
    status=1
  fi
  if [ "$lib" != "" ]
  then
    [ $status -ne 0 ] && { echo "*** ERREUR ***" ; test -f $REDIR_FILE && cat $REDIR_FILE ; rm -f $REDIR_FILE ; } \
                      || { echo "OK" ; [ "$VERBOSE" = "Y" ] && test -f $REDIR_FILE && sed -e "s;^;    > ;" $REDIR_FILE ; }
  fi 
  rm -f $REDIR_FILE
  [ $status -ne 0 ] && return 1
  return $status
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#     Teste un répertoire et le crée
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
checkDir()
{
  [ "$1" = "-silent" ] && { SILENT="Y" ; shift ; }
  [ "$SILENT" != "Y" ] && printf "%-75s : " "  - Existence of $1"
  if [ ! -d $1 ]
  then
    [ "$SILENT" != "Y" ] && echo "Non Existent"
    [ "$SILENT" != "Y" ] && printf "%-75s : " "    - Creation of $1"
    if [ "$SILENT" != "Y" ] 
    then
      mkdir -p $1 && echo OK || { echo "*** ERROR ***" ; return 1 ; }
    else
      mkdir -p $1 || return 1
    fi
  else
    [ "$SILENT" != "Y" ] && echo "OK"
  fi
  [ "$SILENT" != "Y" ] && printf "%-75s : " "    - $1 is writable"
  if [ "$SILENT" != "Y" ] 
  then
    [ -w $1 ] && echo OK || { echo "*** ERROR ***" ; return 1 ; }
  else
    [ -w $1 ] || return 1
  fi  
  return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#  Usage
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
usage() 
{
 echo " $*

Usage :
 $SCRIPT [-K] [-t heures]
         [-h|-?]

         -t heures    : Selectionne les sessions inactives depuis 'heures'
                        heures comme candidates au kill 
         -K           : Tue effectivement les sessions et les processes
         -L           : Execute sur le serveur local seulement
         -?|-h        : Aide

  Version : $VERSION
  "
  exit
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set -o pipefail

SCRIPT=killJMS.sh

[ "$(id -un)" != "oracle" ] && die "Merci de lancer ce script depuis l'utilisateur \"oracle\""

#[ "$1" = "" ] && usage
toShift=0
while getopts t:KLh opt
do
  case $opt in
   # --------- Selection des sessions -------------------------
   t)   inactiveSince=$OPTARG    ; toShift=$(($toShift + 2)) ;;
   # --------- Modes de fonctionnement ------------------------
   K)   mode=KILL                ; toShift=$(($toShift + 1)) ;;
   L)   LOCAL=Y                  ; toShift=$(($toShift + 1)) ;;
   ?|h) usage "Aide demandee";;
  esac
done
shift $toShift 
# -----------------------------------------------------------------------------
#
#       Analyse des paramètres et valeurs par défaut
#
# -----------------------------------------------------------------------------
mode=${mode:-LIST}                             # Par défaut LIST
LOCAL=${LOCAL:-N}
inactiveSince=${inactiveSince:-12}
inactiveSince=$(echo $inactiveSince | sed -e "s;,;.;g")

[ "$mode" = "KILL" ] && argOtherServer="-K"
argOtherServer="$argOtherServer -t $inactiveSince -L"
sessUserName=TEC
sessClient=JMS
# -----------------------------------------------------------------------------
#
#    Constantes et variables dépendantes
#
# -----------------------------------------------------------------------------
DAT=$(date +%Y%m%d_%H%M)                     # DATE (for filenames)
BASEDIR=$HOME/killJMS                      # Base dir for logs & files
LOG_DIR=$BASEDIR/$ORACLE_SID                  # Log DIR

if [ "$LOG_FILE" = "" ]
then
  case $mode in
    KILL)         LOG_FILE=LOG_FILE=$LOG_DIR/killJMS_${ORACLE_SID}_${DAT}.log ;;
    TEST)         LOG_FILE=/dev/null                                       ;;
    LIST)         LOG_FILE=/dev/null                                       ;;
    *)            die "Mode inconnu"                                       ;;
  esac
fi

# -----------------------------------------------------------------------------
#    Controles basiques (il faut que l'on puisse poitionner l'environnement
# base de données cible (et que ce soit la bonne!!!
# -----------------------------------------------------------------------------

checkDir -silent $LOG_DIR || die "$LOG_DIR is incorrect"

# -----------------------------------------------------------------------------
#      Lancement de l'exécution
# -----------------------------------------------------------------------------

case $mode in
 KILL)           listSessions KILL       2>&1 | tee $LOG_FILE ;;
 LIST)           listSessions LIST       2>&1 | tee $LOG_FILE ;;
 TEST)           testUnit       2>&1 | tee $LOG_FILE ;;
esac

if [ "$LOCAL" != "Y" ]
then
  localServer=$(hostname -f)
  scriptPath=$(readlink -f $0)
  if    [[ "$localServer" =~ ^[^\.]*1\. ]]
  then
    autreNoeud=$(echo $localServer | sed -e "s;^\([^\.]*\)1;\12;")
  elif  [[ "$localServer" =~ ^[^\.]*2\. ]]
  then
    autreNoeud=$(echo $localServer | sed -e "s;^\([^\.]*\)2;\11;")
  else
    die "Nom de serveur non connu"
  fi


  echo
  echo "======================================================================"
  echo "Copie et lancement de $scriptPath sur $autreNoeud"
  echo "======================================================================"
  echo

  ssh -o StrictHostKeyChecking=no $autreNoeud true || die "$autre Noeud non accessible"
  ssh -o StrictHostKeyChecking=no $autreNoeud mkdir -p $(dirname $scriptPath) || die "Impossible de creer le repertoire"
  scp -o StrictHostKeyChecking=no -q $scriptPath ${autreNoeud}:$scriptPath || die "Impossible de recopier le script"
  envFile=/home/oracle/$(echo $ORACLE_SID | sed -e "s;.$;;").env
  ssh -o StrictHostKeyChecking=no $autreNoeud "ORACLE_SID=None ; . $envFile ; $scriptPath $argOtherServer"
fi