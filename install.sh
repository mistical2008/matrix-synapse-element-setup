#!/usr/bin/env bash

# Define required tools
REQUIRED_TOOLS=(docker docker-compose wget caddy jq)
MATRIX_SETUP_ROOT="matrix"
MATRIX_BASE_URL="https://matrix.example.com"
MATRIX_SERVER_NAME="matrix.example.com"
USER_SCRIPTS_DIR="$HOME/.local/share/bin"

# exit from script if programm with name $1 is not installed
function checkExistance ()
{
    if ! [ -x "$(command -v $1)" ]; then
        echo "Error: $1 is not installed." >&2
        exit 1
    else
        echo " ✓ $1 is installed"
    fi
}

# for each element in array $REQUIRED_TOOLS run checkExistance
function runToolsCheck ()
{
    echo "Checking required tools..."

    for tool in "${REQUIRED_TOOLS[@]}"
    do
        checkExistance $tool
    done
}

function createNetwork ()
{
    docker network create --driver=bridge --subnet=10.10.10.0/24 --gateway=10.10.10.1 matrix_net
}

function prepareFs ()
{
    mkdir matrix
}

function goToMatrixSetupRoot ()
{
    cd "$MATRIX_SETUP_ROOT/"
}

# check for ping to https://develop.element.io/config.json adn retry for 3 times and exit with error
function checkForElementIo ()
{
    echo "Checking for element.io..."

    if ping -c 1 -W 1 https://develop.element.io/config.json > /dev/null 2>&1; then
        echo " ✓ element.io is available"
        break
    else
        echo "Error: element.io is not reachable" >&2
        exit 1
    fi
}

function getElementConfig ()
{
    checkForElementIo

    wget https://develop.element.io/config.json
    mv config.json element-config.json
}

# add to element-config.json default_server_config base_url and server_name
function addDefaultServerConfig ()
{
    echo "Adding default_server_config to element-config.json..."

    jq '.default_server_config += {
        "m.homeserver": {
            "base_url": "'$MATRIX_BASE_URL'",
            "server_name": "'$MATRIX_SERVER_NAME'"
        },
        "m.identity_server": {
            "base_url": "https://vector.im"
        }
    }' element-config.json > element-config.json.tmp
    mv element-config.json.tmp element-config.json
}

function generateSynapseHomeserverConf ()
{
    docker run -it --rm -v "$HOME/$MATRIX_SETUP_ROOT/synapse:/data" -e SYNAPSE_SERVER_NAME=$MATRIX_SERVER_NAME -e SYNAPSE_REPORT_STATS=yes matrixdotorg/synapse:latest generate
}

function tellHowToSetupPostgresForSynapse ()
{
    echo "================= POSTGRES SETUP ====================="
    echo "To make Synapse work with Postgres you need to add comment out next lines synapse/homeserver.yaml"
    echo "database:"
    echo "  name: sqlite3"
    echo "  args:"
    echo "    database: /data/homeserver.db"
    echo ""
    echo "Than add to synapse/homeserver.yaml next lines:"
    echo "database:"
    echo "  name: psycopg2"
    echo "  args:"
    echo "    user: {{POSTGRES_USER}}"
    echo "    password: {{POSTGRES_PASSWORD}}"
    echo "    database: {{POSTGRES_DB}}"
    echo "    host: postgres"
    echo "    cp_min: 5"
    echo "    cp_max: 10"
}

function dockerComposeUp ()
{
    docker-compose up -d
}

function tellHowToSetupAnRunCaddy ()
{
    echo "================= CADDY SETUP ====================="
    echo "To open your server to the internet you need to run caddy"
    echo "Replace in 'Caddyfile' mail@example.com with your email. This need to secure connection with HTTPS"
    echo "Replace 'example.com' with your domain name"
    echo ""
    echo "Then you need to place this file in /etc/caddy/ or some directory in ~/ and run 'caddy start'"
    echo "If 'caddy' already running you need to run 'caddy reload'"
}

function setupMatrixUserCreateScript ()
{
    echo "================= USER CREATE SCRIPT ====================="
    # check if folder exists
    if [ -d "$HOME/$USER_SCRIPTS_DIR" ]; then
        echo "✓ Scripts folder exists"
    else
        echo "…Creating scripts folder in $HOME/$USER_SCRIPTS_DIR"
        mkdir "$HOME/$USER_SCRIPTS_DIR"
        echo "✓ Scripts folder created"
    fi

    cp ./new-matrix-user.sh "$HOME/$USER_SCRIPTS_DIR/new-matrix-user"

    echo "✓ Script 'new-matrix-user' copied to $HOME/$USER_SCRIPTS_DIR"
    chmod +x "$HOME/$USER_SCRIPTS_DIR/new-matrix-user" && echo "✓ Script 'new-matrix-user' is executable"
    echo ""
    echo "To create new matrix user run 'new-matrix-user' and follow instructions"
}

runToolsCheck
createNetwork
prepareFs
goToMatrixSetupRoot
getElementConfig
addDefaultServerConfig
generateSynapseHomeserverConf
tellHowToSetupPostgresForSynapse
dockerComposeUp
tellHowToSetupAnRunCaddy
setupMatrixUserCreateScript
