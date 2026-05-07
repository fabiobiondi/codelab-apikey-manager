#!/bin/bash

# 🚀 GOOGLE CLOUD API KEY MANAGER — WORKSHOP EDITION 🚀
# Designed for students running on free trial credits.
# Handles: project creation, billing auto-link, API enablement, key creation.

set -uo pipefail

# ────────────────────────────────────────────────────────────────────
# Helper: interactive picker. Uses fzf when available, otherwise falls
# back to a numbered prompt. Items come from stdin (one per line); the
# chosen item is echoed on stdout. Prompts go to stderr so callers can
# capture stdout cleanly. Returns non-zero if the user cancels.
# ────────────────────────────────────────────────────────────────────
pick_from_list() {
    local label="$1"
    local items=()
    local line
    while IFS= read -r line; do
        items+=("$line")
    done

    if [ ${#items[@]} -eq 0 ]; then
        return 1
    fi

    if command -v fzf >/dev/null 2>&1; then
        printf '%s\n' "${items[@]}" | fzf \
            --height=40% \
            --reverse \
            --no-info \
            --prompt="${label} > " \
            --header="↑/↓ to move, Enter to select, Esc to cancel"
        return $?
    fi

    # Fallback: numbered list on stderr, read number from user.
    # Read from /dev/tty because our stdin is the piped item list.
    {
        echo ""
        for i in "${!items[@]}"; do
            echo "   $((i+1))) ${items[$i]}"
        done
        echo ""
        printf "🔢 Enter the number for %s: " "$label"
    } >&2
    local choice
    if ! read -r choice </dev/tty; then
        return 1
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && \
       [ "$choice" -ge 1 ] && \
       [ "$choice" -le "${#items[@]}" ]; then
        printf '%s\n' "${items[$((choice-1))]}"
        return 0
    fi
    return 1
}

echo "------------------------------------------------"
echo "🌟 Workshop API Key Manager 🌟"
echo "------------------------------------------------"

# ────────────────────────────────────────────────────────────────────
# 0️⃣  Pre-flight: gcloud installed & authenticated
# ────────────────────────────────────────────────────────────────────
if ! command -v gcloud >/dev/null 2>&1; then
    echo "❌ gcloud CLI not found. In Cloud Shell this should never happen — re-open the shell."
    echo "   Otherwise install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

ACTIVE_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
if [ -z "$ACTIVE_ACCOUNT" ] || [ "$ACTIVE_ACCOUNT" = "(unset)" ]; then
    echo "❌ No active gcloud account. Run: gcloud auth login"
    exit 1
fi
echo "👤 Authenticated as: $ACTIVE_ACCOUNT"

# ────────────────────────────────────────────────────────────────────
# 1️⃣  Billing account: pick a working trial credit
# ────────────────────────────────────────────────────────────────────
echo ""
echo "💳 Looking for an open billing account (trial credit)..."

# Get only OPEN billing accounts
mapfile -t OPEN_BILLING < <(gcloud billing accounts list \
    --filter="open=true" \
    --format="value(name.basename())" 2>/dev/null)

if [ ${#OPEN_BILLING[@]} -eq 0 ]; then
    echo "❌ No open billing accounts found."
    echo "   You need a trial credit redeemed on this account ($ACTIVE_ACCOUNT)."
    echo "   Check the workshop instructions or visit: https://console.cloud.google.com/billing"
    exit 1
fi

if [ ${#OPEN_BILLING[@]} -eq 1 ]; then
    BILLING_ACCOUNT="${OPEN_BILLING[0]}"
    echo "✅ Using billing account: $BILLING_ACCOUNT"
else
    echo "📋 Multiple open billing accounts found."
    echo "   (Trial credits are usually 'Google Cloud Platform Trial Billing Account')"
    mapfile -t BILLING_DISPLAY < <(gcloud billing accounts list --filter="open=true" \
        --format="value(displayName)" 2>/dev/null)

    BILLING_ITEMS=()
    for i in "${!OPEN_BILLING[@]}"; do
        BILLING_ITEMS+=("${OPEN_BILLING[$i]}  —  ${BILLING_DISPLAY[$i]:-}")
    done

    BILLING_CHOICE=$(printf '%s\n' "${BILLING_ITEMS[@]}" | pick_from_list "Billing account")
    if [ -z "$BILLING_CHOICE" ]; then
        echo "❌ No billing account selected."
        exit 1
    fi
    BILLING_ACCOUNT="${BILLING_CHOICE%%  —  *}"
    echo "✅ Using billing account: $BILLING_ACCOUNT"
fi

# ────────────────────────────────────────────────────────────────────
# 2️⃣  Project: use existing or create new one
# ────────────────────────────────────────────────────────────────────
echo ""
echo "📦 Project setup..."

DEFAULT_PROJECT=$(gcloud config get-value project 2>/dev/null)
PROJECT_ID=""
CREATE_NEW=0

# Load available projects into arrays
mapfile -t AVAILABLE_PROJECTS < <(gcloud projects list --format="value(projectId)" 2>/dev/null)
mapfile -t AVAILABLE_PROJECT_NAMES < <(gcloud projects list --format="value(name)" 2>/dev/null)

if [ -n "$DEFAULT_PROJECT" ] && [ "$DEFAULT_PROJECT" != "(unset)" ]; then
    read -p "🆔 Use current project '$DEFAULT_PROJECT'? (Y/n/new): " PROJECT_CHOICE
    PROJECT_CHOICE=${PROJECT_CHOICE:-Y}
    if [[ "$PROJECT_CHOICE" =~ ^[Yy]$ ]]; then
        PROJECT_ID=$DEFAULT_PROJECT
    elif [[ "$PROJECT_CHOICE" =~ ^[Nn]ew$ ]]; then
        CREATE_NEW=1
    fi
    # any other input (n, no, etc.) → fall through to existing/new prompt
fi

if [ -z "$PROJECT_ID" ] && [ "$CREATE_NEW" -eq 0 ]; then
    echo ""
    NEW_ENTRY="+ Create new project"

    if [ ${#AVAILABLE_PROJECTS[@]} -gt 0 ]; then
        echo "📋 Pick a project (or create a new one):"
        PROJECT_ITEMS=("$NEW_ENTRY")
        for i in "${!AVAILABLE_PROJECTS[@]}"; do
            PROJECT_ITEMS+=("${AVAILABLE_PROJECTS[$i]}  —  ${AVAILABLE_PROJECT_NAMES[$i]:-}")
        done

        PROJECT_CHOICE=$(printf '%s\n' "${PROJECT_ITEMS[@]}" | pick_from_list "Project")

        if [ -z "$PROJECT_CHOICE" ]; then
            # Fallback path may yield empty if the user typed nothing.
            # Allow them to type a raw project ID or 'new' as a last resort.
            read -r -p "🆔 Enter an existing project ID, or type 'new' to create one: " PROJECT_INPUT
            if [ "$PROJECT_INPUT" = "new" ]; then
                CREATE_NEW=1
            elif [ -z "$PROJECT_INPUT" ]; then
                echo "❌ Project ID required."
                exit 1
            else
                PROJECT_ID="$PROJECT_INPUT"
                gcloud config set project "$PROJECT_ID" --quiet
            fi
        elif [ "$PROJECT_CHOICE" = "$NEW_ENTRY" ]; then
            CREATE_NEW=1
        else
            PROJECT_ID="${PROJECT_CHOICE%%  —  *}"
            gcloud config set project "$PROJECT_ID" --quiet
        fi
    else
        echo "   No existing projects found in this account."
        PROJECT_ITEMS=("$NEW_ENTRY")
        PROJECT_CHOICE=$(printf '%s\n' "${PROJECT_ITEMS[@]}" | pick_from_list "Project")
        if [ "$PROJECT_CHOICE" = "$NEW_ENTRY" ]; then
            CREATE_NEW=1
        else
            echo "❌ No selection made."
            exit 1
        fi
    fi
fi

if [ "$CREATE_NEW" -eq 1 ]; then
    # Project IDs must be globally unique, 6-30 chars, lowercase.
    # Retry until creation succeeds or the user aborts (Ctrl+C / empty after suggestion).
    while true; do
        SUGGESTED_ID="workshop-$(date +%s)-$RANDOM"
        SUGGESTED_ID=$(echo "$SUGGESTED_ID" | tr '[:upper:]' '[:lower:]' | cut -c1-30)
        read -p "📝 New project ID (default: $SUGGESTED_ID): " NEW_PROJECT_ID
        NEW_PROJECT_ID=${NEW_PROJECT_ID:-$SUGGESTED_ID}

        echo "🏗️  Creating project '$NEW_PROJECT_ID'..."
        if gcloud projects create "$NEW_PROJECT_ID" --name="Workshop Project" --quiet; then
            PROJECT_ID="$NEW_PROJECT_ID"
            gcloud config set project "$PROJECT_ID" --quiet
            echo "✅ Project created and set as active."
            break
        fi

        echo "⚠️  Could not create '$NEW_PROJECT_ID' — the ID may already be taken globally,"
        echo "    or it may not meet the rules (6–30 chars, lowercase letters/digits/hyphens,"
        echo "    must start with a letter)."
        read -p "🔁 Try a different ID? (Y/n): " RETRY
        RETRY=${RETRY:-Y}
        if [[ ! "$RETRY" =~ ^[Yy]$ ]]; then
            echo "🛑 Aborting."
            exit 1
        fi
    done
fi

# Verify access
if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
    echo "❌ Cannot access project '$PROJECT_ID'."
    exit 1
fi
echo "✅ Project: $PROJECT_ID"

# ────────────────────────────────────────────────────────────────────
# 3️⃣  Auto-link billing account to project
# ────────────────────────────────────────────────────────────────────
echo ""
echo "🔗 Checking billing link..."

CURRENT_BILLING=$(gcloud billing projects describe "$PROJECT_ID" \
    --format="value(billingAccountName)" 2>/dev/null | sed 's|billingAccounts/||')

if [ -z "$CURRENT_BILLING" ] || [ "$CURRENT_BILLING" != "$BILLING_ACCOUNT" ]; then
    echo "🔗 Linking billing account '$BILLING_ACCOUNT' to project..."
    if ! gcloud billing projects link "$PROJECT_ID" \
        --billing-account="$BILLING_ACCOUNT" --quiet; then
        echo "❌ Failed to link billing account."
        echo "   You may not have billing.resourceAssociations.create on this billing account."
        exit 1
    fi
    echo "✅ Billing linked."
else
    echo "✅ Billing already linked to '$BILLING_ACCOUNT'."
fi

# ────────────────────────────────────────────────────────────────────
# 4️⃣  Enable API Keys Management API
# ────────────────────────────────────────────────────────────────────
echo ""
echo "⚙️  Enabling API Keys Management API..."
if ! gcloud services enable apikeys.googleapis.com --project="$PROJECT_ID" --quiet; then
    echo "❌ Failed to enable apikeys.googleapis.com"
    exit 1
fi

# ────────────────────────────────────────────────────────────────────
# 5️⃣  Optionally list existing keys
# ────────────────────────────────────────────────────────────────────
read -p "📂 List existing API keys in this project? (y/N): " LIST_REQ
LIST_REQ=${LIST_REQ:-N}
if [[ "$LIST_REQ" =~ ^[Yy]$ ]]; then
    echo "--------------------------------------------------------------------------------"
    gcloud services api-keys list --project="$PROJECT_ID" \
        --format="table(displayName, name.basename():label=ID, state, createTime)"
    echo "--------------------------------------------------------------------------------"
fi

# ────────────────────────────────────────────────────────────────────
# 6️⃣  API Key naming & duplicate handling
# ────────────────────────────────────────────────────────────────────
read -p "🏷️  Display name for your new API Key (default: workshop-key): " KEY_NAME
KEY_NAME=${KEY_NAME:-workshop-key}

EXISTING_KEY_NAME=$(gcloud services api-keys list --project="$PROJECT_ID" \
    --filter="displayName='$KEY_NAME'" --format="value(name)")

if [ -n "$EXISTING_KEY_NAME" ]; then
    echo "⚠️  An API key with the name '$KEY_NAME' already exists."
    read -p "🗑️  Delete the existing key and recreate? (y/N): " DELETE_EXISTING
    if [[ "$DELETE_EXISTING" =~ ^[Yy]$ ]]; then
        gcloud services api-keys delete "$EXISTING_KEY_NAME" --project="$PROJECT_ID" --quiet
        echo "✅ Old key deleted."
    else
        echo "🛑 Aborting to avoid duplicates."
        exit 0
    fi
fi

# ────────────────────────────────────────────────────────────────────
# 7️⃣  API selection — workshop default includes deploy stack
# ────────────────────────────────────────────────────────────────────
# Default = full Gemini SDK + Cloud Run deploy pipeline
SELECTED_APIS=(
    "generativelanguage.googleapis.com"  # Gemini API
    "aiplatform.googleapis.com"          # Vertex AI
    "run.googleapis.com"                 # Cloud Run (deploy target)
    "cloudbuild.googleapis.com"          # Cloud Build (builds the container)
    "artifactregistry.googleapis.com"    # Artifact Registry (stores the container)
)

echo ""
echo "🧩 APIs to enable (workshop default — includes Gemini SDK + Cloud Run deploy):"
for api in "${SELECTED_APIS[@]}"; do
    echo "   - $api"
done

read -p "🛠️  Modify this list? (y/N): " MODIFY_APIS
MODIFY_APIS=${MODIFY_APIS:-N}

if [[ "$MODIFY_APIS" =~ ^[Yy]$ ]]; then
    ALL_OPTIONS=(
        "generativelanguage.googleapis.com (Gemini API)"
        "aiplatform.googleapis.com (Vertex AI)"
        "run.googleapis.com (Cloud Run)"
        "cloudbuild.googleapis.com (Cloud Build)"
        "artifactregistry.googleapis.com (Artifact Registry)"
        "language.googleapis.com (Natural Language API)"
        "vision.googleapis.com (Vision API)"
        "speech.googleapis.com (Speech-to-Text)"
        "translate.googleapis.com (Translation API)"
    )
    ALL_SERVICES=(
        "generativelanguage.googleapis.com"
        "aiplatform.googleapis.com"
        "run.googleapis.com"
        "cloudbuild.googleapis.com"
        "artifactregistry.googleapis.com"
        "language.googleapis.com"
        "vision.googleapis.com"
        "speech.googleapis.com"
        "translate.googleapis.com"
    )

    echo "Select APIs (comma-separated numbers, e.g. 1,2,3,4,5):"
    for i in "${!ALL_OPTIONS[@]}"; do
        echo "   $((i+1))) ${ALL_OPTIONS[$i]}"
    done

    read -p "Selection: " SELECTION
    SELECTED_APIS=()
    IFS=',' read -ra ADDR <<< "$SELECTION"
    for i in "${ADDR[@]}"; do
        index=$(echo "$i" | xargs)
        if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -ge 1 ] && [ "$index" -le "${#ALL_SERVICES[@]}" ]; then
            SELECTED_APIS+=("${ALL_SERVICES[$((index-1))]}")
        fi
    done

    if [ ${#SELECTED_APIS[@]} -eq 0 ]; then
        echo "⚠️  No valid selection. Using default list."
        SELECTED_APIS=(
            "generativelanguage.googleapis.com"
            "aiplatform.googleapis.com"
            "run.googleapis.com"
            "cloudbuild.googleapis.com"
            "artifactregistry.googleapis.com"
        )
    fi
fi

# ────────────────────────────────────────────────────────────────────
# 8️⃣  Enable selected APIs (batch for speed)
# ────────────────────────────────────────────────────────────────────
echo ""
echo "⚙️  Enabling APIs (this can take a minute)..."
# Batch enable is much faster than one-by-one
if ! gcloud services enable "${SELECTED_APIS[@]}" --project="$PROJECT_ID" --quiet; then
    echo "❌ Failed to enable one or more APIs."
    exit 1
fi
echo "✅ All APIs enabled."

# ────────────────────────────────────────────────────────────────────
# 9️⃣  Grant Cloud Build deploy permissions (workshop-specific)
# ────────────────────────────────────────────────────────────────────
# When deploying to Cloud Run via `gcloud run deploy --source=.`, Cloud Build
# needs permission to deploy to Cloud Run and act as the runtime service account.
# Without these bindings, students hit "Permission denied" during their first deploy.
if [[ " ${SELECTED_APIS[*]} " =~ " cloudbuild.googleapis.com " ]] && \
   [[ " ${SELECTED_APIS[*]} " =~ " run.googleapis.com " ]]; then
    echo ""
    echo "🛡️  Configuring Cloud Build → Cloud Run deploy permissions..."

    PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
    CLOUDBUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
    COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

    # Cloud Build SA needs to deploy to Cloud Run
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${CLOUDBUILD_SA}" \
        --role="roles/run.admin" --quiet >/dev/null 2>&1 || true

    # Cloud Build SA needs to act as the Cloud Run runtime SA (default = compute SA)
    gcloud iam service-accounts add-iam-policy-binding "$COMPUTE_SA" \
        --member="serviceAccount:${CLOUDBUILD_SA}" \
        --role="roles/iam.serviceAccountUser" --quiet >/dev/null 2>&1 || true

    echo "✅ Deploy permissions configured."
fi

# ────────────────────────────────────────────────────────────────────
# 🔟  Create restricted API key (using array, not eval)
# ────────────────────────────────────────────────────────────────────
echo ""
echo "🏗️  Creating restricted API key '$KEY_NAME'..."

CREATE_ARGS=(services api-keys create
    --project="$PROJECT_ID"
    --display-name="$KEY_NAME")
for api in "${SELECTED_APIS[@]}"; do
    CREATE_ARGS+=(--api-target="service=$api")
done

if ! gcloud "${CREATE_ARGS[@]}"; then
    echo "💥 Error creating the API key."
    exit 1
fi

echo ""
echo "✅ API Key created!"
echo "⏳ Restrictions can take up to 5 minutes to propagate."

echo "📡 Fetching the secret API key string..."
KEY_RESOURCE=$(gcloud services api-keys list --project="$PROJECT_ID" \
    --filter="displayName='$KEY_NAME'" --format="value(name)" | head -n1)

if [ -n "$KEY_RESOURCE" ]; then
    KEY_STRING=$(gcloud services api-keys get-key-string "$KEY_RESOURCE" \
        --project="$PROJECT_ID" --format="value(keyString)")

    if [ -n "$KEY_STRING" ]; then
        echo ""
        echo "═══════════════════════════════════════════════════════"
        echo "🔑 API KEY:    $KEY_STRING"
        echo "📦 PROJECT_ID: $PROJECT_ID"
        echo "═══════════════════════════════════════════════════════"
        echo ""
        echo "📋 Add to your .env file:"
        echo "   GEMINI_API_KEY=$KEY_STRING"
        echo "   GOOGLE_CLOUD_PROJECT=$PROJECT_ID"
        echo ""
        echo "🚀 To deploy to Cloud Run later:"
        echo "   gcloud run deploy my-app --source=. --region=europe-west1 --allow-unauthenticated"
        echo ""
        echo "✨ Setup complete!"
    else
        echo "⚠️  Could not fetch the key string. Check the GCP Console."
    fi
else
    echo "⚠️  Could not find the newly created key resource."
fi