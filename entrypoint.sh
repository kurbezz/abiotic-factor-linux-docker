#!/bin/bash
set -euo pipefail

# Configure server arguments
SetUsePerfThreads="-useperfthreads "
if [[ $UsePerfThreads == "false" ]]; then
    SetUsePerfThreads=""
fi

SetNoAsyncLoadingThread="-NoAsyncLoadingThread "
if [[ $NoAsyncLoadingThread == "false" ]]; then
    SetNoAsyncLoadingThread=""
fi

MaxServerPlayers="${MaxServerPlayers:-6}"
Port="${Port:-7777}"
QueryPort="${QueryPort:-27015}"
ServerPassword="${ServerPassword:-password}"
SteamServerName="${SteamServerName:-LinuxServer}"
WorldSaveName="${WorldSaveName:-Cascade}"
AdditionalArgs="${AdditionalArgs:-}"

# The Discord webhook URL is provided as an environment variable.
# If not provided, the game server still starts but without webhook integration.
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"

# Check for updates/perform initial installation
if [ ! -d "/server/AbioticFactor/Binaries/Win64" ] || [[ $AutoUpdate == "true" ]]; then
    steamcmd \
      +@sSteamCmdForcePlatformType windows \
      +force_install_dir /server \
      +login anonymous \
      +app_update 2857200 validate \
      +quit
fi

pushd /server/AbioticFactor/Binaries/Win64 > /dev/null

echo "Starting game server..."
if [ -z "$DISCORD_WEBHOOK_URL" ]; then
    echo "Discord webhook URL not provided; server will run without webhook notifications."
    wine AbioticFactorServer-Win64-Shipping.exe ${SetUsePerfThreads}${SetNoAsyncLoadingThread}-MaxServerPlayers=${MaxServerPlayers} \
      -PORT=${Port} -QueryPort=${QueryPort} -ServerPassword=${ServerPassword} \
      -SteamServerName="${SteamServerName}" -WorldSaveName="${WorldSaveName}" -tcp ${AdditionalArgs}
else
    echo "Discord webhook enabled; monitoring logs for join code..."
    # Run the game server, piping output to tee which both prints the log and sends it to the notifier.
    wine AbioticFactorServer-Win64-Shipping.exe ${SetUsePerfThreads}${SetNoAsyncLoadingThread}-MaxServerPlayers=${MaxServerPlayers} \
      -PORT=${Port} -QueryPort=${QueryPort} -ServerPassword=${ServerPassword} \
      -SteamServerName="${SteamServerName}" -WorldSaveName="${WorldSaveName}" -tcp ${AdditionalArgs} \
      | tee >(while IFS= read -r line; do
            # Forward the line to stdout
            echo "$line"
            # Look for the join code line – adjust this regex if needed.
            if echo "$line" | grep -q "Session short code:"; then
                join_code=$(echo "$line" | sed -n 's/.*Session short code: \([A-Z0-9]\+\).*/\1/p')
                # Send only the join code to Discord via webhook
                curl -H "Content-Type: application/json" \
                     -d "{\"content\": \"${join_code}\"}" \
                     "$DISCORD_WEBHOOK_URL"
            fi
        done)
fi

popd > /dev/null
