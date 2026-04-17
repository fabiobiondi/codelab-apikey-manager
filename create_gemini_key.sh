#!/bin/bash

# 🚀 GOOGLE CLOUD API KEY CREATOR 🚀

echo "------------------------------------------------"
echo "🌟 Welcome to the API Key Creation Script! 🌟"
echo "------------------------------------------------"

# 🔍 Check for existing project in environment variables
DEFAULT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ ! -z "$DEFAULT_PROJECT" ]; then
    read -p "🆔 Found default project '$DEFAULT_PROJECT'. Use it? (y/n): " USE_DEFAULT
    if [[ "$USE_DEFAULT" =~ ^[Yy]$ ]]; then
        PROJECT_ID=$DEFAULT_PROJECT
    fi
fi

# 📝 Prompt for Project ID if not set
if [ -z "$PROJECT_ID" ]; then
    read -p "🆔 Enter the Google Cloud Project ID: " PROJECT_ID
    if [ -z "$PROJECT_ID" ]; then
        echo "❌ Error: Project ID is required."
        exit 1
    fi
fi

# 🛠️ Enable required services
echo "⚙️  Ensuring required APIs are enabled in project '$PROJECT_ID'..."
echo "🔗 Enabling: Gemini API, Cloud Run, and Vertex AI..."
gcloud services enable \
    generativelanguage.googleapis.com \
    run.googleapis.com \
    aiplatform.googleapis.com \
    apikeys.googleapis.com \
    --project="$PROJECT_ID"

if [ $? -ne 0 ]; then
    echo "❌ Failed to enable required services. Please check your permissions."
    exit 1
fi
echo "✅ APIs are enabled."

# 📝 Prompt for API Key Name
read -p "🏷️ Enter the display name for the API Key: " KEY_NAME
if [ -z "$KEY_NAME" ]; then
    echo "❌ Error: API Key name is required."
    exit 1
fi

# 🔍 Check if a key with the same display name already exists
echo "🕵️ Checking if API key '$KEY_NAME' already exists..."
EXISTING_KEY_NAME=$(gcloud services api-keys list --project="$PROJECT_ID" --filter="displayName='$KEY_NAME'" --format="value(name)")

if [ ! -z "$EXISTING_KEY_NAME" ]; then
    echo "⚠️  An API key with the name '$KEY_NAME' already exists ($EXISTING_KEY_NAME)."
    read -p "🗑️  Do you want to delete the existing key and create a new one? (y/n): " DELETE_EXISTING
    if [[ "$DELETE_EXISTING" =~ ^[Yy]$ ]]; then
        echo "♻️ Deleting existing key..."
        gcloud services api-keys delete "$EXISTING_KEY_NAME" --project="$PROJECT_ID" --quiet
        if [ $? -ne 0 ]; then
            echo "❌ Failed to delete the existing key. Aborting."
            exit 1
        fi
        echo "✅ Key deleted."
    else
        echo "🛑 Aborting creation to avoid duplicates."
        exit 0
    fi
fi

echo ""
echo "🏗️  Creating API key '$KEY_NAME' in project '$PROJECT_ID'..."
echo "🔗 Enabled Services: Gemini API 🤖, Cloud Run ☁️, and Vertex AI 🧠"
echo ""

# 🔑 Create the API key with restrictions
gcloud services api-keys create \
    --project="$PROJECT_ID" \
    --display-name="$KEY_NAME" \
    --api-target=service=generativelanguage.googleapis.com \
    --api-target=service=run.googleapis.com \
    --api-target=service=aiplatform.googleapis.com

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
        echo "⚠️  Could not fetch the key string automatically. You can find it in the GCP Console. 🖥️"
    fi
else
    echo "💥 Error occurred while creating the API key."
    exit 1
fi

################################################################################
# 📚 DOCUMENTATION
# 
# 🎯 PURPOSE:
# This script automates the creation of a Google Cloud Platform API Key
# with specific restrictions for Gemini API, Cloud Run, and Vertex AI.
#
# 📋 PREREQUISITES:
# 1. ☁️  Google Cloud SDK (gcloud) installed.
# 2. 🔐 Authenticated via: `gcloud auth login`.
# 3. 🔑 Sufficient permissions in the target project (Editor or Owner).
#
# ⚙️  HOW IT WORKS:
# 1. 🔍 Detects default GCP project from local configuration.
# 2. 🆔 Requests or confirms the GCP Project ID.
# 3. ⚙️  Enables required APIs: Gemini, Cloud Run, Vertex AI, and API Keys API.
# 4. 🏷️  Requests a Display Name for the key.
# 5. 🕵️ Checks for existing keys with the same name and offers deletion.
# 6. 🛠️  Uses `gcloud services api-keys create` to generate the key.
# 7. 🚫 Applies API restrictions for Gemini, Cloud Run, and Vertex AI.
# 8. 📤 Fetches and prints the final key string.
#
# 🚀 USAGE:
# chmod +x create_gemini_key.sh
# ./create_gemini_key.sh
#
################################################################################
