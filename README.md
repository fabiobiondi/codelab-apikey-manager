# 🚀 GCP API Key Manager

A lightweight, interactive Bash script to automate the creation and management of Google Cloud Platform (GCP) API Keys specifically tailored for **Gemini API**, **Cloud Run**, and **Vertex AI**.

## 🌟 Features

- **🤖 Multi-Service Support**: Automatically restricts keys to Gemini API, Cloud Run, and Vertex AI.
- **⚙️ Auto-API Enabling**: Checks and enables all required GCP services in your project before creating the key.
- **🆔 Smart Project Detection**: Automatically detects your current `gcloud` project and asks for confirmation.
- **🗑️ Conflict Management**: Detects existing keys with the same name and offers to delete them before recreating.
- **📡 Key Recovery**: Automatically fetches and displays the secret key string upon successful creation.
- **✨ User-Friendly**: Rich terminal output with emojis and clear status messages.

## 📋 Prerequisites

Before running the script, ensure you have:

1.  **Google Cloud SDK (`gcloud`)** installed.
2.  **Authenticated** with your account:
    ```bash
    gcloud auth login
    ```
3.  **Project Permissions**: You need `Editor` or `Owner` roles (or specific API Key management permissions) on the target GCP project.

## 🚀 Usage

Simply clone the repository and run the script:

```bash
git clone https://github.com/giacomoRanieri/codelab-apikey-manager.git
cd codelab-apikey-manager
./create_gemini_key.sh
```

*(Note: The script is already marked as executable in the repository, so no `chmod` is required!)*

## ☁️ Usage on Google Cloud Shell

Google Cloud Shell is the easiest way to run this script as it comes with `gcloud` pre-installed and pre-authenticated.

1.  Open [Google Cloud Shell](https://shell.cloud.google.com).
2.  Run the following one-liner to clone and start:
    ```bash
    git clone https://github.com/giacomoRanieri/codelab-apikey-manager.git && cd codelab-apikey-manager && ./create_gemini_key.sh
    ```

## 🛠️ How it Works

1.  **Project Selection**: Checks for a default project in your environment.
2.  **API Activation**: Enables `generativelanguage.googleapis.com`, `run.googleapis.com`, `aiplatform.googleapis.com`, and `apikeys.googleapis.com`.
3.  **Validation**: Prompts for a display name and checks for existing duplicates.
4.  **Conflict Resolution**: If a key exists, offers deletion followed by a choice to recreate or terminate.
5.  **Creation**: Generates the key with precise API target restrictions for maximum security.
6.  **Output**: Displays the final API key string for immediate use.

## ⚠️ Important Notes

- **Security**: API Keys are less secure than Service Accounts. Use them only when necessary (e.g., client-side integrations or specific API requirements) and always keep them secret.
- **Propagation**: GCP API Key restrictions can take up to **5 minutes** to fully propagate across Google's infrastructure.

## 📄 License

This project is open-source and available under the MIT License.
