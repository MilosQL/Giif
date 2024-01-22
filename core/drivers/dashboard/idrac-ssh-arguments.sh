# To be sourced from other scripts as needed

unset HOST
unset USERNAME
unset PASSWORD
unset PORT

# Developer's note: getopts is a shell builtin;
# see `man 1p getopts` and `help getopts` for details 

while getopts ":h:u:p:" flag; do
case "$flag" in
    h) HOST=$OPTARG;;
    u) USERNAME=$OPTARG;;
    p) PASSWORD=$OPTARG;;
   \?)
      echo -e "\nInvalid option: -$OPTARG.\n\nPlease contact your support team to resolve this problem.\n" >&2
      exit 1
      ;;
   \:)
      echo -e "\nOption -$OPTARG requires an argument.\n\nPlease contact your support team to resolve this problem.\n" >&2
      exit 1
      ;;
esac
done

shift "$(( OPTIND - 1 ))"

if [ -z "$HOST" ] ; then
      echo -e "\nMissing option: -h.\n\nPlease contact your support team to resolve this problem.\n" >&2
      exit 1
fi

if [ -z "$USERNAME" ] ; then
      echo -e "\nMissing option: -u.\n\nPlease contact your support team to resolve this problem.\n" >&2
      exit 1
fi

if [ -z "$PASSWORD" ] ; then
      echo -e "\nMissing option: -p.\n\nPlease contact your support team to resolve this problem.\n" >&2
      exit 1
fi

extract_colons="${HOST//[^:]}"
colon_count=${#extract_colons}
if ((colon_count >= 2 )); then
      echo -e "\nInvalid -h argument: Multiple ':' found.\n\nPlease contact your support team to resolve this problem.\n" >&2
      exit 1
fi

PORT=`echo ${HOST} | cut -s -d':' -f2`
HOST=${HOST%:*}
PORT=${PORT:-'22'}

# Check SSH credentials and SSH connectivity
sshpass -p ${PASSWORD} ssh -q -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p ${PORT} ${USERNAME}@${HOST} 'version' 1>/dev/null 2>&1
if [ $? != 0 ] ; then
      echo -e "\nUnable to establish SSH connection.\n\nPlease contact your support team to resolve this problem.\n" >&2
      exit 1
fi

# Preparing HOST-based locking variable for flock(1); getent converts symbolic name to an IP address
FLOCK=`getent hosts ${HOST} | cut -d' ' -f1 `
[ -z "$FLOCK" ] && FLOCK=${HOST}
