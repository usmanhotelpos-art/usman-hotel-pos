# Google Sheets Integration Setup Guide

## Error
```
Google service account key not found at ./config/google-service-account.json
```

## Solution Steps

### Step 1: Create a Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Select a Project" → "New Project"
3. Enter a project name and create it

### Step 2: Enable Google Sheets API
1. In Cloud Console, go to "APIs & Services" → "Library"
2. Search for "Google Sheets API"
3. Click on it and press "Enable"

### Step 3: Create a Service Account
1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "Service Account"
3. Fill in the details and create the service account

### Step 4: Generate a JSON Key
1. In Service Accounts list, click on the service account you just created
2. Go to the "Keys" tab
3. Click "Add Key" → "Create new key"
4. Choose "JSON" format
5. Download the JSON file

### Step 5: Place the Key File
1. Copy the downloaded JSON file
2. Paste it into: `server/config/`
3. Rename it to: `google-service-account.json`

### Step 6: Share Your Google Sheet
1. Open the downloaded JSON file and find the `client_email` value
2. Example: `my-service-account@my-project.iam.gserviceaccount.com`
3. Go to your Google Sheet: https://docs.google.com/spreadsheets/d/1EeB87HFEHehVFevomNDCRnNFyKZFyi6fLULJ3dsD4rU/
4. Share it with that email address (Give "Editor" access)

### Alternative: Use Environment Variable
Instead of placing the file in `server/config/`, you can:
1. Set environment variable: `GOOGLE_SERVICE_ACCOUNT_KEYFILE=/path/to/your/keyfile.json`
2. Then the code will use that path instead

## Verification
After setup, when you click "Create Google Sheet", it should:
- Create a new spreadsheet
- Backup your database there
- The error should disappear

---
**Note**: Your sheet link: https://docs.google.com/spreadsheets/d/1EeB87HFEHehVFevomNDCRnNFyKZFyi6fLULJ3dsD4rU/
**Email**: farhansardar413@gmail.com
