#!/bin/bash

# 🚀 GOOGLE CLOUD API KEY MANAGER 🚀

echo "------------------------------------------------"
echo "🌟 Welcome to the Advanced API Key Manager! 🌟"
echo "------------------------------------------------"

# 1️⃣ Project Selection
DEFAULT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ ! -z "$DEFAULT_PROJECT" ]; then
    read -p "🆔 Found current project '$DEFAULT_PROJECT'. Use it? (Y/n): " USE_DEFAULT
    USE_DEFAULT=${USE_DEFAULT:-Y}
    if [[ "$USE_DEFAULT" =~ ^[Yy]$ ]]; then
        PROJECT_ID=$DEFAULT_PROJECT
    fi
fi

if [ -z "$PROJECT_ID" ]; then
    read -p "🆔 Enter the Google Cloud Project ID: " PROJECT_ID
    if [ -z "$PROJECT_ID" ]; then
        echo "❌ Error: Project ID is required."
        exit 1
    fi
fi

# 2️⃣ Enable API Key Management API
echo "⚙️  Enabling API Keys Management API..."
gcloud services enable apikeys.googleapis.com --project="$PROJECT_ID" --quiet

# 3️⃣ Ask to list existing keys
read -p "📂 Would you like to list existing API keys in this project? (y/N): " LIST_REQ
LIST_REQ=${LIST_REQ:-N}
if [[ "$LIST_REQ" =~ ^[Yy]$ ]]; then
    echo "📡 Fetching API keys..."
    echo "--------------------------------------------------------------------------------"
    gcloud services api-keys list --project="$PROJECT_ID" --format="table(displayName, name.basename():label=ID, state, createTime)"
    echo "--------------------------------------------------------------------------------"
fi

# 4️⃣ API Key Management (Name & Existing Check)
read -p "🏷️  Enter the display name for your new API Key: " KEY_NAME
if [ -z "$KEY_NAME" ]; then
    echo "❌ Error: API Key name is required."
    exit 1
fi

EXISTING_KEY_NAME=$(gcloud services api-keys list --project="$PROJECT_ID" --filter="displayName='$KEY_NAME'" --format="value(name)")

if [ ! -z "$EXISTING_KEY_NAME" ]; then
    echo "⚠️  An API key with the name '$KEY_NAME' already exists."
    read -p "🗑️  Do you want to delete the existing key? (y/n): " DELETE_EXISTING
    if [[ "$DELETE_EXISTING" =~ ^[Yy]$ ]]; then
        gcloud services api-keys delete "$EXISTING_KEY_NAME" --project="$PROJECT_ID" --quiet
        echo "✅ Key deleted."
        read -p "🔄 Do you want to proceed with creation? (Y/n): " RECREATE
        RECREATE=${RECREATE:-Y}
        if [[ ! "$RECREATE" =~ ^[Yy]$ ]]; then
            echo "👋 Goodbye!"
            exit 0
        fi
    else
        echo "🛑 Aborting to avoid duplicates."
        exit 0
    fi
fi

# 5️⃣ API Selection
# Default list
SELECTED_APIS=("generativelanguage.googleapis.com" "run.googleapis.com" "aiplatform.googleapis.com")

echo ""
echo "🧩 Default APIs to be enabled and restricted for this key:"
for api in "${SELECTED_APIS[@]}"; do
    echo "   - $api"
done

read -p "🛠️  Would you like to modify this list? (y/N): " MODIFY_APIS
MODIFY_APIS=${MODIFY_APIS:-N}

if [[ "$MODIFY_APIS" =~ ^[Yy]$ ]]; then
    # Full list of available options
    ALL_OPTIONS=(
        "generativelanguage.googleapis.com (Gemini API)"
        "run.googleapis.com (Cloud Run)"
        "aiplatform.googleapis.com (Vertex AI)"
        "language.googleapis.com (Natural Language API)"
        "vision.googleapis.com (Vision API)"
        "speech.googleapis.com (Speech-to-Text)"
        "translate.googleapis.com (Translation API)"
    )
    ALL_SERVICES=(
        "generativelanguage.googleapis.com"
        "run.googleapis.com"
        "aiplatform.googleapis.com"
        "language.googleapis.com"
        "vision.googleapis.com"
        "speech.googleapis.com"
        "translate.googleapis.com"
    )

    echo "Select APIs by entering their numbers separated by commas (e.g., 1,2,4):"
    for i in "${!ALL_OPTIONS[@]}"; do
        echo "   $((i+1))) ${ALL_OPTIONS[$i]}"
    done
    
    read -p "Selection: " SELECTION
    
    # Reset selected APIs
    SELECTED_APIS=()
    IFS=',' read -ra ADDR <<< "$SELECTION"
    for i in "${ADDR[@]}"; do
        # Trim whitespace
        index=$(echo $i | xargs)
        if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -ge 1 ] && [ "$index" -le "${#ALL_SERVICES[@]}" ]; then
            SELECTED_APIS+=("${ALL_SERVICES[$((index-1))]}")
        fi
    done
    
    if [ ${#SELECTED_APIS[@]} -eq 0 ]; then
        echo "⚠️  No valid selection made. Falling back to default list."
        SELECTED_APIS=("generativelanguage.googleapis.com" "run.googleapis.com" "aiplatform.googleapis.com")
    fi
fi

# 6️⃣ Enable Selected APIs
echo ""
echo "⚙️  Ensuring selected APIs are enabled..."
for api in "${SELECTED_APIS[@]}"; do
    echo "   🔗 Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" --quiet
done
echo "✅ All selected APIs are enabled."

# 7️⃣ Create Restricted API Key
echo ""
echo "🏗️  Creating restricted API key '$KEY_NAME'..."

# Build the command dynamically
CMD="gcloud services api-keys create --project=\"$PROJECT_ID\" --display-name=\"$KEY_NAME\""
for api in "${SELECTED_APIS[@]}"; do
    CMD="$CMD --api-target=service=$api"
done

eval $CMD

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ API Key created successfully!"
    echo "⏳ Note: It may take up to 5 minutes for restrictions to propagate."
    
    # 🔍 Fetch the key string
    echo "📡 Fetching the secret API key string..."
    
    KEY_STRING=$(gcloud services api-keys list --project="$PROJECT_ID" --filter="displayName='$KEY_NAME'" --format="value(name)" | xargs gcloud services api-keys get-key-string --project="$PROJECT_ID" --format="value(keyString)")
    
    if [ ! -z "$KEY_STRING" ]; then
        echo ""
        echo "-----------------------------------------------"
        echo "🔑 API KEY: $KEY_STRING"
        echo "-----------------------------------------------"
        echo "✨ Operation completed successfully! ✨"
    else
        echo "⚠️  Could not fetch the key string automatically. You can find it in the GCP Console."
    fi
else
    echo "💥 Error occurred while creating the API key."
    exit 1
fi

################################################################################
# 📚 DOCUMENTATION
# 
# 🎯 PURPOSE:
# Advanced management of GCP API Keys with granular service selection.
#
# ⚙️  FLOW:
# 1. 🆔 Project: Defaults to current gcloud project.
# 2. ⚙️  System Check: Ensures API Key Management API is enabled.
# 3. 📂 Listing: Optional listing of existing keys.
# 4. 🏷️  Naming: Interactive naming and duplicate handling.
# 5. 🛠️  Service Selection: 
#    - Default: Gemini, Cloud Run, Vertex AI.
#    - Custom: Choose from a list of popular Google Cloud APIs.
# 6. 🔗 Provisioning: Automatically enables all selected services.
# 7. 🔑 Security: Creates a key strictly restricted to selected services.
# 8. 📤 Delivery: Displays the final API key string.
#
################################################################################
