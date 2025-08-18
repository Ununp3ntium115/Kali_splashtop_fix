#! /bin/bash
bstime=`date +%s`
while true; do
	sleep 10
	case "$(pgrep -f 'SRStreamer' | wc -w)" in
	0) echo "Restarting Streamer GUI"
		exec /opt/splashtop-streamer/script/splashtop-streamer
		[ $? -eq 0 ] && exit 0
		;;
	1) echo "SRStreamer is still alive"
		;;
	esac
	cur_time=$((`date +%s`-bstime))
	[ "$cur_time" -gt 25 ] && exit 0
done

