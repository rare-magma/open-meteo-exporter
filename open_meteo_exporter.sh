#!/usr/bin/env bash
set -Eeo pipefail

dependencies=(awk curl gzip jq)
for program in "${dependencies[@]}"; do
    command -v "$program" >/dev/null 2>&1 || {
        echo >&2 "Couldn't find dependency: $program. Aborting."
        exit 1
    }
done

# shellcheck source=/dev/null
source "$CREDENTIALS_DIRECTORY/creds"

[[ -z "${INFLUXDB_HOST}" ]] && echo >&2 "INFLUXDB_HOST is empty. Aborting" && exit 1
[[ -z "${INFLUXDB_API_TOKEN}" ]] && echo >&2 "INFLUXDB_API_TOKEN is empty. Aborting" && exit 1
[[ -z "${ORG}" ]] && echo >&2 "ORG is empty. Aborting" && exit 1
[[ -z "${BUCKET}" ]] && echo >&2 "BUCKET is empty. Aborting" && exit 1
[[ -z "${LONGITUDE}" ]] && echo >&2 "LONGITUDE is empty. Aborting" && exit 1
[[ -z "${LATITUDE}" ]] && echo >&2 "LATITUDE is empty. Aborting" && exit 1

AWK=$(command -v awk)
CURL=$(command -v curl)
GZIP=$(command -v gzip)
JQ=$(command -v jq)

INFLUXDB_URL="https://$INFLUXDB_HOST/api/v2/write?precision=s&org=$ORG&bucket=$BUCKET"

AIR_QUALITY_METRICS="european_aqi,us_aqi,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,aerosol_optical_depth,dust,uv_index,uv_index_clear_sky"
OPEN_METEO_AIR_QUALITY_API_URL="https://air-quality-api.open-meteo.com/v1/air-quality?timeformat=unixtime&latitude=$LATITUDE&longitude=$LONGITUDE&current=$AIR_QUALITY_METRICS"

WEATHER_METRICS="temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m"
OPEN_METEO_CURRENT_WEATHER_API_URL="https://api.open-meteo.com/v1/forecast?timeformat=unixtime&latitude=$LATITUDE&longitude=$LONGITUDE&current=$WEATHER_METRICS"

air_quality_json=$($CURL --silent --fail --show-error --compressed "$OPEN_METEO_AIR_QUALITY_API_URL")
weather_json=$($CURL --silent --fail --show-error --compressed "$OPEN_METEO_CURRENT_WEATHER_API_URL")

pollution_stats=$(
    echo "$air_quality_json" |
        $JQ --raw-output "
        (.current |
        [\"${LONGITUDE}\",
        \"${LATITUDE}\",
        .european_aqi,
        .us_aqi,
        .pm10,
        .pm2_5,
        .carbon_monoxide,
        .nitrogen_dioxide,
        .sulphur_dioxide,
        .ozone,
        .aerosol_optical_depth,
        .dust,
        .uv_index,
        .uv_index_clear_sky,
        .time
        ])
        | @tsv" |
        $AWK '{printf "open_meteo_air_quality,longitude=%s,latitude=%s european_aqi=%s,us_aqi=%s,pm10=%s,pm2_5=%s,carbon_monoxide=%s,nitrogen_dioxide=%s,sulphur_dioxide=%s,ozone=%s,aerosol_optical_depth=%s,dust=%s,uv_index=%s,uv_index_clear_sky=%s %s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15}'
)

weather_stats=$(
    echo "$weather_json" |
        $JQ --raw-output "
        (.current |
        [\"${LONGITUDE}\",
        \"${LATITUDE}\",
        .temperature_2m,
        .relative_humidity_2m,
        .apparent_temperature,
        .precipitation,
        .rain,
        .showers,
        .snowfall,
        .weather_code,
        .cloud_cover,
        .pressure_msl,
        .surface_pressure,
        .wind_speed_10m,
        .wind_direction_10m,
        .wind_gusts_10m,
        .time
        ])
        | @tsv" |
        $AWK '{printf "open_meteo_current_weather,longitude=%s,latitude=%s temperature_2m=%s,relative_humidity_2m=%s,apparent_temperature=%s,precipitation=%s,rain=%s,showers=%s,snowfall=%s,weather_code=%s,cloud_cover=%s,pressure_msl=%s,surface_pressure=%s,wind_speed_10m=%s,wind_direction_10m=%s,wind_gusts_10m=%s %s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17}'
)

stats=$(
    cat <<END_HEREDOC
$pollution_stats
$weather_stats
END_HEREDOC
)

echo "$stats" | $GZIP |
    $CURL --silent --fail --show-error \
        --request POST "${INFLUXDB_URL}" \
        --header 'Content-Encoding: gzip' \
        --header "Authorization: Token $INFLUXDB_API_TOKEN" \
        --header "Content-Type: text/plain; charset=utf-8" \
        --header "Accept: application/json" \
        --data-binary @-
