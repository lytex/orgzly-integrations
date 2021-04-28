source .env # Get ORG_DIRECTORY environment var from one centralized file

cd "$ORG_DIRECTORY"

while true; do
    git fetch
    sleep 1
done