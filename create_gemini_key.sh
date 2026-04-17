#!/bin/bash

# 🚀 GOOGLE CLOUD API KEY CREATOR & MANAGER 🚀

# Function to display help
show_help() {
    echo "Usage: ./create_gemini_key.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --list      List all API keys in the project"
    echo "  --help      Show this help message"
    echo ""
    echo "If no options are provided, the script starts the interactive creation flow."
}

# Function to list keys
list_keys() {
    echo "📡 Fetching API keys for project '$PROJECT_ID'..."
    echo "--------------------------------------------------------------------------------"
    gcloud services api-keys list --project="$PROJECT_ID" --format="table(displayName, name.basename():label=ID, state, createTime)"
    echo "--------------------------------------------------------------------------------"
}

# Initial Setup & Project Detection
DEFAULT_PROJECT=$(gcloud config get-value project 2>/dev/null)

# Argument Parsing
case "$1" in
    --list)
        if [ -z "$DEFAULT_PROJECT" ]; then
            read -p "🆔 Enter the Google Cloud Project ID: " PROJECT_ID
        else
            PROJECT_ID=$DEFAULT_PROJECT
        fi
        list_keys
        exit 0
        ;;
    --help)
        show_help
        exit 0
        ;;
esac

echo "------------------------------------------------"
echo "🌟 Welcome to the API Key Manager! 🌟"
echo "------------------------------------------------"

# 🔍 Project Detection
if [ ! -z "$DEFAULT_PROJECT" ]; then
    read -p "🆔 Found default project '$DEFAULT_PROJECT'. Use it? (y/n): " USE_DEFAULT
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

# 🛠️ Enable required services
echo "⚙️  Ensuring required APIs are enabled in project '$PROJECT_ID'..."
gcloud services enable \
    generativelanguage.googleapis.com \
    run.googleapis.com \
    aiplatform.googleapis.com \
    apikeys.googleapis.com \
    --project="$PROJECT_ID"

if [ $? -ne 0 ]; then
    echo "❌ Failed to enable required services."
    exit 1
fi

# 📝 Prompt for API Key Name
read -p "🏷️ Enter the display name for the API Key: " KEY_NAME
if [ -z "$KEY_NAME" ]; then
    echo "❌ Error: API Key name is required."
    exit 1
fi

# 🔍 Check if key exists
EXISTING_KEY_NAME=$(gcloud services api-keys list --project="$PROJECT_ID" --filter="displayName='$KEY_NAME'" --format="value(name)")

if [ ! -z "$EXISTING_KEY_NAME" ]; then
    echo "⚠️  An API key with the name '$KEY_NAME' already exists."
    read -p "🗑️  Do you want to delete the existing key? (y/n): " DELETE_EXISTING
    if [[ "$DELETE_EXISTING" =~ ^[Yy]$ ]]; then
        gcloud services api-keys delete "$EXISTING_KEY_NAME" --project="$PROJECT_ID" --quiet
        echo "✅ Key deleted."
        read -p "🔄 Do you want to recreate it now? (y/n): " RECREATE
        if [[ ! "$RECREATE" =~ ^[Yy]$ ]]; then
            echo "👋 Goodbye!"
            exit 0
        fi
    else
        echo "🛑 Aborting."
        exit 0
    fi
fi

echo "🏗️  Creating API key..."
gcloud services api-keys create \
    --project="$PROJECT_ID" \
    --display-name="$KEY_NAME" \
    --api-target=service=generativelanguage.googleapis.com \
    --api-target=service=run.googleapis.com \
    --api-target=service=aiplatform.googleapis.com

if [ $? -eq 0 ]; then
    echo "✅ Success!"
    KEY_STRING=$(gcloud services api-keys list --project="$PROJECT_ID" --filter="displayName='$KEY_NAME'" --format="value(name)" | xargs gcloud services api-keys get-key-string --project="$PROJECT_ID" --format="value(keyString)")
    echo "-----------------------------------------------"
    echo "🔑 API KEY: $KEY_STRING"
    echo "-----------------------------------------------"
else
    echo "💥 Error creating key."
    exit 1
fi

################################################################################
# 📚 DOCUMENTATION
# 
# 🎯 PURPOSE:
# Automates GCP API Key creation, listing, and cleanup for Gemini, Cloud Run, and Vertex AI.
#
# 📋 PREREQUISITES:
# 1. gcloud SDK installed and authenticated.
# 2. Project Editor/Owner permissions.
#
# ⚙️  HOW IT WORKS:
# 1. 📂 Supports flags like --list to view all project keys.
# 2. 🆔 Handles project detection and API enabling automatically.
# 3. 🏷️  Interactive creation with duplicate detection.
# 4. 🔄 Offers deletion and optional recreation for existing keys.
# 5. 🚫 Applies strict API target restrictions (Gemini, Run, Vertex).
#
# 🚀 USAGE:
# ./create_gemini_key.sh          # Interactive creation
# ./create_gemini_key.sh --list   # List all keys
# ./create_gemini_key.sh --help   # Show options
#
################################################################################
