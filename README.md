# API-Automation-tool

This project runs an Angular app with a small Express server (SSR). I added an endpoint to run a PowerShell automation script and return its JSON log so the UI's Response Terminal can show results.

Quick usage

1. Place your automation files in the included folder `Automation - Swagger input` (this repo already contains `callapi.ps1`, `swagger.json`, `overrides.json`, `get_api_logs.json`).
2. Build and run the server (SSR) and then call the endpoint to execute the script and retrieve logs.

Run (high-level)

```powershell
# Build the app (Angular build step may vary)
npm run build

# Run the built SSR server (the project includes a script that expects server bundle in dist)
npm run serve:ssr:api-automation-tool
```

Endpoints added

- GET /run-script — executes the PowerShell script (defaults to `Automation - Swagger input/callapi.ps1`) and returns the produced log JSON (defaults to `Automation - Swagger input/get_api_logs.json`).
- GET /api/logs — returns the contents of `get_api_logs.json` (parsed JSON if possible).

How the UI maps the output

- The Angular `AppComponent` was updated so that when you click the "Run" action (Run Tests), the front-end calls `/run-script`. The returned JSON (or the parsed `get_api_logs.json`) is assigned to the `ResponseTerminal` component's `response` input. So the response terminal will show the JSON written by the script.

Environment variables and overrides

- You can override default paths with environment variables: `SCRIPT_PATH`, `SWAGGER_PATH`, `PARAMETERS_PATH`, `LOG_OUTPUT`.
- You can also pass query parameters to `/run-script` (e.g. `?scriptPath=...&swaggerPath=...&parametersPath=...&logOutput=...`).

Security note

- Running scripts via an HTTP endpoint is potentially dangerous. Protect `/run-script` with authentication or IP restrictions in production.

Next steps you can ask me to implement

- Add a small integration test that starts the server and verifies `/run-script` using a dummy PS1.
- Add authentication for `/run-script`.
- Add UI controls to choose between local-uploaded swagger/params and the repo defaults.
