#!/bin/bash

set -u

FAILURES=0
DRYRUN=""
NONINTERACTIVE=0
INCLUDEPLUGINS=0
EXCLUDE_PLUGINS=()
PASSWORDLESS_OK=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_BASE="$(basename "${BASH_SOURCE[0]}" .sh)"
LOG_FILE="${SCRIPT_DIR}/${SCRIPT_BASE}_$(date +%F).log"

# -------------------------------
# Latest Log Symlink
# -------------------------------
LATEST_LOG="${SCRIPT_DIR}/${SCRIPT_BASE}_latest.log"
ln -sf "$(basename "${LOG_FILE}")" "${LATEST_LOG}"

# -------------------------------
# Logging Functions
# -------------------------------
log_section() {
    echo "------------------------------------------------------------------------"
    echo ""
    echo "$1"
    echo ""
    echo "------------------------------------------------------------------------"
}

log_info() {
    echo "[$(date '+%F %T')] INFO: $1" >> "${LOG_FILE}"
}

log_warn() {
    echo "[$(date '+%F %T')] WARN: $1" >> "${LOG_FILE}"
}

log_error() {
    echo "[$(date '+%F %T')] ERROR: $1" >> "${LOG_FILE}"
}

# -------------------------------
# Log Rotation
# -------------------------------
rotate_logs() {
    ls -1t "${SCRIPT_DIR}/${SCRIPT_BASE}"_*.log 2>/dev/null | tail -n +6 | xargs -r rm -f
}

# -------------------------------
# Rsync Wrapper (with stats)
# -------------------------------
run_rsync() {
    local LABEL="$1"
    shift

    local OUTPUT
    OUTPUT=$(rsync -az ${DRYRUN} --stats -e "ssh ${SSH_OPTS}" "$@" 2>&1)
    local RC=$?

    local FILES
    FILES=$(echo "$OUTPUT" | awk -F': ' '/Number of regular files transferred/ {print $2}')

    if [ -z "$FILES" ]; then
        FILES="0"
    fi

    if [ ${RC} -eq 0 ]; then
        echo "${LABEL} sync completed successfully - ${FILES} file(s) transferred"
        log_info "${LABEL} sync completed successfully - ${FILES} file(s) transferred"
    else
        echo "***** ERROR: ${LABEL} sync failed *****"
        log_error "${LABEL} sync failed"
        log_error "${OUTPUT}"
        FAILURES=$((FAILURES+1))
    fi
}

# -------------------------------
# Cron Setup Function
# -------------------------------
setup_cron() {
    local EXTRA_ARGS=""
    local plugin

    if [ "${INCLUDEPLUGINS}" -eq 1 ]; then
        EXTRA_ARGS="${EXTRA_ARGS} --include-plugins"
    fi

    for plugin in "${EXCLUDE_PLUGINS[@]}"; do
        EXTRA_ARGS="${EXTRA_ARGS} --exclude-plugin ${plugin}"
    done

    local CRON_CMD="*/5 * * * * ${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}") ${TARGET} --non-interactive${EXTRA_ARGS} >> /dev/null 2>&1"

    log_section "Cron Setup"

    if [ "${PASSWORDLESS_OK}" -ne 1 ]; then
        echo "Skipping cron setup because passwordless SSH is not working yet."
        echo "Fix SSH first, then add cron."
        log_warn "Cron setup skipped because passwordless SSH is not working"
        return
    fi

    if crontab -l 2>/dev/null | grep -Fq "${SCRIPT_BASE}"; then
        echo "Cron entry already exists for this script."
        log_info "Cron entry already exists"
        return
    fi

    echo "No cron entry found for this script."
    echo ""
    echo "Recommended cron job:"
    echo ""
    echo "${CRON_CMD}"
    echo ""

    read -r -p "Add this cron job now? [y/N]: " ADD_CRON

    if [[ "${ADD_CRON}" =~ ^[Yy]$ ]]; then
        (crontab -l 2>/dev/null; echo "${CRON_CMD}") | crontab -
        echo "Cron job added successfully."
        log_info "Cron job added: ${CRON_CMD}"
    else
        echo "Skipping cron setup."
        log_info "User skipped cron setup"
    fi
}

rotate_logs

log_info "------------------------------------------------------------------------"
log_info "Run started"

# -------------------------------
# Usage / Help
# -------------------------------
usage() {
    echo "------------------------------------------------------------------------"
    echo ""
    echo "Usage: $0 <target-ip> [options]"
    echo ""
    echo "Example:"
    echo "  $0 10.14.88.26"
    echo "  $0 10.14.88.26 --dry-run"
    echo "  $0 10.14.88.26 --include-plugins"
    echo "  $0 10.14.88.26 --include-plugins --exclude-plugin remote-falcon"
    echo "  $0 10.14.88.26 --dry-run --include-plugins --exclude-plugin remote-falcon"
    echo ""
    echo "Parameters:"
    echo "  <target-ip>           IP address of the destination FPP instance"
    echo ""
    echo "Options:"
    echo "  --dry-run             Show what would change without actually syncing"
    echo "  --non-interactive     Do not prompt for input (for cron/headless use)"
    echo "  --include-plugins     Include plugins and plugindata in sync"
    echo ""
    echo "  --exclude-plugin <name>"
    echo "                        Exclude a plugin from sync"
    echo "                        Can be specified multiple times"
    echo ""
    echo "                        Example:"
    echo "                          --exclude-plugin remote-falcon"
    echo "                          --exclude-plugin fpp-brightness"
    echo ""
    echo "                        This excludes:"
    echo "                          /home/fpp/media/plugins/<name>"
    echo "                          /home/fpp/media/config/plugin.<name>"
    echo "                          /home/fpp/media/config/plugin.<name>.*"
    echo ""
    echo "                        To see current plugin names, run:"
    echo "                          ls /home/fpp/media/plugins/"
    echo ""
    echo "This script syncs FPP media, configuration, scripts, and optionally"
    echo "plugins from the local system to the specified target."
    echo ""
    echo "------------------------------------------------------------------------"
}

# -------------------------------
# Argument Parsing
# -------------------------------
TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRYRUN="--dry-run"
            shift
            ;;
        --non-interactive)
            NONINTERACTIVE=1
            shift
            ;;
        --include-plugins)
            INCLUDEPLUGINS=1
            shift
            ;;
        --exclude-plugin)
            if [ -n "${2:-}" ]; then
                EXCLUDE_PLUGINS+=("$2")
                shift 2
            else
                echo "***** ERROR: --exclude-plugin requires a value *****"
                exit 1
            fi
            ;;
        --*)
            echo "***** WARNING: Unknown argument ignored: $1 *****"
            log_warn "Unknown argument ignored: $1"
            shift
            ;;
        *)
            if [ -z "${TARGET}" ]; then
                TARGET="$1"
            else
                echo "***** WARNING: Extra positional argument ignored: $1 *****"
                log_warn "Extra positional argument ignored: $1"
            fi
            shift
            ;;
    esac
done

if [ -z "${TARGET}" ]; then
    usage
    exit 1
fi

if [ -n "${DRYRUN}" ]; then
    echo "***** DRY RUN MODE - NO CHANGES WILL BE MADE *****"
    log_info "Dry run mode enabled"
fi

if [ "${NONINTERACTIVE}" -eq 1 ]; then
    echo "***** NON-INTERACTIVE MODE ENABLED *****"
    log_info "Non-interactive mode enabled"
fi

if [ "${INCLUDEPLUGINS}" -eq 1 ]; then
    echo "***** PLUGIN SYNC ENABLED *****"
    log_info "Plugin sync enabled"
else
    echo "***** PLUGIN SYNC DISABLED *****"
    log_info "Plugin sync disabled"
fi

if [ ${#EXCLUDE_PLUGINS[@]} -gt 0 ]; then
    echo "***** Excluding plugins: ${EXCLUDE_PLUGINS[*]} *****"
    log_info "Excluding plugins: ${EXCLUDE_PLUGINS[*]}"
fi

SSH_USER="root"
SSH_TARGET="${SSH_USER}@${TARGET}"
SSH_DIR="${HOME}/.ssh"
KNOWN_HOSTS="${SSH_DIR}/known_hosts"

SSH_OPTS="-o ControlMaster=auto -o ControlPersist=5m -o ControlPath=${HOME}/.ssh/cm-%r@%h:%p"

# -------------------------------
# First-Time Setup Notes
# -------------------------------
log_section "First-Time Setup Notes"

echo "If this is a NEW target system, the following may be required:"
echo ""
echo "1. Root SSH login must be enabled on the target"
echo "2. SSH service must be running"
echo "3. This script can optionally configure SSH keys automatically"
echo "4. Root should already have a local SSH key for ssh-copy-id to work"
echo ""
echo "You will be prompted to trust the host and/or copy SSH keys if needed."
echo ""

log_info "Target: ${TARGET}"

# -------------------------------
# Ensure ~/.ssh exists
# -------------------------------
log_section "Preparing SSH Environment"

mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
log_info "Prepared SSH directory ${SSH_DIR}"

# -------------------------------
# Check for local SSH key
# -------------------------------
if ! ls "${SSH_DIR}"/id_*.pub >/dev/null 2>&1; then
    echo "********************************************************************"
    echo "No local SSH public key found for root."
    echo "Passwordless SSH cannot be configured without a local key."
    echo ""
    echo "Run the following if needed:"
    echo "  ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N """
    echo "********************************************************************"
    log_warn "No local SSH public key found for root"
fi

# -------------------------------
# Check known_hosts entry
# -------------------------------
if ! ssh-keygen -F "${TARGET}" > /dev/null 2>&1; then
    echo ""
    echo "********************************************************************"
    echo "No SSH known_hosts entry found for ${TARGET}."
    echo "If you trust this host, its SSH key can be added now so you are not"
    echo "prompted repeatedly during rsync."
    echo "********************************************************************"
    echo ""

    log_warn "No known_hosts entry found for ${TARGET}"

    if [ "${NONINTERACTIVE}" -eq 1 ]; then
        echo "NON-INTERACTIVE MODE: Skipping known_hosts prompt."
        echo "Suggested fix:"
        echo "  ssh-keyscan -H ${TARGET} >> ${KNOWN_HOSTS}"
        log_warn "Non-interactive mode skipped known_hosts prompt for ${TARGET}"
        FAILURES=$((FAILURES+1))
    else
        read -r -p "Add ${TARGET} to ${KNOWN_HOSTS}? [y/N]: " ADD_HOSTKEY

        if [[ "${ADD_HOSTKEY}" =~ ^[Yy]$ ]]; then
            ssh-keyscan -H "${TARGET}" >> "${KNOWN_HOSTS}" 2>/dev/null
            chmod 600 "${KNOWN_HOSTS}"
            echo "Added ${TARGET} to ${KNOWN_HOSTS}"
            log_info "Added ${TARGET} to ${KNOWN_HOSTS}"
        else
            echo "Continuing without adding ${TARGET} to known_hosts."
            echo "You may be prompted repeatedly during sync."
            log_warn "User declined adding ${TARGET} to known_hosts"
        fi
    fi
else
    log_info "known_hosts entry already exists for ${TARGET}"
fi

# -------------------------------
# Check SSH auth
# -------------------------------
log_section "Checking Passwordless SSH Setup"

if ssh ${SSH_OPTS} -o BatchMode=yes -o ConnectTimeout=5 "${SSH_TARGET}" "exit" >/dev/null 2>&1; then
    echo "Passwordless SSH is working for ${SSH_TARGET}"
    log_info "Passwordless SSH working for ${SSH_TARGET}"
    PASSWORDLESS_OK=1
else
    echo "********************************************************************"
    echo "Passwordless SSH is NOT configured for ${SSH_TARGET}"
    echo ""
    echo "This script works best with SSH keys to avoid repeated prompts."
    echo ""
    echo "You can set it up manually with:"
    echo "  ssh-copy-id ${SSH_TARGET}"
    echo ""
    echo "Remote server requirements:"
    echo "  - root SSH login enabled"
    echo "  - your public key added to /root/.ssh/authorized_keys"
    echo "********************************************************************"
    echo ""

    log_warn "Passwordless SSH is not configured for ${SSH_TARGET}"

    if [ "${NONINTERACTIVE}" -eq 1 ]; then
        echo "NON-INTERACTIVE MODE: Skipping ssh-copy-id prompt."
        echo "You may be prompted for a password during sync, or the job may fail if cron cannot prompt."
        log_warn "Non-interactive mode skipped ssh-copy-id setup for ${SSH_TARGET}"
        FAILURES=$((FAILURES+1))
    else
        read -r -p "Attempt to configure passwordless SSH now? [y/N]: " SETUP_SSH

        if [[ "${SETUP_SSH}" =~ ^[Yy]$ ]]; then
            echo ""
            echo "Running: ssh-copy-id ${SSH_TARGET}"
            echo "You will be prompted for the remote password ONCE..."
            echo ""

            ssh-copy-id "${SSH_TARGET}" >/dev/null 2>&1
            local_rc=$?

            if [ ${local_rc} -ne 0 ]; then
                echo "***** WARNING: ssh-copy-id may have failed *****"
                log_warn "ssh-copy-id returned non-zero for ${SSH_TARGET}"
                FAILURES=$((FAILURES+1))
            fi

            echo ""
            echo "Re-testing passwordless SSH..."

            if ssh ${SSH_OPTS} -o BatchMode=yes -o ConnectTimeout=5 "${SSH_TARGET}" "exit" >/dev/null 2>&1; then
                echo "SUCCESS: Passwordless SSH is now working"
                log_info "Passwordless SSH successfully configured for ${SSH_TARGET}"
                PASSWORDLESS_OK=1
            else
                echo "***** WARNING: Passwordless SSH setup may have failed *****"
                log_warn "Passwordless SSH re-test failed for ${SSH_TARGET}"
                FAILURES=$((FAILURES+1))
            fi
        else
            echo "Continuing without passwordless SSH."
            log_warn "User declined passwordless SSH setup for ${SSH_TARGET}"
        fi
    fi
fi

echo "Current Date and Time: $(date)"
echo "Target: ${TARGET}"

log_info "Current Date and Time: $(date)"
log_info "Target: ${TARGET}"

# -------------------------------
# Ensure remote directories exist
# -------------------------------
log_section "Ensuring Remote Directory Structure"

REMOTE_DIRS="/home/fpp/media/music \
/home/fpp/media/videos \
/home/fpp/media/sequences \
/home/fpp/media/images \
/home/fpp/media/effects \
/home/fpp/media/playlists \
/home/fpp/media/config \
/home/fpp/media/scripts"

if [ "${INCLUDEPLUGINS}" -eq 1 ]; then
    REMOTE_DIRS="${REMOTE_DIRS} /home/fpp/media/plugins /home/fpp/media/plugindata"
fi

REMOTE_OUTPUT=$(ssh ${SSH_OPTS} "${SSH_TARGET}" "mkdir -p ${REMOTE_DIRS}" 2>&1)
REMOTE_RC=$?

if [ ${REMOTE_RC} -ne 0 ]; then
    echo "***** ERROR: Failed to ensure remote directory structure *****"
    log_error "Failed to ensure remote directory structure"
    log_error "${REMOTE_OUTPUT}"
    FAILURES=$((FAILURES+1))
else
    echo "Remote directory structure verified successfully"
    log_info "Remote directory structure verified successfully"
fi

PLUGIN_DIR_EXCLUDES=()
CONFIG_PLUGIN_EXCLUDES=()

for plugin in "${EXCLUDE_PLUGINS[@]}"; do
    PLUGIN_DIR_EXCLUDES+=(--exclude "${plugin}")
    CONFIG_PLUGIN_EXCLUDES+=(--exclude "plugin.${plugin}")
    CONFIG_PLUGIN_EXCLUDES+=(--exclude "plugin.${plugin}.*")
done

# -------------------------------
# Sync Media
# -------------------------------
log_section "Syncing Media"

run_rsync "Music"     --delete /home/fpp/media/music/     "${SSH_TARGET}:/home/fpp/media/music/"
run_rsync "Videos"    --delete /home/fpp/media/videos/    "${SSH_TARGET}:/home/fpp/media/videos/"
run_rsync "Sequences" --delete /home/fpp/media/sequences/ "${SSH_TARGET}:/home/fpp/media/sequences/"
run_rsync "Images"    --delete /home/fpp/media/images/    "${SSH_TARGET}:/home/fpp/media/images/"
run_rsync "Effects"   --delete /home/fpp/media/effects/   "${SSH_TARGET}:/home/fpp/media/effects/"

# -------------------------------
# Sync Config
# -------------------------------
log_section "Syncing Config"

run_rsync "Playlists" --delete /home/fpp/media/playlists/ "${SSH_TARGET}:/home/fpp/media/playlists/"
run_rsync "Config"    "${CONFIG_PLUGIN_EXCLUDES[@]}" --delete /home/fpp/media/config/ "${SSH_TARGET}:/home/fpp/media/config/"
run_rsync "Scripts"   --delete /home/fpp/media/scripts/   "${SSH_TARGET}:/home/fpp/media/scripts/"

# -------------------------------
# Sync Plugins
# -------------------------------
if [ "${INCLUDEPLUGINS}" -eq 1 ]; then
    log_section "Syncing Plugins"

    run_rsync "Plugins"    "${PLUGIN_DIR_EXCLUDES[@]}" --delete /home/fpp/media/plugins/ "${SSH_TARGET}:/home/fpp/media/plugins/"
    run_rsync "PluginData" --delete /home/fpp/media/plugindata/ "${SSH_TARGET}:/home/fpp/media/plugindata/"
else
    log_section "Skipping Plugins"

    echo "Plugin sync not requested."
    echo "Use --include-plugins to sync plugins and plugindata."
    log_info "Plugin sync skipped"
fi

# -------------------------------
# Cron Setup (Interactive Only)
# -------------------------------
if [ "${NONINTERACTIVE}" -eq 0 ]; then
    setup_cron
fi

# -------------------------------
# Summary
# -------------------------------
log_section "Sync Complete"

echo "Completed at: $(date)"
log_info "Completed at: $(date)"

if [ "$FAILURES" -gt 0 ]; then
    echo "***** WARNING: ${FAILURES} non-sync operation(s) failed or need attention *****"
    log_warn "${FAILURES} non-sync operation(s) failed or need attention"
else
    echo "All operations completed successfully"
    log_info "All operations completed successfully"
fi

log_info "Run ended"
log_info "------------------------------------------------------------------------"
