# Cloud Functions Setup

## Environment Variables

Set the following environment variables before deploying:

```bash
# Set Midtrans Server Key
firebase functions:config:set midtrans.server_key="YOUR_MIDTRANS_SERVER_KEY"

# View current config
firebase functions:config:get

# Deploy functions
npm run deploy
```

## Required Configuration

- `midtrans.server_key`: Your Midtrans Server Key (get from https://dashboard.midtrans.com)

## Local Development

Create `.runtimeconfig.json` in functions folder for local testing:

```json
{
  "midtrans": {
    "server_key": "YOUR_MIDTRANS_SERVER_KEY"
  }
}
```

**Important:** Add `.runtimeconfig.json` to `.gitignore` to prevent committing secrets.
