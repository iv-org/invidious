#!/bin/zsh


print_help()
{
	echo "Usage: yt-api-helper  -i [-c <client>] [-e <endpoint>]"
	echo "Usage: yt-api-helper  -e <endpoint> -d <data>"
	echo ""
	echo "Options:"
	echo "  -c,--client       Client to use. Pass 'help' to this option to get"
	echo "                      the list of supported clients"
	echo "  -d,--data         Raw data to send to the API"
	echo "  -e,--endpoint     Youtube endpoint to request. Pass 'help' to this"
	echo "                      option to get the list of supported endpoints"
	echo "  -h,--help         Show this help"
	echo "  -i,--interactive  Run in interactive mode"
	echo "  -o,--output       Print output to file instead of stdout"
	echo ""
}

print_clients()
{
	echo "Available clients:"
	echo "web"
	echo "web-embed"
	echo "web-mobile"
	echo "android"
	echo "android-embed"
}

print_endpoints()
{
	echo "Available endpoints:"
	echo "browse"
	echo "browse-continuation"
	echo "next"
	echo "next-continuation"
	echo "player"
	echo "search"
	echo "resolve"
}


query_with_default()
{
	prompt="$1"
	default="$2"

	printf "\n%s [%s]: " "$prompt" "$default" >&2
	read data

	if [ -z "$data" ]; then
		echo "$default"
	else
		echo "$data"
	fi
}

query_with_error()
{
	prompt="$1"
	error_message="$2"

	printf "\n%s []: " "$prompt" >&2
	read data

	if [ -z "$data" ]; then
		echo "Error: $error_message"
		return 1
	else
		echo "$data"
	fi
}


is_arg()
{
	case $1 in
		-c|--client)      true;;
		-d|--data)        true;;
		-e|--endpoint)    true;;
		-h|--help)        true;;
		-i|--interactive) true;;
		-o|--output)      true;;
		*)                false;;
	esac
}


#
# Parameters init
#

interactive=false

client_option=""
endpoint_option=""

data=""


#
# Interactive client selection
#

while :; do
	# Exit if no more arguments to parse
	if [ $# -eq 0 ]; then break; fi

	case $1 in
		-c|--client)
			shift

			if [ $# -eq 0 ] || $(is_arg "$1"); then
				echo "Error: missing argument after -c/--client"
				return 2
			fi

			client_option=$1
		;;

		-d|--data)
			shift

			if [ $# -eq 0 ] || $(is_arg "$1"); then
				echo "Error: missing argument after -d/--data"
				return 2
			fi

			data=$1
		;;

		-e|--endpoint)
			shift

			if [ $# -eq 0 ] || $(is_arg "$1"); then
				echo "Error: missing argument after -e/--endpoint"
				return 2
			fi

			endpoint_option=$1
		;;

		-h|--help)
			print_help
			return 0
		;;

		-i|--interactive)
			interactive=true
		;;

		-o|--output)
			shift

			if [ $# -eq 0 ] || $(is_arg "$1"); then
				echo "Error: missing argument after -o/--output"
				return 2
			fi

			output="$1"
		;;

		*)
			echo "Error: unknown argument '$1'"
			return 2
		;;
	esac

	shift
done


#
# Input validation
#

if [ ! -z "$data" ]; then
	# Can't pass data in interactive mode
	if [ $interactive = true ]; then
		echo "Error: -d/--data can't be used with -i/--interactive"
		return 2
	fi

	# Can't pass client in non-interactive mode (must be part of data)
	if [ ! -z $client_option ]; then
		echo "Error: -c/--client can't be used with -d/--data"
		return 2
	fi

	# Endpoint must be given if non-interactive mode
	if [ -z $endpoint_option ]; then
		echo "Error: In non-interactive mode, an endpoint must be passed with -e/--endpoint"
		return 2
	fi
fi

if [ -z "$data" ] && [ $interactive = false ]; then
	# Data must be given if non-interactive mode
	echo "Error: In non-interactive mode, data must be passed with -d/--data"
	return 2
fi

if [ -z "$output" ] && [ $interactive = true ]; then
	printf "\nIt is recommended to use --output in interactive mode.\nContinue? [y/N]: "
	read confirm

	if [ -z $confirm ]; then confirm="n"; fi

	case $confirm in
		[Yy]|[Yy][Ee][Ss]) ;;
		*) return 0;;
	esac
fi


#
# Client selection
#

if [ -z $client_option ]; then
	client_option=$(query_with_default "Enter a client to use" "web")
fi

case $client_option in
	help)
		print_clients
		return 0
	;;

	web)
		apikey="AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
		client_name="WEB"
		client_vers="2.20210721.00.00"
	;;

	web-embed)
		apikey="AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
		client_name="WEB_EMBEDDED_PLAYER"
		client_vers="1.20210721.1.0"
	;;

	web-mobile)
		apikey="AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
		client_name="MWEB"
		client_vers="2.20210726.08.00"
	;;

	android)
		apikey= "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w"
		client_name="ANDROID"
		client_vers="16.20"
	;;

	android-embed)
		apikey="AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
		client_name="ANDROID_EMBEDDED_PLAYER"
		client_vers="16.20"
	;;

	*)
		echo "Error: Unknown client '$client_option'"
		echo ""
		print_clients
		return 1
	;;
esac


#
# Endpoint selection
#

if [ -z $endpoint_option ]; then
	printf "Enter an endpoint to request []: "
	read endpoint_option
fi

case $endpoint_option in
	help)
		print_endpoints
		return 0
		;;

	browse)
		endpoint="youtubei/v1/browse"

		if [ $interactive = true ]; then
			browse_id=$(query_with_default "Enter browse ID" "UCXuqSBlHAE6Xw-yeJA0Tunw")
			partial_data="\"browseId\":\"${browse_id}\""
		fi
	;;

	browse-cont*|browse-tok*)
		endpoint="youtubei/v1/browse"

		if [ $interactive = true ]; then
			token=$(query_with_error "Enter continuation token" "token required")
			partial_data="\"continuation\":\"${token}\""
		fi
	;;

	player|next)
		endpoint="youtubei/v1/$endpoint_option"

		if [ $interactive = true ]; then
			vid=$(query_with_default "Enter video ID" "dQw4w9WgXcQ")
			partial_data="\"videoId\":\"${vid}\""

		fi
	;;

	next-cont*|next-tok*)
		endpoint="youtubei/v1/next"

		if [ $interactive = true ]; then
			token=$(query_with_error "Enter continuation token" "token required")
			partial_data="\"continuation\":\"${token}\""
		fi
	;;

	search)
		endpoint="youtubei/v1/search"

		if [ $interactive = true ]; then
			# Get search query, and escape backslashes and double quotes
			query=$(
				query_with_error "Enter your search query" "search term required" |
				sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
			)
			partial_data="\"query\":\"${query}\""
		fi
	;;

	resolve)
		endpoint="navigation/resolve_url"

		if [ $interactive = true ]; then
			url=$(query_with_error "Enter URL" "URL required")
			partial_data="\"url\":\"${url}\""
		fi
	;;

	*)
		echo "Error: Unknown endpoint '$endpoint_option'"
		echo ""
		print_clients
		return 1
	;;
esac


#
# Interactively request additional parameters for the supported endpoints
#

if [ $interactive = true ]
then
	case $endpoint_option in

	browse|player|search)
		params=$(query_with_default "Enter optional parameters (base64-encoded protobuf)" "")

		if [ ! -z $params ]; then
			partial_data="${partial_data},\"params\":\"${params}\""
		fi
	;;
	esac
fi

# new line
echo


#
# Interactive language/region selection
#

if [ $interactive = true ]; then
	hl=$(query_with_default "Enter content language (hl)" "en")
	gl=$(query_with_default "Enter content region (gl)"   "US")

	client="\"clientName\":\"${client_name}\",\"clientVersion\":\"${client_vers}\",\"hl\":\"${hl}\",\"gl\":\"${gl}\""
fi


#
# Final command
#

if [ $interactive = true ]; then
	data="{\"context\":{\"client\":{$client}},$partial_data}"

	# Basic debug
	echo "sending:"
	echo "$data" | sed 's/{/{\n/g; s/}/\n}/g; s/,/,\n/g'
fi


url="https://www.youtube.com/${endpoint}?key=${apikey}"

# Headers
hdr_ct='Content-Type: application/json; charset=utf-8'
hdr_ua='User-Agent: Mozilla/5.0 (Windows NT 10.0; rv:78.0) Gecko/20100101 Firefox/78.0'

# Default to STDOUT if no output file was given
if [ -z "output" ]; then output='-'; fi

# Run!
curl --compressed -o "$output" -H "$hdr_ct" -H "$hdr_ua" --data "$data" "$url"
