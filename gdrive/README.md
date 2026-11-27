# Connect Google Drive — for your PAIA (Mac)

Tell your PAIA:
"Download https://stevenlava.com/gdrive/connect.command, run it with bash and my Google address, then add the Google Drive notes from https://stevenlava.com/gdrive/README.md to your CLAUDE.md."

Run:  curl -fsSL https://stevenlava.com/gdrive/connect.command -o ~/connect-gdrive.command && bash ~/connect-gdrive.command you@gmail.com

A browser opens: pick the account, tick every box, press Allow.

## Google Drive notes for CLAUDE.md
gcloud (in ~/.local/google-cloud-sdk/bin) holds the owner's Google sign-in, made with
"Connect Google Drive". To read, get a token and call Google's REST APIs with curl:
  TOKEN=$(gcloud auth print-access-token --account=<email>)
  curl -s -H "Authorization: Bearer $TOKEN" "https://www.googleapis.com/drive/v3/files?q=name contains 'budget'&fields=files(id,name,mimeType,modifiedTime)"
  Sheets: https://sheets.googleapis.com/v4/spreadsheets/<id>/values/<range>
  Docs export: https://www.googleapis.com/drive/v3/files/<id>/export?mimeType=text/plain
Say which file a figure came from. Reading is free. Any write, edit, share or delete:
say what you'd change and wait for the owner's go. Never print a token.
If it answers 401/403, run Connect Google Drive again.
