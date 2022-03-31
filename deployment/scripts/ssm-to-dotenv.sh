#! /usr/bin/env bash
# ./scripts/ssm-to-dotenv.sh /<stage-name>/mmt

set -o pipefail

echo "# Values retrieved from SSM Parameter Store"
echo "# Prefix = $1"
echo "# Last update = $(date)"

aws ssm get-parameters-by-path \
    --path $1 \
    --with-decryption \
    --output text \
    --query "Parameters[].[Name,Value]" | \
while read name value; do
    key=${name##*/}  # Trim prefix
    key=$(echo $key | tr '[a-z]' '[A-Z]')  # Uppercase
    echo "${key}=\"$value\"";
done
