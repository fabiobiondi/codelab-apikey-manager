# 🚀 GCP API Key Manager

A lightweight, interactive Bash script to automate the creation and management of Google Cloud Platform (GCP) API Keys specifically tailored for **Gemini API**, **Cloud Run**, and **Vertex AI**, with support for custom API selection.

## 🌟 Features

- **🤖 Multi-Service Support**: Restrict keys to Gemini API, Cloud Run, Vertex AI, and more.
- **⚙️ Auto-API Enabling**: Automatically enables the API Keys Management API and any service you select.
- **🆔 Smart Project Detection**: Detects your current `gcloud` project and offers it as a default.
- **📂 Interactive Listing**: Optionally view all existing keys in your project before creating a new one.
- **🛠️ Granular API Selection**: Choose exactly which APIs to enable and restrict for each key via an interactive menu.
- **🗑️ Conflict Management**: Detects existing keys with the same name and offers interactive deletion/recreation.
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

# Standard interactive workflow
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

## 🛠️ How it Works (New Flow)

1.  **Project Selection**: Identifies and confirms the target GCP Project (defaults to current).
2.  **API Key Service**: Ensures `apikeys.googleapis.com` is active.
3.  **Discovery**: Optionally lists existing API keys to avoid naming conflicts.
4.  **Naming**: Prompts for a display name and handles existing duplicates interactively.
5.  **Service Customization**: 
    - Offers a **default set** (Gemini, Cloud Run, Vertex AI).
    - Allows **manual selection** from a list of popular Google Cloud APIs (Vision, Translate, Natural Language, etc.).
6.  **Provisioning**: Automatically enables all selected services on the project.
7.  **Restricted Creation**: Generates the key with strict `--api-target` restrictions for maximum security.
8.  **Output**: Displays the final API key string for immediate use.

## ⚠️ Important Notes

- **Security**: API Keys are less secure than Service Accounts. Use them only when necessary and always keep them secret.
- **Propagation**: GCP API Key restrictions can take up to **5 minutes** to fully propagate across Google's infrastructure.

## 📄 License

This project is open-source and available under the MIT License.
